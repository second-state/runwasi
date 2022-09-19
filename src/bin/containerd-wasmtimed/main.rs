use std::sync::Arc;

use containerd_shim_wasm::sandbox::{Local, ManagerService};
use containerd_shim_wasm::services::sandbox_ttrpc::{create_manager, Manager};
use log::info;
use runwasi::instance::Wasi as WasiInstance;
use ttrpc::{self, Server};
use wasmedge_sdk::{
    config::{CommonConfigOptions, ConfigBuilder, HostRegistrationConfigOptions},
    Vm,
};

fn main() {
    info!("starting up!");
    let host_options = HostRegistrationConfigOptions::default().wasi(true);
    let config = ConfigBuilder::new(CommonConfigOptions::default())
        .with_host_registration_config(host_options)
        .build()
        .unwrap();
    let vm = Vm::new(Some(config)).unwrap();
    let s: ManagerService<_, Local<WasiInstance, _>> = ManagerService::new(vm);
    let s = Arc::new(Box::new(s) as Box<dyn Manager + Send + Sync>);
    let service = create_manager(s);

    let mut server = Server::new()
        .bind("unix:///run/io.containerd.wasmtime.v1/manager.sock")
        .unwrap()
        .register_service(service);

    server.start().unwrap();
    info!("server started!");
    let (_tx, rx) = std::sync::mpsc::channel::<()>();
    rx.recv().unwrap();
}
