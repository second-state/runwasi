use containerd_shim as shim;
use containerd_shim_wasm::sandbox::ShimCli;
use runwasi::runtime_utils::runtime_check;
#[cfg(feature = "wasmedge")]
use runwasi::wasmedge::Wasi as WasiInstance;

fn main() {
    #[cfg(feature = "wasmedge")]
    shim::run::<ShimCli<WasiInstance, wasmedge_sdk::Vm>>("io.containerd.wasmwasi.v1", None);
    runtime_check();
}
