
CC ?= $(EMCC)       # emcc 编译器将通过 emmake 设置
AR ?= $(EMAR)       # emar 将通过 emmake 设置
CFLAGS= -sMEMORY64=1 -Wno-experimental -O3
LUA_LIB= /lua-5.3.4/src/liblua.a 
LUA_INC= -I/lua-5.3.4/src 


COMMIT=$(shell git rev-parse HEAD)
VERSION=$(shell cat VERSION)
DATE=$(shell date +'%FT%TZ%z')

all: libsqlite.so

libsqlitec.so: sqlite-vec.o lsqlite3.o sqlite3.o
	$(AR) rcs libsqlitevec.so sqlite-vec.o lsqlite3.o sqlite3.o $(LUA_LIB)
	rm *.o

sqlite-lembed.o: sqlite-lembed.c 
	$(CC) $(CFLAGS) -o sqlite-lembed.o -c sqlite-lembed.c

sqlite-vec.o: sqlite-vec.c
	$(CC) $(CFLAGS) -o sqlite-vec.o -c sqlite-vec.c -DSQLITE_CORE

lsqlite3.o: lsqlite3.c sqlite-lembed.h
	$(CC) $(CFLAGS) -o lsqlite3.o -c lsqlite3.c ${LUA_INC} -DSQLITE_CORE

sqlite3.o: sqlite3.c
	$(CC) $(CFLAGS) -o sqlite3.o -c sqlite3.c

clean:
	rm -f *.o *.so
