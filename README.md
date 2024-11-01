# aos-rag

## Intro

This project is designed to provide on-chain **RAG**(**R**etrieval-**A**ugmented **G**eneration) ability on top of [aos](https://cookbook_ao.g8way.io/guides/aos/index.html) process.

The target of the build is an ao module, everyone can start an aos process with this module loaded to achieve the ability to do on-chain **RAG**.

## Quickstart

directly use our module([0FzCdvtr3yldxGsaTBkfdaSchhGwd-2k487ZoIogofI](https://www.ao.link/#/module/0FzCdvtr3yldxGsaTBkfdaSchhGwd-2k487ZoIogofI)).

```Shell
aos {process_name} --module 0FzCdvtr3yldxGsaTBkfdaSchhGwd-2k487ZoIogofI
```

Run `.load` command to load the test lua file.

1. Load Demo Code

```Shell
.load process/rag.lua
```

2. Init Model & Vec DB

```Shell
Send({ Target = ao.id, Action = "Init" })
```

Message received should be `Database initialized`

3. Embedding Data
```Shell
Send({ Target = ao.id, Action = 'Embedding', Data = '["Shohei Ohtanis ex-interpreter pleads guilty to charges related to gambling and theft","The jury has been selected in Hunter Bidens gun trial","Larry Allen, a Super Bowl champion and famed Dallas Cowboy, has died at age 52","After saying Charlotte, a lone stingray, was pregnant, aquarium now says shes sick","An Epoch Times executive is facing money laundering charge"]' })
```

Message received should be `Articles embedded`

4. Retrieve
```Shell
Send({ Target = ao.id, Action = "Retrieve", Data = '{"prompt":"firearm courtroom","limit":3}' })
```

Message received should be in JSON of sorted list contains `headline` & `distance`, distance represents how much headline is similarity with your prompt.

## Contributing

### Compile Module

```Shell
// prepare vendor and make
// Makefile use docker image to build, so if there are difficulties with pulling image
// You can run docker pull to get the image by yourself

make vendor
make
```

#### Compilation Structure

![](./docs/pics/4.png)

##### Step 1:  
- sqlite3.o : sqlite3.c
- libllama.a, common/libcommon.a : llamacpp cmake & make

##### Step 2:
- sqlite-vec.o: sqlite-vec.c -I{SQLITE_DIR} -DSQLITE_CORE
- sqlite-lembed.o: sqlite-lembed.c -I{SQLITE_DIR} -I{LLAMA_DIR} -DSQLITE_CORE

##### Step 3:
- lsqlite3.o: lsqlite3.c -I{SQLITE_VEC_DIR} -I{SQLITE_LEMBED_DIR} -I{LUA_LIB}

##### Step 4:
- libsqlite.so: sqlite3.o sqlite-vec.o sqlite-lembed.o lsqlite3.o

##### Step 5:
- Move libllama.a common/libcommon.a (from step 1) and libsqlite.so (from step 4) to aos/process/libs

##### Step 6:
- Ao build module to generate wasm

### Publish Module

After running `make`, outputs `process.js` and `process.wasm` will be found in the directory `test/`.

```Shell
// The size of output process.wasm may be 4.7M, it will cost 0.003 AR, there should be enough balanc in your AR wallet.

export WALLET='YOUR WALLET JSON FILE LOCATION'
node scripts/deploy_module.js
```

## Reference

- **AO-llama** (https://github.com/PeterFarber/AO-Llama)  
  This project demonstrates how to integrate the llama runtime environment into an AOS process as a callable library. It provides methods for compiling libraries within the process and outlines the basic compilation and linking logic for the llama library.

- **sqlite-lembed** (https://github.com/asg017/sqlite-lembed)
  This project provides the load extension function to support auto loading sqlite-lembed ability. After loaded, the library will provide functions in sqlite statements. We can use them in SQL statements.

- **sqlite-vec** (https://github.com/asg017/sqlite-vec)
  This project provides the load extension function to support auto loading sqlite-vec ability. After loaded, we can use the functions to process vetors and calculate the distance between vectors in SQL statements.