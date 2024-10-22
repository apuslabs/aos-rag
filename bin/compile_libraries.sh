# SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
WORKER_DIR=$(pwd)

LLAMA_CPP_DIR="${WORKER_DIR}/build/lib/llamacpp"
AO_LLAMA_DIR="${WORKER_DIR}/build/src/lib/ao-llama"
PROCESS_DIR="${WORKER_DIR}/aos/process"
LIBS_DIR="${PROCESS_DIR}/libs"

SQLITE_VEC_DIR="${WORKER_DIR}/build/src/lib/sqlite-vec"

BUILD_PROCESS_DIR="${WORKER_DIR}/build/src/process"

AO_IMAGE="p3rmaw3b/ao:0.1.2" # Needs new version
EMXX_CFLAGS="-s MEMORY64=1"

prepare_llamacpp(){
  sed -i.bak 's/#define ggml_assert_aligned.*/#define ggml_assert_aligned\(ptr\)/g' ${LLAMA_CPP_DIR}/ggml.c
  sed -i.bak '/.*GGML_ASSERT.*GGML_MEM_ALIGN == 0.*/d' ${LLAMA_CPP_DIR}/ggml.c

  # Build llama.cpp into a static library with emscripten
  sudo docker run -v ${LLAMA_CPP_DIR}:/llamacpp ${AO_IMAGE} sh -c \
      "cd /llamacpp && emcmake cmake -DCMAKE_CXX_FLAGS='${EMXX_CFLAGS}' -S . -B . -DLLAMA_BUILD_EXAMPLES=OFF"

  sudo docker run -v ${LLAMA_CPP_DIR}:/llamacpp ${AO_IMAGE} sh -c \
      "cd /llamacpp && emmake make llama common EMCC_CFLAGS='${EMXX_CFLAGS}'" 

  rm ${LLAMA_CPP_DIR}/ggml.c && mv ${LLAMA_CPP_DIR}/ggml.c.bak ${LLAMA_CPP_DIR}/ggml.c
}

prepare_ao_llama(){
  sudo docker run -v ${LLAMA_CPP_DIR}:/llamacpp  -v ${AO_LLAMA_DIR}:/ao-llama ${AO_IMAGE} sh -c \
      "cd /ao-llama && emmake make"
}

prepare_process_lib(){
  # # Copy llama.cpp to the libs directory
  mkdir -p $LIBS_DIR/llamacpp/common
  cp ${LLAMA_CPP_DIR}/libllama.a $LIBS_DIR/llamacpp/libllama.a
  cp ${LLAMA_CPP_DIR}/common/libcommon.a $LIBS_DIR/llamacpp/common/libcommon.a

  # Copy ao-llama to the libs directory
  mkdir -p $LIBS_DIR/ao-llama
  cp ${AO_LLAMA_DIR}/libaollama.so $LIBS_DIR/ao-llama/libaollama.so
  cp ${AO_LLAMA_DIR}/libaostream.so $LIBS_DIR/ao-llama/libaostream.so
}

prepare_sqlitevec_lib(){
  sudo docker run -v ${SQLITE_VEC_DIR}:/sqlite-vec ${AO_IMAGE} sh -c \
    "cd /sqlite-vec && emmake make EMCC_CFLAGS='${EMXX_CFLAGS}'" 

  mkdir -p $LIBS_DIR/sqlite-vec
  cp ${SQLITE_VEC_DIR}/libsqlitevec.so $LIBS_DIR/sqlite-vec/libsqlitevec.so
}

prepare_process_files(){
  # Copy config.yml to the process directory
  cp ${BUILD_PROCESS_DIR}/* ${PROCESS_DIR}/
}

ao_build_module(){
  # Build the process module
  cd ${PROCESS_DIR} 
  rm -rf ${PROCESS_DIR}/process.wasm ${PROCESS_DIR}/process.js
  docker run -e DEBUG=1 --platform linux/amd64 -v ./:/src ${AO_IMAGE} ao-build-module

  cd ${WORKER_DIR}
}

process_output(){
  mkdir -p $WORKER_DIR/out
  cp ${PROCESS_DIR}/process.wasm ${WORKER_DIR}/out/process.wasm
  cp ${PROCESS_DIR}/process.js ${WORKER_DIR}/out/process.js
}

# prepare_llamacpp
# prepare_ao_llama
# prepare_process_lib
prepare_sqlitevec_lib
# prepare_process_files
# ao_build_module
# process_output