PREFIX ?= /usr/local
INSTALL ?= install
TEST_IMG_NAME ?= wasmtest:latest
HYPER_DIRS = $(shell find demo/hyper -type d)
HYPER_FILES = $(shell find demo/hyper -type f -name '*')
HYPER_IMG_NAME ?= hyper-demo:latest
REQWEST_DIRS = $(shell find demo/reqwest -type d)
REQWEST_FILES = $(shell find demo/reqwest -type f -name '*')
REQWEST_IMG_NAME ?= reqwest-demo:latest
DB_DIRS = $(shell find demo/db -type d)
DB_FILES = $(shell find demo/db -type f -name '*')
DB_IMG_NAME ?= db-demo:latest
MICROSERVICE_DB_DIRS = $(shell find demo/microservice_db -type d)
MICROSERVICE_DB_FILES = $(shell find demo/microservice_db -type f -name '*')
MICROSERVICE_DB_IMG_NAME ?= microservice-db-demo:latest
WASINN_DIRS = $(shell find demo/wasinn -type d)
WASINN_FILES = $(shell find demo/wasinn -type f -name '*')
WASINN_IMG_NAME ?= wasinn-demo:latest
PREOPENS_DIRS = $(shell find demo/wasmedge-rootfs-mounts-demo -type d)
PREOPENS_FILES = $(shell find demo/wasmedge-rootfs-mounts-demo -type f -name '*')
PREOPENS_IMG_NAME ?= preopens-demo:latest
export CONTAINERD_NAMESPACE ?= default

TARGET ?= debug
RELEASE_FLAG :=
ifeq ($(TARGET),release)
RELEASE_FLAG = --release
endif

FEATURES_FLAG :=
ifneq ($(FEATURES),)
FEATURES_FLAG = --features $(FEATURES)
endif

RUNTIME :=
ifneq ($(RUNTIME),)
RUNTIME = $(shell echo ${FEATURES} | grep -o "wasmedge")
endif

.PHONY: build
build:
	cargo build $(RELEASE_FLAG) $(FEATURES_FLAG)

clean:
	cargo clean

.PHONY: install
install:
	$(INSTALL) target/$(TARGET)/containerd-shim-$(RUNTIME)-v1 $(PREFIX)/bin
	$(INSTALL) target/$(TARGET)/containerd-shim-$(RUNTIME)d-v1 $(PREFIX)/bin
	$(INSTALL) target/$(TARGET)/containerd-$(RUNTIME)d $(PREFIX)/bin

.PHONY: target/wasm32-wasi/$(TARGET)/wasi-demo-app.wasm
target/wasm32-wasi/$(TARGET)/wasi-demo-app.wasm:
	cd crates/wasi-demo-app && cargo build

.PHONY: target/wasm32-wasi/$(TARGET)/img.tar
target/wasm32-wasi/$(TARGET)/img.tar: target/wasm32-wasi/$(TARGET)/wasi-demo-app.wasm
	cd crates/wasi-demo-app && cargo build --features oci-v1-tar

load: target/wasm32-wasi/$(TARGET)/img.tar
	sudo ctr -n $(CONTAINERD_NAMESPACE) image import --all-platforms $<

demo/out/hyper_img.tar: demo/images/hyper.Dockerfile \
	$(HYPER_DIRS) $(HYPER_FILES) $(TOKIO_DIRS) $(TOKIO_FILES)
	mkdir -p $(@D)
	docker buildx build --platform=wasi/wasm -o type=docker,dest=$@ -t $(HYPER_IMG_NAME) -f ./demo/images/hyper.Dockerfile ./demo

demo/out/reqwest_img.tar: demo/images/reqwest.Dockerfile \
	$(REQWEST_DIRS) $(REQWEST_FILES)
	mkdir -p $(@D)
	docker buildx build --platform=wasi/wasm -o type=docker,dest=$@ -t $(REQWEST_IMG_NAME) -f ./demo/images/reqwest.Dockerfile ./demo

demo/out/db_img.tar: demo/images/db.Dockerfile \
	$(DB_DIRS) $(DB_FILES)
	mkdir -p $(@D)
	docker buildx build --platform=wasi/wasm -o type=docker,dest=$@ -t $(DB_IMG_NAME) -f ./demo/images/db.Dockerfile ./demo

demo/out/microservice_db_img.tar: demo/images/microservice_db.Dockerfile \
	$(MICROSERVICE_DB_DIRS) $(MICROSERVICE_DB_FILES)
	mkdir -p $(@D)
	docker buildx build --platform=wasi/wasm -o type=docker,dest=$@ -t $(MICROSERVICE_DB_IMG_NAME) -f ./demo/images/microservice_db.Dockerfile ./demo

demo/out/wasinn_img.tar: demo/images/wasinn.Dockerfile \
	$(WASINN_DIRS) $(WASINN_FILES)
	mkdir -p $(@D)
	docker buildx build --platform=wasi/wasm -o type=docker,dest=$@ -t $(WASINN_IMG_NAME) -f ./demo/images/wasinn.Dockerfile ./demo

demo/out/preopens.tar: demo/images/preopens.Dockerfile \
	$(PREOPENS_DIRS) $(PREOPENS_FILES)
	mkdir -p $(@D)
	docker buildx build --platform=wasi/wasm -o type=docker,dest=$@ -t $(PREOPENS_IMG_NAME) -f ./demo/images/preopens.Dockerfile ./demo

load_demo: demo/out/hyper_img.tar \
	demo/out/db_img.tar \
	demo/out/reqwest_img.tar \
	demo/out/microservice_db_img.tar \
	demo/out/wasinn_img.tar \
	demo/out/preopens.tar
	$(foreach var,$^,\
		sudo ctr -n $(CONTAINERD_NAMESPACE) image import $(var);\
	)

