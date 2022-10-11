FROM --platform=${BUILDPLATFORM} rust:1.59 AS build
RUN rustup target add wasm32-wasi
WORKDIR /opt/reqwest-demo
COPY wasmedge_reqwest_demo .
RUN cargo build --target=wasm32-wasi --release

FROM scratch
ENTRYPOINT ["/wasm"]
COPY --from=build /opt/reqwest-demo/target/wasm32-wasi/release/wasmedge_reqwest_demo.wasm /wasm