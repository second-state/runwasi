use {
    anyhow::Context, oci_spec::image as spec, oci_tar_builder::Builder, sha256::try_digest,
    std::env, std::fs::File, std::path::PathBuf,
};

fn main() {
    println!("cargo:rerun-if-env-changed=BUILD_IMAGE");
    let enable_build_img = env::var("BUILD_IMAGE")
        .map(|v| v == "TRUE")
        .unwrap_or(false); // run by default

    if !enable_build_img {
        return;
    }

    env_logger::init();

    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let pkg_name = env::var("CARGO_PKG_NAME").unwrap();
    let wasm_name = format!("{}.wasm", pkg_name);
    let p = out_dir.join("img.tar");
    let bin_output_dir = out_dir
        .parent()
        .unwrap()
        .parent()
        .unwrap()
        .parent()
        .unwrap();

    let app_path = bin_output_dir.join(wasm_name);
    let layer_path = out_dir.join("layer.tar");
    let mut layer_builder = tar::Builder::new(File::create(&layer_path).unwrap());
    if app_path.exists() {
        layer_builder
            .append_path_with_name(&app_path, "app.wasm")
            .unwrap();
    } else {
        for element in bin_output_dir.read_dir().unwrap() {
            let path = element.unwrap().path();
            if let Some(extension) = path.extension() {
                if extension == "wasm" {
                    layer_builder
                        .append_path_with_name(&path, path.file_name().unwrap())
                        .unwrap();
                }
            }
        }
    }

    let mut builder = Builder::default();
    builder.add_layer(&layer_path);

    let entrypoint = if app_path.exists() {
        vec!["/app.wasm".to_owned()]
    } else {
        vec![]
    };

    let config = spec::ConfigBuilder::default()
        .entrypoint(entrypoint)
        .build()
        .unwrap();

    let layer_digest = try_digest(layer_path.as_path()).unwrap();
    let img = spec::ImageConfigurationBuilder::default()
        .config(config)
        .os("wasi")
        .architecture("wasm")
        .rootfs(
            spec::RootFsBuilder::default()
                .diff_ids(vec!["sha256:".to_owned() + &layer_digest])
                .build()
                .unwrap(),
        )
        .build()
        .context("failed to build image configuration")
        .unwrap();

    builder.add_config(
        img,
        format!("ghcr.io/second-state/runwasi-demo:{}", pkg_name).to_string(),
    );

    let f = File::create(&p).unwrap();
    builder.build(f).unwrap();
    std::fs::rename(&p, bin_output_dir.join("img.tar")).unwrap();
}
