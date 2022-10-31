FROM --platform=${BUILDPLATFORM} rust:1.59 AS build
RUN rustup target add wasm32-wasi
WORKDIR /opt/wasinn
COPY wasinn/pytorch-mobilenet-image/rust .
WORKDIR /opt/wasinn
RUN cargo build --target=wasm32-wasi --release

FROM scratch
ENTRYPOINT ["/wasm"]
COPY --from=build /opt/wasinn/target/wasm32-wasi/release/wasmedge-wasinn-example-mobilenet-image.wasm /wasm