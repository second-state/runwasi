
# special target: https://github.com/docker/metadata-action#bake-definition
target "meta-helper" {}

variable "platforms" {
  default = "linux/amd64,linux/arm64"
}

variable "plugin" {
  default = ""
}

group "default" {
    targets = ["image"]
}

target "image" {
    inherits = ["meta-helper"]
    output = ["type=image"]
    // output = ["type=local,dest=out/"]
}

target "lib" {
    dockerfile = "release/DockerfileLib"
    inherits = ["image"]
    platforms = split(",", "${platforms}")
    args = {
        "PLUGIN" = "${plugin}"
    }
}

target "bin" {
    dockerfile = "release/DockerfileBin"
    inherits = ["image"]
    platforms = split(",", "${platforms}")
    args = {
        "CARGO_FLAGS" = "--no-default-features --features wasi_nn"
    }
}

target "allinone" {
    dockerfile = "release/DockerfileAllInOne"
    inherits = ["image"]
    platforms = split(",", "${platforms}")
    contexts = {
        lib = "target:lib"
        bin = "target:bin"
    }
}