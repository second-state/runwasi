FROM --platform=${BUILDPLATFORM} rust:1.59 AS build
RUN rustup target add wasm32-wasi
RUN apt-get update -y && apt-get install --no-install-recommends -y clang

WORKDIR /opt/db
COPY db .

WORKDIR /opt/db/mysql
RUN cargo build --target=wasm32-wasi --release

WORKDIR /opt/db/mysql_async
RUN cargo build --target=wasm32-wasi --release

FROM scratch
COPY --from=build /opt/db/mysql/target/wasm32-wasi/release/query.wasm /query.wasm
COPY --from=build /opt/db/mysql/target/wasm32-wasi/release/insert.wasm /insert.wasm
COPY --from=build /opt/db/mysql_async/target/wasm32-wasi/release/crud.wasm /crud.wasm