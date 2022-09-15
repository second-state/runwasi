// use std::fs::OpenOptions;
// use std::path::Path;

// use anyhow::Context;
// use cap_std::fs::File as CapFile;
// use containerd_shim_wasm::sandbox::oci;
// use containerd_shim_wasm::sandbox::oci::Error;
use oci_spec::runtime::Spec;

pub fn env_to_wasi(spec: &Spec) -> Vec<String> {
    let default = vec![];
    let env = spec
        .process()
        .as_ref()
        .unwrap()
        .env()
        .as_ref()
        .unwrap_or(&default);
    env.to_vec()
}