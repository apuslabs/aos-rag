
WORKER_DIR=$(pwd)

LLAMA_CPP_DIR="${WORKER_DIR}/build/lib/llamacpp"
AO_LLAMA_DIR="${WORKER_DIR}/build/src/lib/ao-llama"
PROCESS_DIR="${WORKER_DIR}/aos/process"
LIBS_DIR="${PROCESS_DIR}/libs"

SQLITE_VEC_DIR="${WORKER_DIR}/build/src/lib/sqlite-vec"

BUILD_PROCESS_DIR="${WORKER_DIR}/build/src/process"

AO_IMAGE="p3rmaw3b/ao:0.1.2" # Needs new version
EMXX_CFLAGS="-s MEMORY64=1"


prepare_sqlitevec_lib(){
  sudo docker run -v ${SQLITE_VEC_DIR}:/sqlite-vec ${AO_IMAGE} sh -c \
    "cd /sqlite-vec && emmake make EMCC_CFLAGS='${EMXX_CFLAGS}'" 

  mkdir -p $LIBS_DIR/sqlite-vec
  cp ${SQLITE_VEC_DIR}/libsqlitevec.so $LIBS_DIR/sqlite-vec/libsqlitevec.so
}

prepare_sqlitevec_lib