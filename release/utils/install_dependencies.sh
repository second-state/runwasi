#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <parameter1> <parameter2>"
    exit 1
fi

all_params="$@"
echo "All parameters: $all_params"

if [ "$1" == "wasi_nn-pytorch" ]; then
    echo "install $1 dependencies"
    pytorch_version=1.8.2
    curl -s -L -O --remote-name-all https://download.pytorch.org/libtorch/lts/1.8/cpu/libtorch-cxx11-abi-shared-with-deps-${pytorch_version}%2Bcpu.zip
    unzip -q "libtorch-cxx11-abi-shared-with-deps-${pytorch_version}%2Bcpu.zip"
    ls .
    mv ./libtorch/lib/libtorch.so "$2"
    mv ./libtorch/lib/libc10.so "$2"
    mv ./libtorch/lib/libtorch_cpu.so "$2"
    mv ./libtorch/lib/libgomp-75eea7e8.so.1 "$2"
fi

if [ "$1" == "wasi_nn-ggml" ]; then
    apt-get install --no-install-recommends -y libopenblas-dev
fi

