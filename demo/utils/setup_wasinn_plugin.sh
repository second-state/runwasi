#!/bin/sh -x

# Download PyTorch
if [ ! -d "$PWD/libtorch" ]
then
  export PYTORCH_VERSION="1.8.2"
  curl -s -L -O --remote-name-all https://download.pytorch.org/libtorch/lts/1.8/cpu/libtorch-cxx11-abi-shared-with-deps-${PYTORCH_VERSION}%2Bcpu.zip
  unzip -q "libtorch-cxx11-abi-shared-with-deps-${PYTORCH_VERSION}%2Bcpu.zip"
  rm -f "libtorch-cxx11-abi-shared-with-deps-${PYTORCH_VERSION}%2Bcpu.zip"
  sudo sh -c 'echo "$(pwd)/libtorch/lib" > /etc/ld.so.conf.d/libtorch.conf'
fi

# Download Wasmedge
if [ ! -d "$PWD/WasmEdge-0.11.1-Linux" ]
then
  curl -sLO https://github.com/WasmEdge/WasmEdge/releases/download/0.11.1/WasmEdge-0.11.1-ubuntu20.04_x86_64.tar.gz
  tar -zxf WasmEdge-0.11.1-ubuntu20.04_x86_64.tar.gz
  rm -f WasmEdge-0.11.1-ubuntu20.04_x86_64.tar.gz
  sudo sh -c 'echo "$(pwd)/WasmEdge-0.11.1-Linux/lib" > /etc/ld.so.conf.d/libwasmedge.conf'
fi

# Download WASINN plugin and extract to wasmedge library download path
if [ ! -f "$PWD/WasmEdge-0.11.1-Linux/lib/wasmedge/libwasmedgePluginWasiNN.so" ]
then
  curl -sLO https://github.com/WasmEdge/WasmEdge/releases/download/0.11.1/WasmEdge-plugin-wasi_nn-pytorch-0.11.1-ubuntu20.04_x86_64.tar.gz
  tar -zxf WasmEdge-plugin-wasi_nn-pytorch-0.11.1-ubuntu20.04_x86_64.tar.gz
  rm -f WasmEdge-plugin-wasi_nn-pytorch-0.11.1-ubuntu20.04_x86_64.tar.gz
  mv libwasmedgePluginWasiNN.so WasmEdge-0.11.1-Linux/lib/wasmedge
fi

sudo ldconfig
export WASMEDGE_INCLUDE_DIR=$PWD/WasmEdge-0.11.1-Linux/include
export WASMEDGE_LIB_DIR=$PWD/WasmEdge-0.11.1-Linux/lib
export WASMEDGE_PLUGIN_PATH=$PWD/WasmEdge-0.11.1-Linux/lib/wasmedge
