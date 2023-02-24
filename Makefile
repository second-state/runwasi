PREFIX ?= /usr/local
INSTALL ?= install
BUILD_SCRIPT_PATH = $(PWD)/demo/utils/build.rs
HYPER_CLIENT_PATH = demo/hyper/client
HYPER_SERVER_PATH = demo/hyper/server
REQWEST_PATH = demo/reqwest
DB_MYSQL_PATH = demo/db/mysql
DB_MYSQL_ASYNC_PATH = demo/db/mysql_async
MICROSERVICE_DB_PATH = demo/microservice_db
WASINN_PATH = demo/wasinn/pytorch-mobilenet-image/rust
PREOPENS_PATH = demo/wasmedge-rootfs-mounts-demo
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

define build_img
	@if ! test -f $1/build.rs; then \
		echo "Setup build environment for" $1; \
		cd $1; \
		cp $(BUILD_SCRIPT_PATH) .; \
		cargo add --build tar@0.4 sha256@1.1 log@0.4 env_logger@0.10 oci-spec@0.5 anyhow@1.0; \
		cargo add --build oci-tar-builder --git https://github.com/containerd/runwasi --rev a2f86e4; \
	fi
	cd $1 && cargo build --target=wasm32-wasi $(RELEASE_FLAG)
	cd $1 && BUILD_IMAGE=TRUE cargo build --target=wasm32-wasi $(RELEASE_FLAG)
endef

.PHONY: demo/%
demo/%:
	$(call build_img, $(patsubst %/target/wasm32-wasi/$(TARGET)/img.tar,demo/%,$*))

load_demo: $(HYPER_CLIENT_PATH)/target/wasm32-wasi/$(TARGET)/img.tar \
	$(HYPER_SERVER_PATH)/target/wasm32-wasi/$(TARGET)/img.tar \
	$(REQWEST_PATH)/target/wasm32-wasi/$(TARGET)/img.tar \
	$(DB_MYSQL_PATH)/target/wasm32-wasi/$(TARGET)/img.tar \
	$(DB_MYSQL_ASYNC_PATH)/target/wasm32-wasi/$(TARGET)/img.tar \
	$(MICROSERVICE_DB_PATH)/target/wasm32-wasi/$(TARGET)/img.tar \
	$(WASINN_PATH)/target/wasm32-wasi/$(TARGET)/img.tar \
	$(PREOPENS_PATH)/target/wasm32-wasi/$(TARGET)/img.tar
	$(foreach var,$^,\
		sudo ctr -n $(CONTAINERD_NAMESPACE) image import --all-platforms $(var);\
	)
