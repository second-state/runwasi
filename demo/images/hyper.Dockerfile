FROM --platform=${BUILDPLATFORM} rust:1.59 AS build
RUN rustup target add wasm32-wasi
WORKDIR /opt/hyper
COPY hyper .

WORKDIR /opt/hyper/client
RUN cargo build --target=wasm32-wasi --release

WORKDIR /opt/hyper/server
RUN cargo build --target=wasm32-wasi --release

FROM scratch
COPY --from=build /opt/hyper/client/target/wasm32-wasi/release/wasmedge_hyper_client.wasm /client.wasm
COPY --from=build /opt/hyper/server/target/wasm32-wasi/release/wasmedge_hyper_server.wasm /server.wasm