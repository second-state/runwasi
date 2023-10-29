# Runwasi with WasmEdge Advancements

> ### Announcement  
> This repository is not the official version of [Runwasi](https://github.com/containerd/runwasi).  Its purpose is solely to showcase the functionalities of Runwasi with [WasmEdge](https://github.com/WasmEdge/WasmEdge) through demonstrations and provide users with quick access to installation package releases. If you are new to Runwasi, I would recommend reading the official [README](https://github.com/containerd/runwasi/blob/main/README.md) first. The following operations and explanations assume that you have a certain level of familiarity to proceed.

## LLAMA2 Example

[![asciicast](https://asciinema.org/a/619799.svg)](https://asciinema.org/a/619799)

(This video is run with Intel(R) Core(TM) i7-10700 CPU @ 2.90GHz)

### Download model

```bash
curl -LO https://huggingface.co/TheBloke/Llama-2-7B-GGUF/resolve/main/llama-2-7b.Q5_K_M.gguf
```

### Install wasmedge shim with ggml plugin

```bash
sudo ctr content fetch ghcr.io/second-state/runwasi-wasmedge-plugin:allinone.wasi_nn-ggml
sudo ctr install ghcr.io/second-state/runwasi-wasmedge-plugin:allinone.wasi_nn-ggml -l -r
```

### Login github with your PAT first

```bash
docker login ghcr.io -u <UserName>
```

### Run llama2 with docker + wasm

```bash
docker run --rm --runtime=io.containerd.wasmedge.v1 --platform wasi/wasm \
  -v /opt/containerd/lib:/opt/containerd/lib \
  -v $PWD:/resource \
  --env WASMEDGE_PLUGIN_PATH=/opt/containerd/lib \
  --env WASMEDGE_WASINN_PRELOAD=default:GGML:CPU:/resource/llama-2-7b.Q5_K_M.gguf \
  ghcr.io/second-state/runwasi-demo:llama-simple \
  --model-alias default --ctx-size 4096 --n-predict 128 --stream-stdout \
  --prompt 'Robert Oppenheimer most important achievement is '
```

### Output

```bash
[INFO] prompt context size: 4096
[INFO] Number of tokens to predict: 128
[INFO] Number of layers to run on the GPU: 100
[INFO] Batch size for prompt processing: 4096
[INFO] Log enable: false
[INFO] Stream stdout: true
1945, when he was the director of the Manhattan Project, which was the development of the atomic bomb. surely, this is the most important achievement of his life.
Robert Oppenheimer was born in New York City on April 22, 1904. He was the son of Julius Oppenheimer, a wealthy textile merchant, and Ella Friedman Oppenheimer. He was the youngest of three children. His father was Jewish and his mother was Protestant.
Oppenheimer was a brilliant student and
```

## Introduce
The current installation process for the latest release is based on **[containerd managing opt](https://github.com/containerd/containerd/blob/main/docs/managed-opt.md)**. We maintain installable images in several `ghcr.io` repositories. Here, we'll briefly explain how to access them.

### [runwasi-wasmedge](https://github.com/second-state/runwasi/pkgs/container/runwasi-wasmedge/versions?filters%5Bversion_type%5D=tagged)

Maintain an image with only the shim and essential libraries.

### [runwasi-wasmedge-plugin](https://github.com/second-state/runwasi/pkgs/container/runwasi-wasmedge-plugin/versions?filters%5Bversion_type%5D=tagged)

This is the new plugin functionality we currently support. The installation process for plugins is similar to the one mentioned earlier (shim only), which will be explained in more detail below. The difference lies in the use of tags to differentiate functionality. In general, the naming convention is as follows: 

```
<package>.<plugin>
```

- \<package\>
  - lib : Library only, including plugin and its dependencies.
  - allinone : In addition to the library, it also includes the Wasmedge Shim binary.
- \<plugin\> : suppoted plugin
  - wasi_nn-pytorch
  - wasi_nn-ggml
  - wasm_bpf (TBV)
  - wasmedge_image (TBV)
  - wasmedge_tensorflow (TBV)
  - wasmedge_tensorflowlite (TBV)
  - wasi_crypto (TBV)
  - wasi_nn-tensorflowlite (TBV)
  - wasi_nn-openvino (TBV)


> ### Attention  
> 1. **TBV** means to be verified. It has been pre-packaged, but complete integration tests have not been added yet, so there may be issues during execution.
> 2. This feature is still in progress, and the naming conventions may change at later.

## Instructions

- To install the above packages, you can simply execute the following commands.

```bash
sudo ctr content fetch <docker_img>:<tag>
sudo ctr install <docker_img>:<tag> -l -r
```

- To remove it, you will need to manually delete the files under the specified path (if they exist).

```bash
rm /opt/containerd/lib/*
rm /opt/containerd/bin/*
```

> ### Attention  
> Installation from the `ctr` command will overwrite the default runtime (shim) search path. So, if you want to run the shim build from source, you should first execute the previous command to remove them and then restart `containerd` using the command below.

```bash
sudo systemctl daemon-reload && sudo systemctl restart containerd
```

## More Examples

We have prepared three daily run demo actions, including [ctr](https://github.com/second-state/runwasi/blob/feature-plugin/.github/workflows/full-testing.yml), [docker](https://github.com/second-state/runwasi/blob/feature-plugin/.github/workflows/docker-demo.yml), and [llama2](https://github.com/second-state/runwasi/blob/feature-plugin/.github/workflows/llama2.yml) (preview). You can check their usage and daily action [status](https://github.com/second-state/runwasi/actions).

## Prebuilt demo image

[Here](https://github.com/second-state/runwasi/pkgs/container/runwasi-demo/versions?filters%5Bversion_type%5D=tagged), we have prebuilt demo images available. You can obtain these same images by simply running `make load_demo` and `make load` (official test case) in the root folder. They are generated based on the test cases in this [directory](https://github.com/second-state/runwasi/tree/main/demo).
