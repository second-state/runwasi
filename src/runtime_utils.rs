pub fn runtime_check() {
    #[cfg(all(feature = "wasmedge", feature = "wasmtime"))]
    compile_error!(
        "feature \"wasmedge\" and feature \"wasmtime\" cannot be enabled at the same time"
    );
    #[cfg(not(any(feature = "wasmedge", feature = "wasmtime")))]
    compile_error!(
        "feature \"wasmedge\" or feature \"wasmtime\" feature must selected for runtime"
    );
}
