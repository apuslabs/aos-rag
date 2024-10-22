
CC ?= $(EMCC)       # emcc 编译器将通过 emmake 设置
AR ?= $(EMAR)       # emar 将通过 emmake 设置
CFLAGS= -sMEMORY64=1 -Wno-experimental 
LUA_LIB= /lua-5.3.4/src/liblua.a 
LUA_INC= -I/lua-5.3.4/src 
LLAMA_INC= -I/llamacpp/ -I/llamacpp/common 

all: libaollama.so libaostream.so

libaollama.so: llama-bindings.o llama-run.o
	$(AR) rcs libaollama.so llama-bindings.o llama-run.o
	rm llama-bindings.o llama-run.o

llama-bindings.o: llama-bindings.c
	$(CC) $(CFLAGS) -c llama-bindings.c -o llama-bindings.o $(LUA_LIB) $(LUA_INC) $(LLAMA_INC)

llama-run.o: llama-run.cpp
	$(CC) $(CFLAGS) -c llama-run.cpp -o llama-run.o $(LLAMA_INC)

libaostream.so: stream-bindings.o stream.o
	$(AR) rcs libaostream.so stream-bindings.o stream.o
	rm stream.o stream-bindings.o

stream-bindings.o: stream-bindings.c
	$(CC) $(CFLAGS) -c stream-bindings.c -o stream-bindings.o $(LUA_LIB) $(LUA_INC)

stream.o: stream.c
	$(CC) $(CFLAGS) -c stream.c -o stream.o $(LUA_LIB) $(LUA_INC)

clean:
	rm -f *.o *.so
