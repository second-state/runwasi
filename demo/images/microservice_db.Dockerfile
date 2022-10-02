FROM --platform=${BUILDPLATFORM} rust:1.59 AS build
RUN rustup target add wasm32-wasi
RUN apt-get update -y && apt-get install --no-install-recommends -y clang

WORKDIR /opt/microservice-db-demo
COPY microservice-rust-mysql .
RUN cargo build --target=wasm32-wasi --release

FROM scratch
ENTRYPOINT ["/wasm"]
COPY --from=build /opt/microservice-db-demo/target/wasm32-wasi/release/order_demo_service.wasm /wasm