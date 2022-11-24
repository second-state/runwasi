FROM --platform=${BUILDPLATFORM} rust:1.65 AS build
RUN rustup target add wasm32-wasi
WORKDIR /opt/preopens
COPY wasmedge-rootfs-mounts-demo .

RUN cargo build --target=wasm32-wasi --release

FROM scratch
COPY --from=build /opt/preopens/target/wasm32-wasi/release/wasmedge-rootfs-mounts-demo.wasm /preopens.wasm
COPY --from=build /opt/preopens/target/wasm32-wasi/release/ /test-dir
ENTRYPOINT ["/preopens.wasm"]
