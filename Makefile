
CC ?= $(EMCC)       # emcc 编译器将通过 emmake 设置
AR ?= $(EMAR)       # emar 将通过 emmake 设置
CFLAGS= -sMEMORY64=1 -Wno-experimental -O3
LUA_LIB= /lua-5.3.4/src/liblua.a 
LUA_INC= -I/lua-5.3.4/src 
AO_IMAGE="p3rmaw3b/ao:0.1.2"

LIB_SQLITE_VEC_DIR=src/lib/sqlite-vec
LIB_SQLITE3_DIR=src/lib/lsqlite
LIB_SQLITE_LEMBED_DIR=src/lib/sql-lembed

EMXX_CFLAGS=-s MEMORY64=1
SRC_PROCESS_DIR=src/process

VENDOR_DIR=vendor/
VENDOR_SQLITE_DIR=vendor/sqlite
VENDOR_LLAMA_DIR=vendor/llama.cpp
VENDOR_AOS_DIR=vendor/aos
BUILD_DIR = .build

DOCKER = sudo docker run

SQLITE_VEC_DEPENDENCY=${LIB_SQLITE_VEC_DIR}/sqlite-vec.c ${VENDOR_SQLITE_DIR} ${BUILD_DIR}
SQLITE_LEMBED_DEPENDENCY=${LIB_SQLITE_LEMBED_DIR}/sqlite-lembed.c ${VENDOR_SQLITE_DIR} ${BUILD_DIR}

SQLITE_VEC_EMCC_OPTION=$(CFLAGS) -o sqlite-vec.o -c src/lib/sqlite-vec/sqlite-vec.c -I${VENDOR_SQLITE_DIR} -DSQLITE_CORE

SQLITE_LEMBED_EMCC_OPTION=$(CFLAGS) -o sqlite-lembed.o -c ${LIB_SQLITE_LEMBED_DIR}/sqlite-lembed.c -I${VENDOR_SQLITE_DIR} \
												 -I${VENDOR_LLAMA_DIR} -DSQLITE_CORE

LSQLITE3_DEPENDENCY=${LIB_SQLITE3_DIR}/lsqlite3.c ${LIB_SQLITE_LEMBED_DIR}/sqlite-lembed.h ${VENDOR_SQLITE_DIR} \
                    ${LIB_SQLITE_VEC_DIR}/sqlite-vec.h ${VENDOR_LLAMA_DIR}

LSQLITE3_EMCC_OPTION=$(CFLAGS) -o lsqlite3.o -c ${LIB_SQLITE3_DIR}/lsqlite3.c ${LUA_LIB} ${LUA_INC} -I${VENDOR_SQLITE_DIR} \
                     -I${LIB_SQLITE_VEC_DIR} -I${LIB_SQLITE_LEMBED_DIR} -I${VENDOR_LLAMA_DIR} -DSQLITE_CORE

SQLITE3_EMCC_OPTION=$(CFLAGS) -o sqlite3.o -c ${VENDOR_SQLITE_DIR}/sqlite3.c 

SQLITE_DEPENDENCY=${VENDOR_SQLITE_DIR}
SQLITE_EMCC_OPTION=

all: ${BUILD_DIR}/process.js ${BUILD_DIR}/process.wasm

${BUILD_DIR}/process.js ${BUILD_DIR}/process.wasm: ${VENDOR_AOS_DIR} ${BUILD_DIR}/libsqlite.so ${BUILD_DIR} ${VENDOR_AOS_DIR} ${BUILD_DIR}/libllama.a ${BUILD_DIR}/libllamacommon.a
	mkdir -p ${VENDOR_AOS_DIR}/process/libs/libsqlite
	chmod -R 777 ${VENDOR_AOS_DIR}/process/libs/libsqlite
	cp ${BUILD_DIR}/libsqlite.so ${VENDOR_AOS_DIR}/process/libs/libsqlite/
	cp ${BUILD_DIR}/libllama* ${VENDOR_AOS_DIR}/process/libs/
	cp ${SRC_PROCESS_DIR}/config.yml ${VENDOR_AOS_DIR}/process/
	${DOCKER} -e DEBUG=1 --platform linux/amd64 -v ./${VENDOR_AOS_DIR}/process:/src ${AO_IMAGE} ao-build-module
	rm -rf test/process.js && mv ${VENDOR_AOS_DIR}/process/process.js test/
	rm -rf test/process.wasm && mv ${VENDOR_AOS_DIR}/process/process.wasm test/

${BUILD_DIR}/libsqlite.so: ${BUILD_DIR}/lsqlite3.o ${BUILD_DIR}/sqlite-vec.o ${BUILD_DIR}/sqlite-lembed.o ${BUILD_DIR}/sqlite3.o
	${DOCKER} -v ./.build:/worker ${AO_IMAGE} sh -c \
    "cd /worker && emar rcs libsqlite.so sqlite-vec.o sqlite-lembed.o lsqlite3.o sqlite3.o $(LUA_LIB)"

${BUILD_DIR}/testsqlite.o:
	${DOCKER} -v ./.build:/worker ${AO_IMAGE} sh -c \
    "cd /worker && emcc rcs libsqlite.so sqlite-vec.o lsqlite3.o sqlite3.o $(LUA_LIB)"

${BUILD_DIR}/lsqlite3.o: ${LSQLITE3_DEPENDENCY} ${BUILD_DIR} ${VENDOR_LLAMA_DIR}
	${DOCKER} -v .:/worker ${AO_IMAGE} sh -c \
    "cd /worker && emcc ${LSQLITE3_EMCC_OPTION}"
	sudo mv lsqlite3.o .build/

${BUILD_DIR}/sqlite-vec.o: ${SQLITE_VEC_DEPENDENCY} ${BUILD_DIR}
	${DOCKER} -v .:/worker ${AO_IMAGE} sh -c \
    "cd /worker && emcc ${SQLITE_VEC_EMCC_OPTION}"
	sudo rm -rf .build/sqlite-vec.o && sudo mv sqlite-vec.o .build/sqlite-vec.o

${BUILD_DIR}/sqlite-lembed.o: ${SQLITE_LEMBED_DEPENDENCY} ${BUILD_DIR}
	${DOCKER} -v .:/worker ${AO_IMAGE} sh -c \
    "cd /worker && emcc ${SQLITE_LEMBED_EMCC_OPTION}"
	sudo mv sqlite-lembed.o ${BUILD_DIR}/

${BUILD_DIR}/sqlite3.o: ${VENDOR_SQLITE_DIR} ${BUILD_DIR}
	${DOCKER} -v .:/worker ${AO_IMAGE} sh -c \
    "cd /worker && emcc ${SQLITE3_EMCC_OPTION}"
	sudo rm -rf .build/sqlite3.o && sudo mv sqlite3.o .build/sqlite3.o

${BUILD_DIR}/libllama.a ${BUILD_DIR}/libllamacommon.a: ${VENDOR_LLAMA_DIR}
	${DOCKER} -v ./${VENDOR_LLAMA_DIR}:/llamacpp ${AO_IMAGE} sh -c \
			"cd /llamacpp && emcmake cmake -DCMAKE_CXX_FLAGS='${EMXX_CFLAGS}' -S . -B . -DLLAMA_BUILD_EXAMPLES=OFF"
	${DOCKER} -v ./${VENDOR_LLAMA_DIR}:/llamacpp ${AO_IMAGE} sh -c \
			"cd /llamacpp && emmake make llama common EMCC_CFLAGS='${EMXX_CFLAGS}'"
	sudo rm -rf .build/libcommon.a && sudo mv ${VENDOR_LLAMA_DIR}/common/libcommon.a .build/libllamacommon.a
	sudo rm -rf .build/libllama.a && sudo mv ${VENDOR_LLAMA_DIR}/libllama.a .build/libllama.a

${VENDOR_SQLITE_DIR}: ${VENDOR_DIR}
	mkdir -p vendor/sqlite
	curl -O "https://www.sqlite.org/2024/sqlite-autoconf-3460100.tar.gz"
	tar zxvf sqlite-autoconf-3460100.tar.gz
	sudo mv sqlite-autoconf-3460100/* ${VENDOR_SQLITE_DIR}/
	rm -rf sqlite-autoconf-3460100*

${VENDOR_AOS_DIR}: ${VENDOR_DIR}
	curl -L -o aos.zip https://github.com/permaweb/aos/archive/3b81b69cc07461126c4e461aca53591b40bd3751.zip
	unzip aos.zip
	mv aos-3b81b69cc07461126c4e461aca53591b40bd3751 vendor/aos
	rm aos.zip

${VENDOR_LLAMA_DIR}: ${VENDOR_DIR}
	cd vendor && git clone https://github.com/ggerganov/llama.cpp.git && cd llama.cpp && git checkout 2b3389677a833cee0880226533a1768b1a9508d2

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(VENDOR_DIR):
	mkdir -p $(VENDOR_DIR)

clean:
	rm -rf .build
	rm -rf ${VENDOR_AOS_DIR}/process/libs/*
