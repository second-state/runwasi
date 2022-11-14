# Demo

## Index
- [Hyper Cleint / Server](https://github.com/CaptainVincent/runwasi/tree/main/demo#demo-1-hyper-cleint--server)
- [Reqwest](https://github.com/CaptainVincent/runwasi/tree/main/demo#demo-2-reqwest)
- [Database](https://github.com/CaptainVincent/runwasi/tree/main/demo#case-3-database)
- [Microservice with Database](https://github.com/CaptainVincent/runwasi/tree/main/demo#case-4-microservice-with-database)
- [WASI NN](https://github.com/CaptainVincent/runwasi/tree/main/demo#case-5-wasi-nn-x86-only)

All below demo cases should be run after all shim components already installed that mentioned in [README.md](../README.md#examples). 

## Build and load all demo images first

- Run
```terminal
$ make load_demo
```

## [Demo 1. Hyper Cleint / Server](https://github.com/WasmEdge/wasmedge_hyper_demo)

### Client

- Run
```terminal
$ sudo ctr run --rm --net-host --runtime=io.containerd.wasmedge.v1 docker.io/library/hyper-demo:latest testclient /client.wasm
```

- Output
```terminal
GET as byte stream: http://eu.httpbin.org/get?msg=Hello
Response: 200 OK
Headers: {
    "date": "Sun, 09 Oct 2022 01:44:00 GMT",
    "content-type": "application/json",
    "content-length": "237",
    "connection": "keep-alive",
    "server": "gunicorn/19.9.0",
    "access-control-allow-origin": "*",
    "access-control-allow-credentials": "true",
}

b"{\n  \"args\": {\n    \"msg\": \"Hello\"\n  }, \n  \"headers\": {\n    \"Host\": \"eu.httpbin.org\", \n    \"X-Amzn-Trace-Id\": \"Root=1-63422760-1b5f693d7024f0f570b296ec\"\n  }, \n  \"origin\": \"60.248.109.122\", \n  \"url\": \"http://eu.httpbin.org/get?msg=Hello\"\n}\n"

GET and get result as string: http://eu.httpbin.org/get?msg=WasmEdge
{
  "args": {
    "msg": "WasmEdge"
  },
  "headers": {
    "Host": "eu.httpbin.org",
    "X-Amzn-Trace-Id": "Root=1-63422760-6adefb9b2ba22bf10b9d924f"
  },
  "origin": "60.248.109.122",
  "url": "http://eu.httpbin.org/get?msg=WasmEdge"
}


POST and get result as string: http://eu.httpbin.org/post
with a POST body: hello wasmedge
{
  "args": {},
  "data": "hello wasmedge",
  "files": {},
  "form": {},
  "headers": {
    "Content-Length": "14",
    "Host": "eu.httpbin.org",
    "X-Amzn-Trace-Id": "Root=1-63422761-243b3dda0da5d7ad571c5e63"
  },
  "json": null,
  "origin": "60.248.109.122",
  "url": "http://eu.httpbin.org/post"
}
```

### Server

- Run
```terminal
$ sudo ctr run --rm --net-host --runtime=io.containerd.wasmedge.v1 docker.io/library/hyper-demo:latest testserver /server.wasm
```

- Output
```terminal
Listening on http://0.0.0.0:8080
```

- Open second session and run
```terminal
$ curl http://127.0.0.1:8080/echo -X POST -d "WasmEdge"
```

- Output
```terminal
WasmEdge%
```

- Kill the running task in container
```terminal
$ sudo ctr task kill -s SIGKILL testserver
```

## [Demo 2. Reqwest](https://github.com/WasmEdge/wasmedge_reqwest_demo)

- Run
```terminal
$ sudo ctr run --rm --net-host --runtime=io.containerd.wasmedge.v1 docker.io/library/reqwest-demo:latest testreqwest
```

- Output
```terminal
Fetching "http://eu.httpbin.org/get?msg=WasmEdge"...
Response: HTTP/1.1 200 OK
Headers: {
    "date": "Wed, 05 Oct 2022 16:13:07 GMT",
    "content-type": "application/json",
    "content-length": "265",
    "connection": "keep-alive",
    "server": "gunicorn/19.9.0",
    "access-control-allow-origin": "*",
    "access-control-allow-credentials": "true",
}

GET: {
  "args": {
    "msg": "WasmEdge"
  },
  "headers": {
    "Accept": "*/*",
    "Host": "eu.httpbin.org",
    "X-Amzn-Trace-Id": "Root=1-633dad13-3eb3296841e5263e42ac4e1b"
  },
  "origin": "60.248.109.122",
  "url": "http://eu.httpbin.org/get?msg=WasmEdge"
}

POST: {
  "args": {},
  "data": "msg=WasmEdge",
  "files": {},
  "form": {},
  "headers": {
    "Accept": "*/*",
    "Content-Length": "12",
    "Host": "eu.httpbin.org",
    "X-Amzn-Trace-Id": "Root=1-633dad13-4745044437058cbd5af71021"
  },
  "json": null,
  "origin": "60.248.109.122",
  "url": "http://eu.httpbin.org/post"
}

PUT: {
  "args": {},
  "data": "msg=WasmEdge",
  "files": {},
  "form": {},
  "headers": {
    "Accept": "*/*",
    "Content-Length": "12",
    "Host": "eu.httpbin.org",
    "X-Amzn-Trace-Id": "Root=1-633dad14-5bd829ce0474c72e03794e50"
  },
  "json": null,
  "origin": "60.248.109.122",
  "url": "http://eu.httpbin.org/put"
}
```

## [Case 3. Database](https://github.com/WasmEdge/wasmedge-db-examples)

**Attention**

You need start mysql service first. Here assume user/password is root/123.

### Insert / Query

- Run - insert
```terminal
$ sudo ctr run --rm --net-host --env DATABASE_URL=mysql://root:123@127.0.0.1:3306/mysql --runtime=io.containerd.wasmedge.v1 docker.io/library/db-demo:latest testdb /insert.wasm
```

- Output
```terminal
[src/bin/insert.rs:91] selected_payments = [
    Payment {
        customer_id: 1,
        amount: 2,
        account_name: None,
    },
    Payment {
        customer_id: 3,
        amount: 4,
        account_name: Some(
            "foo",
        ),
    },
    Payment {
        customer_id: 5,
        amount: 6,
        account_name: None,
    },
    Payment {
        customer_id: 7,
        amount: 8,
        account_name: None,
    },
    Payment {
        customer_id: 9,
        amount: 10,
        account_name: Some(
            "bar",
        ),
    },
]
Yay!
```

- Run - query
```terminal
$ sudo ctr run --rm --net-host --env DATABASE_URL=mysql://root:123@127.0.0.1:3306/mysql --runtime=io.containerd.wasmedge.v1 docker.io/library/db-demo:latest testdb /query.wasm
```

- Output
```terminal 
[src/bin/query.rs:28] selected_dbs = [
    Db {
        host: "localhost",
        db: "performance_schema",
    },
    Db {
        host: "localhost",
        db: "sys",
    },
]
```

### Aync with MySQL

- Run - CRUD
```terminal
$ sudo ctr run --rm --net-host --env DATABASE_URL=mysql://root:123@127.0.0.1:3306/mysql --runtime=io.containerd.wasmedge.v1 docker.io/library/db-demo:latest testdb /crud.wasm
```

- Output
```terminal
create new table
[src/main.rs:134] loaded_orders.len() = 5
[src/main.rs:135] loaded_orders = [
    Order {
        order_id: 1,
        production_id: 12,
        quantity: 2,
        amount: 56.0,
        shipping: 15.0,
        tax: 2.0,
        shipping_address: "Mataderos 2312",
    },
    Order {
        order_id: 2,
        production_id: 15,
        quantity: 3,
        amount: 256.0,
        shipping: 30.0,
        tax: 16.0,
        shipping_address: "1234 NW Bobcat",
    },
    Order {
        order_id: 3,
        production_id: 11,
        quantity: 5,
        amount: 536.0,
        shipping: 50.0,
        tax: 24.0,
        shipping_address: "20 Havelock",
    },
    Order {
        order_id: 4,
        production_id: 8,
        quantity: 8,
        amount: 126.0,
        shipping: 20.0,
        tax: 12.0,
        shipping_address: "224 Pandan Loop",
    },
    Order {
        order_id: 5,
        production_id: 24,
        quantity: 1,
        amount: 46.0,
        shipping: 10.0,
        tax: 2.0,
        shipping_address: "No.10 Jalan Besar",
    },
]
[src/main.rs:160] loaded_orders.len() = 4
[src/main.rs:161] loaded_orders = [
    Order {
        order_id: 1,
        production_id: 12,
        quantity: 2,
        amount: 56.0,
        shipping: 15.0,
        tax: 2.0,
        shipping_address: "Mataderos 2312",
    },
    Order {
        order_id: 2,
        production_id: 15,
        quantity: 3,
        amount: 256.0,
        shipping: 30.0,
        tax: 16.0,
        shipping_address: "1234 NW Bobcat",
    },
    Order {
        order_id: 3,
        production_id: 11,
        quantity: 5,
        amount: 536.0,
        shipping: 50.0,
        tax: 24.0,
        shipping_address: "20 Havelock",
    },
    Order {
        order_id: 5,
        production_id: 24,
        quantity: 1,
        amount: 46.0,
        shipping: 10.0,
        tax: 2.0,
        shipping_address: "No.10 Jalan Besar",
    },
]
[src/main.rs:187] loaded_orders.len() = 4
[src/main.rs:188] loaded_orders = [
    Order {
        order_id: 1,
        production_id: 12,
        quantity: 2,
        amount: 56.0,
        shipping: 15.0,
        tax: 2.0,
        shipping_address: "Mataderos 2312",
    },
    Order {
        order_id: 2,
        production_id: 15,
        quantity: 3,
        amount: 256.0,
        shipping: 30.0,
        tax: 16.0,
        shipping_address: "8366 Elizabeth St.",
    },
    Order {
        order_id: 3,
        production_id: 11,
        quantity: 5,
        amount: 536.0,
        shipping: 50.0,
        tax: 24.0,
        shipping_address: "20 Havelock",
    },
    Order {
        order_id: 5,
        production_id: 24,
        quantity: 1,
        amount: 46.0,
        shipping: 10.0,
        tax: 2.0,
        shipping_address: "No.10 Jalan Besar",
    },
]
```

## [Case 4. Microservice with Database](https://github.com/second-state/microservice-rust-mysql)

- Run
```terminal
$ sudo ctr run --rm --net-host --env DATABASE_URL=mysql://root:123@127.0.0.1:3306/mysql --runtime=io.containerd.wasmedge.v1 docker.io/library/microservice-db-demo:latest testmicroservice
```

- Open second session and run
```terminal
$ curl http://localhost:8080/init
```

- Output
```terminal
{"status":true}%
```

- Then run
```terminal
$ curl http://localhost:8080/create_orders -X POST -d @demo/microservice-rust-mysql/orders.json
```

- Output
```terminal
{"status":true}%
```

- Then run
```terminal
$ curl http://localhost:8080/orders
```

- Output
```terminal
[{"order_id":1,"product_id":12,"quantity":2,"amount":56.0,"shipping":15.0,"tax":2.0,"shipping_address":"Mataderos 2312"},{"order_id":2,"product_id":15,"quantity":3,"amount":256.0,"shipping":30.0,"tax":16.0,"shipping_address":"1234 NW Bobcat"},{"order_id":3,"product_id":11,"quantity":5,"amount":536.0,"shipping":50.0,"tax":24.0,"shipping_address":"20 Havelock"},{"order_id":4,"product_id":8,"quantity":8,"amount":126.0,"shipping":20.0,"tax":12.0,"shipping_address":"224 Pandan Loop"},{"order_id":5,"product_id":24,"quantity":1,"amount":46.0,"shipping":10.0,"tax":2.0,"shipping_address":"No.10 Jalan Besar"}]%
```

- Then run
```terminal
$ curl http://localhost:8080/update_order -X POST -d @demo/microservice-rust-mysql/update_order.json
```

- Output
```terminal
{"status":true}%
```

- Then run
```terminal
$ curl http://localhost:8080/delete_order?id=2
```

- Output
```terminal
{"status":true}%
```

- Kill the running task in container
```terminal
$ sudo ctr task kill -s SIGKILL testmicroservice
```

## [Case 5. WASI NN (x86 only)](https://github.com/second-state/WasmEdge-WASINN-examples)

### Setup tools

- Run setup_wasinn_plugin.sh script to download PyTorch library, Wasmedge Library and WASINN PyTorch plugin. After that update library search path to system.

> **Attention**
Here will overwrite your libwasmedge search path

```terminal
$ ./demo/utils/setup_wasinn_plugin.sh
```

- Add we also need set environment WASMEDGE_PLUGIN_PATH for containerd service

Paste below content after run `sudo EDITOR=vim systemctl edit containerd`, replace `<Your Plugin Install Path>` to env `$WASMEDGE_PLUGIN_PATH` (was set by setup_wasinn_plugin.sh)
```terminal
[Service]
Environment="WASMEDGE_PLUGIN_PATH=<Your Plugin Install Path>"
```

- Build and install wasmedge shim with support wasi-nn plugin
```terminal
$ make build FEATURES=wasmedge,wasi_nn
$ sudo make install
```

- Download test image
```terminal
wget --no-clobber https://github.com/bytecodealliance/wasi-nn/raw/main/rust/examples/images/1.jpg -O demo/wasinn/pytorch-mobilenet-image/input.jpg
```

Congratulations!! We done.

### Execution

- Run
```terminal
sudo ctr run --rm --mount type=bind,src=$(pwd)/demo/wasinn/pytorch-mobilenet-image,dst=/resource,options=rbind:ro --runtime=io.containerd.wasmedge.v1 docker.io/library/wasinn-demo:latest testwasinn /wasm /resource/mobilenet.pt /resource/input.jpg
```

- Output
```terminal
Read torchscript binaries, size in bytes: 14376860
Loaded graph into wasi-nn with ID: 0
Created wasi-nn execution context with ID: 0
Read input tensor, size in bytes: 602112
Executed graph inference
   1.) [954](20.6681)banana
   2.) [940](12.1483)spaghetti squash
   3.) [951](11.5748)lemon
   4.) [950](10.4899)orange
   5.) [953](9.4834)pineapple, ananas
```