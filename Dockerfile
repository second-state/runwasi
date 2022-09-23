# syntax=docker/dockerfile:1

ARG RUST_VERSION=1.63
ARG XX_VERSION=1.1.0

FROM --platform=$BUILDPLATFORM tonistiigi/xx:${XX_VERSION} AS xx

FROM --platform=$BUILDPLATFORM rust:${RUST_VERSION} AS base
COPY --from=xx / /
RUN apt-get update -y && apt-get install --no-install-recommends -y cmake make clang
# Nightly is needed because there are nested workspaces
RUN rustup default nightly
WORKDIR /src

FROM base AS build
ARG BUILD_TAGS TARGETPLATFORM
ENV WASMEDGE_BUILD_DIR=/src/WasmEdge/build
ENV LD_LIBRARY_PATH=$WASMEDGE_BUILD_DIR/lib/api
RUN xx-apt-get install -y gcc g++ libc++6-dev
RUN rustup target add $(xx-info march)-unknown-$(xx-info os)-$(xx-info libc)

COPY . .
WORKDIR /src/WasmEdge

RUN <<EOT bash
    set -ex
    mkdir -p build && cd build
    cmake -DCMAKE_C_COMPILER=$(xx-info)-gcc \
          -DCMAKE_CXX_COMPILER=$(xx-info)-g++ \
          -DCMAKE_ASM_COMPILER=$(xx-info)-gcc \
          -DPKG_CONFIG_EXECUTABLE="$(xx-clang --print-prog-name=pkg-config)" \
          -DCMAKE_C_COMPILER_TARGET="$(xx-clang --print-target-triple)" \
          -DCMAKE_CXX_COMPILER_TARGET="$(xx-clang++ --print-target-triple)" \
          -DCMAKE_ASM_COMPILER_TARGET="$(xx-clang --print-target-triple)" \
          -DCMAKE_SYSTEM_PROCESSOR="$(xx-info march)" \
          -DCMAKE_BUILD_TYPE=Release \
          -DWASMEDGE_BUILD_AOT_RUNTIME=OFF .. && make -j
EOT

WORKDIR /src

RUN --mount=type=cache,target=/usr/local/cargo/git/db \
    --mount=type=cache,target=/usr/local/cargo/registry/cache \
    --mount=type=cache,target=/usr/local/cargo/registry/index <<EOT
    set -e
    export "CARGO_TARGET_$(xx-info march | tr '[:lower:]' '[:upper:]' | tr - _)_UNKNOWN_$(xx-info os | tr '[:lower:]' '[:upper:]' | tr - _)_$(xx-info libc | tr '[:lower:]' '[:upper:]' | tr - _)_LINKER=$(xx-info)-gcc"
    export "CC_$(xx-info march | tr '[:lower:]' '[:upper:]' | tr - _)_UNKNOWN_$(xx-info os | tr '[:lower:]' '[:upper:]' | tr - _)_$(xx-info libc | tr '[:lower:]' '[:upper:]' | tr - _)=$(xx-info)-gcc"
    cargo build --release --target=$(xx-info march)-unknown-$(xx-info os)-$(xx-info libc)
    cp /src/target/$(xx-info march)-unknown-$(xx-info os)-$(xx-info libc)/release/containerd-shim-wasmedge-v1 /containerd-shim-wasmedge-v1 
EOT

FROM scratch AS release
COPY --link --from=build /containerd-shim-wasmedge-v1 /containerd-shim-wasmedge-v1 
COPY --link --from=build /src/WasmEdge/build/lib/api/libwasmedge.so.0.0.0 /libwasmedge.so.0.0.0

FROM release
