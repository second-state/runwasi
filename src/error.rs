use anyhow;
use containerd_shim_wasm::sandbox::error;
use containerd_shim_wasm::sandbox::oci;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum WasmRuntimeError {
    #[error("{0}")]
    OciError(#[from] oci::Error),
    #[error("{0}")]
    Error(#[from] error::Error),
    #[error("{0}")]
    AnyError(#[from] anyhow::Error),
    #[error("{0}")]
    Wasmedge(#[from] Box<wasmedge_types::error::WasmEdgeError>),
}
