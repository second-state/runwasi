use libc::{dup, dup2, STDERR_FILENO, STDIN_FILENO, STDOUT_FILENO};
use std::fs::OpenOptions;
use std::os::unix::io::{IntoRawFd, RawFd};
use std::path::Path;
use std::sync::mpsc::channel;
use std::sync::mpsc::Sender;
use std::sync::{Arc, Condvar, Mutex};
use std::thread;

use anyhow::Context;
use chrono::{DateTime, Utc};
use containerd_shim_wasm::sandbox::error::Error;
use containerd_shim_wasm::sandbox::oci;
use containerd_shim_wasm::sandbox::{EngineGetter, Instance, InstanceConfig};
use log::{debug, error};
use wasmedge_sdk::{params, Vm};

use super::error::WasmRuntimeError;
use super::oci_wasmedge;

static mut STDIN_FD: Option<RawFd> = None;
static mut STDOUT_FD: Option<RawFd> = None;
static mut STDERR_FD: Option<RawFd> = None;

pub struct Wasi {
    exit_code: Arc<(Mutex<Option<(u32, DateTime<Utc>)>>, Condvar)>,
    engine: Vm,

    id: String,
    stdin: String,
    stdout: String,
    stderr: String,
    bundle: String,
}

#[cfg(test)]
mod tests {
    use std::fs::File;

    use tempfile::tempdir;

    use super::*;

    #[test]
    fn test_maybe_open_stdio() -> Result<(), Error> {
        let f = maybe_open_stdio("")?;
        assert!(f.is_none());

        let f = maybe_open_stdio("/some/nonexistent/path")?;
        assert!(f.is_none());

        let dir = tempdir()?;
        let temp = File::create(dir.path().join("testfile"))?;
        drop(temp);
        let f = maybe_open_stdio(dir.path().join("testfile").as_path().to_str().unwrap())?;
        assert!(f.is_some());
        drop(f);

        Ok(())
    }
}

/// containerd can send an empty path or a non-existant path
/// In both these cases we should just assume that the stdio stream was not setup (intentionally)
/// Any other error is a real error.
pub fn maybe_open_stdio(path: &str) -> Result<Option<RawFd>, Error> {
    if path.is_empty() {
        return Ok(None);
    }

    match OpenOptions::new().read(true).write(true).open(path) {
        Ok(f) => Ok(Some(f.into_raw_fd())),
        Err(err) => match err.kind() {
            std::io::ErrorKind::NotFound => Ok(None),
            _ => Err(err.into()),
        },
    }
}

pub fn reset_stdio() {
    unsafe {
        if STDIN_FD.is_some() {
            dup2(STDIN_FD.unwrap(), STDIN_FILENO);
        }
        if STDOUT_FD.is_some() {
            dup2(STDOUT_FD.unwrap(), STDOUT_FILENO);
        }
        if STDERR_FD.is_some() {
            dup2(STDERR_FD.unwrap(), STDERR_FILENO);
        }
    }
}

pub fn prepare_module(
    mut vm: Vm,
    bundle: String,
    stdin_path: String,
    stdout_path: String,
    stderr_path: String,
) -> Result<Vm, WasmRuntimeError> {
    let mut spec = oci::load(Path::new(&bundle).join("config.json").to_str().unwrap())?;

    spec.canonicalize_rootfs(&bundle).map_err(|err| {
        WasmRuntimeError::Error(Error::Others(format!(
            "could not canonicalize rootfs: {}",
            err
        )))
    })?;
    debug!("opening rootfs");
    let rootfs_path = oci::get_root(&spec).to_str().unwrap();
    let envs = oci_wasmedge::env_to_wasi(&spec);
    let args = oci::get_args(&spec);

    debug!("setting up wasi");
    let mut wasi_instance = vm.wasi_module()?;
    wasi_instance.initialize(
        Some(args.iter().map(|s| s as &str).collect()),
        Some(envs.iter().map(|s| s as &str).collect()),
        Some(vec![rootfs_path]),
    );

    debug!("opening stdin");
    let stdin = maybe_open_stdio(&stdin_path).context("could not open stdin")?;
    if stdin.is_some() {
        unsafe {
            STDIN_FD = Some(dup(STDIN_FILENO));
            dup2(stdin.unwrap(), STDIN_FILENO);
        }
    }

    debug!("opening stdout");
    let stdout = maybe_open_stdio(&stdout_path).context("could not open stdout")?;
    if stdout.is_some() {
        unsafe {
            STDOUT_FD = Some(dup(STDOUT_FILENO));
            dup2(stdout.unwrap(), STDOUT_FILENO);
        }
    }

    debug!("opening stderr");
    let stderr = maybe_open_stdio(&stderr_path).context("could not open stderr")?;
    if stderr.is_some() {
        unsafe {
            STDERR_FD = Some(dup(STDERR_FILENO));
            dup2(stderr.unwrap(), STDERR_FILENO);
        }
    }

    let mut cmd = args[0].clone();
    let stripped = args[0].strip_prefix(std::path::MAIN_SEPARATOR);
    if stripped.is_some() {
        cmd = stripped.unwrap().to_string();
    }

    let mod_path = oci::get_root(&spec).join(cmd);

    debug!("register module from file");
    let vm = vm.register_module_from_file("main", mod_path)?;

    Ok(vm)
}

impl Instance for Wasi {
    type E = Vm;
    fn new(id: String, cfg: Option<&InstanceConfig<Self::E>>) -> Self {
        let cfg = cfg.unwrap(); // TODO: handle error
        Wasi {
            exit_code: Arc::new((Mutex::new(None), Condvar::new())),
            engine: cfg.get_engine(),
            id,
            stdin: cfg.get_stdin().unwrap_or_default(),
            stdout: cfg.get_stdout().unwrap_or_default(),
            stderr: cfg.get_stderr().unwrap_or_default(),
            bundle: cfg.get_bundle().unwrap_or_default(),
        }
    }
    fn start(&self) -> Result<u32, Error> {
        let engine = self.engine.clone();

        let exit_code = self.exit_code.clone();
        let (tx, rx) = channel::<Result<(), Error>>();
        let bundle = self.bundle.clone();
        let stdin = self.stdin.clone();
        let stdout = self.stdout.clone();
        let stderr = self.stderr.clone();

        let _ = thread::Builder::new()
            .name(self.id.clone())
            .spawn(move || {
                debug!("starting instance");

                debug!("preparing module");
                let vm = match prepare_module(engine, bundle, stdin, stdout, stderr) {
                    Ok(vm) => vm,
                    Err(err) => {
                        tx.send(Err(Error::Others(err.to_string()))).unwrap();
                        return;
                    }
                };

                debug!("notifying main thread we are about to start");
                tx.send(Ok(())).unwrap();

                debug!("starting wasi instance");

                // TODO: How to get exit code?
                // This was relatively straight forward in go, but wasi and wasmtime are totally separate things in rust.
                let (lock, cvar) = &*exit_code;
                let _ret = match vm.run_func(Some("main"), "_start", params!()) {
                    Ok(_) => {
                        debug!("exit code: {}", 0);
                        let mut ec = lock.lock().unwrap();
                        *ec = Some((0, Utc::now()));
                    }
                    Err(_) => {
                        error!("exit code: {}", 137);
                        let mut ec = lock.lock().unwrap();
                        *ec = Some((137, Utc::now()));
                    }
                };

                cvar.notify_all();
            })?;

        debug!("Waiting for start notification");
        match rx.recv().unwrap() {
            Ok(_) => (),
            Err(err) => {
                debug!("error starting instance: {}", err);
                let code = self.exit_code.clone();

                let (lock, cvar) = &*code;
                let mut ec = lock.lock().unwrap();
                *ec = Some((139, Utc::now()));
                cvar.notify_all();
                return Err(err);
            }
        }

        Ok(1) // TODO: PID: I wanted to use a thread ID here, but threads use a u64, the API wants a u32
    }

    fn kill(&self, signal: u32) -> Result<(), Error> {
        if signal != 9 {
            return Err(Error::InvalidArgument(
                "only SIGKILL is supported".to_string(),
            ));
        }
        Ok(())
    }

    fn delete(&self) -> Result<(), Error> {
        Ok(())
    }

    fn wait(&self, channel: Sender<(u32, DateTime<Utc>)>) -> Result<(), Error> {
        let code = self.exit_code.clone();
        thread::spawn(move || {
            let (lock, cvar) = &*code;
            let mut exit = lock.lock().unwrap();
            while (*exit).is_none() {
                exit = cvar.wait(exit).unwrap();
            }
            let ec = (*exit).unwrap();
            channel.send(ec).unwrap();
        });

        Ok(())
    }
}

#[cfg(test)]
mod wasitest {
    use std::fs::{create_dir, read_to_string, write, File};
    use std::io::prelude::*;
    use std::time::Duration;

    use super::*;
    use tempfile::tempdir;
    use wasmedge_sdk::{
        config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
        Vm,
    };
    use wasmedge_types::wat2wasm;

    // This is taken from https://github.com/bytecodealliance/wasmtime/blob/6a60e8363f50b936e4c4fc958cb9742314ff09f3/docs/WASI-tutorial.md?plain=1#L270-L298
    const WASI_HELLO_WAT: &[u8]= r#"(module
        ;; Import the required fd_write WASI function which will write the given io vectors to stdout
        ;; The function signature for fd_write is:
        ;; (File Descriptor, *iovs, iovs_len, nwritten) -> Returns number of bytes written
        (import "wasi_snapshot_preview1" "fd_write" (func $fd_write (param i32 i32 i32 i32) (result i32)))

        (memory 1)
        (export "memory" (memory 0))

        ;; Write 'hello world\n' to memory at an offset of 8 bytes
        ;; Note the trailing newline which is required for the text to appear
        (data (i32.const 8) "hello world\n")

        (func $main (export "_start")
            ;; Creating a new io vector within linear memory
            (i32.store (i32.const 0) (i32.const 8))  ;; iov.iov_base - This is a pointer to the start of the 'hello world\n' string
            (i32.store (i32.const 4) (i32.const 12))  ;; iov.iov_len - The length of the 'hello world\n' string

            (call $fd_write
                (i32.const 1) ;; file_descriptor - 1 for stdout
                (i32.const 0) ;; *iovs - The pointer to the iov array, which is stored at memory location 0
                (i32.const 1) ;; iovs_len - We're printing 1 string stored in an iov - so one.
                (i32.const 20) ;; nwritten - A place in memory to store the number of bytes written
            )
            drop ;; Discard the number of bytes written from the top of the stack
        )
    )
    "#.as_bytes();

    #[test]
    fn test_delete_after_create() {
        let config = ConfigBuilder::new(CommonConfigOptions::default())
            .build()
            .unwrap();
        let vm = Vm::new(Some(config)).unwrap();
        let i = Wasi::new("".to_string(), Some(&InstanceConfig::new(vm)));
        i.delete().unwrap();
    }

    #[test]
    fn test_wasi() -> Result<(), Error> {
        let dir = tempdir()?;
        create_dir(&dir.path().join("rootfs"))?;

        let wasmbytes = wat2wasm(WASI_HELLO_WAT).unwrap();
        let mut f = File::create(dir.path().join("rootfs/hello.wasm"))?;
        f.write_all(&wasmbytes)?;

        let stdout = File::create(dir.path().join("stdout"))?;
        drop(stdout);

        write(
            dir.path().join("config.json"),
            "{
                \"root\": {
                    \"path\": \"rootfs\"
                },
                \"process\":{
                    \"cwd\": \"/\",
                    \"args\": [\"hello.wasm\"],
                    \"env\": [\"ENV1=VAL1\"],
                    \"user\": {
                        \"uid\": 0,
                        \"gid\": 0
                    }
                }
            }"
            .as_bytes(),
        )?;

        let host_options = HostRegistrationConfigOptions::default().wasi(true);
        let config = ConfigBuilder::new(CommonConfigOptions::default())
            .with_host_registration_config(host_options)
            .build()
            .map_err(anyhow::Error::msg)?;
        let mut cfg = InstanceConfig::new(Vm::new(Some(config)).map_err(anyhow::Error::msg)?);
        let cfg = cfg
            .set_bundle(dir.path().to_str().unwrap().to_string())
            .set_stdout(dir.path().join("stdout").to_str().unwrap().to_string());

        let wasi = Arc::new(Wasi::new("test".to_string(), Some(cfg)));

        wasi.start()?;

        let w = wasi.clone();
        let (tx, rx) = channel();
        thread::spawn(move || {
            w.wait(tx).unwrap();
        });

        let res = match rx.recv_timeout(Duration::from_secs(10)) {
            Ok(res) => res,
            Err(e) => {
                wasi.kill(9).unwrap();
                return Err(Error::Others(format!(
                    "error waiting for module to finish: {0}",
                    e
                )));
            }
        };
        assert_eq!(res.0, 0);

        let output = read_to_string(dir.path().join("stdout"))?;
        assert_eq!(output, "hello world\n");
        reset_stdio();
        Ok(())
    }
}

impl EngineGetter for Wasi {
    type E = Vm;
    fn new_engine() -> Result<Vm, Error> {
        let vm = Vm::new(None).map_err(anyhow::Error::msg)?;
        Ok(vm)
    }
}
