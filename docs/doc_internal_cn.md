# aos-rag

## 简介

该项目旨在为 [aos](https://cookbook_ao.g8way.io/guides/aos/index.html) 进程提供链上 **RAG**（**R**etrieval-**A**ugmented **G**eneration，检索增强生成）功能。

构建的目标是一个 ao 模块，任何人都可以加载此模块并启动 aos 进程，以实现链上 **RAG** 功能。

* 该功能与 SQLite3 库紧密结合，所有能力都集成到 SQLite3 扩展中。

## 参考项目

- **AO-llama** (https://github.com/PeterFarber/AO-Llama)  
  此项目展示了如何将 llama 运行环境集成到 AOS 进程中作为可调用库。它提供了在进程中编译库的方法，并概述了 llama 库的基本编译和链接逻辑。

- **sqlite-lembed** (https://github.com/asg017/sqlite-lembed)  
  此项目提供了加载扩展函数以支持自动加载 sqlite-lembed 功能。加载后，可以在 SQL 语句中使用该库提供的功能。

- **sqlite-vec** (https://github.com/asg017/sqlite-vec)  
  此项目提供了加载扩展函数以支持自动加载 sqlite-vec 功能。加载后，可以使用这些函数在 SQL 语句中处理向量并计算向量之间的距离。

## 快速开始

```Shell
// 准备 vendor 并编译
// Makefile 使用 Docker 镜像进行构建，如果拉取镜像有困难，可以先自行拉取

make vendor
make
```

运行 `make` 后，输出文件 `process.js` 和 `process.wasm` 将在 `test/` 目录中找到。

```Shell
// 输出的 process.wasm 大小可能为 4.7M，约耗费 0.003 AR，请确保 AR 钱包中有足够余额。

export WALLET='你的钱包 JSON 文件位置'
node scripts/deploy_module.js
```

你可以加载刚更新的模块，或者直接使用我们提供的模块。

```Shell
aos {process_name} --module={module_id}
```

运行命令以加载 aos-rag 模块启动进程。

```Shell
.load process/main.lua
```

运行 `.load` 命令加载测试 lua 文件。

### 测试

```SQL
  INSERT INTO temp.lembed_models(name, model) select 'all-MiniLM-L6-v2', lembed_model_from_file('/data/0FzCdvtr3yldxGsaTBkfdaSchhGwd-2k487ZoIogofI');
```

首先，通过上述 SQL 语句加载模型。


```SQL
  create table articles(
    headline text
  );
  
  -- 2024-06-04 的随机 NPR 标题
  insert into articles VALUES
    ('Shohei Ohtani''s ex-interpreter pleads guilty to charges related to gambling and theft'),
    ('The jury has been selected in Hunter Biden''s gun trial'),
    ('Larry Allen, a Super Bowl champion and famed Dallas Cowboy, has died at age 52'),
    ('After saying Charlotte, a lone stingray, was pregnant, aquarium now says she''s sick'),
    ('An Epoch Times executive is facing money laundering charge');
```

然后，创建名为 articles 的表并插入记录。


```SQL
  -- 使用标题嵌入构建向量表
  create virtual table vec_articles using vec0(
    headline_embeddings float[1600]
  );
  
  insert into vec_articles(rowid, headline_embeddings)
    select rowid, lembed('all-MiniLM-L6-v2', headline)
    from articles;
```

使用 `vec0` 扩展创建 `vec_articles` 表，并为 `articles` 表中的每条记录调用 `lembed` 函数插入向量。

### 编译结构

![](./pics/4.png)

##### 第一步：  
- sqlite3.o : sqlite3.c
- libllama.a, common/libcommon.a : llamacpp cmake & make

##### 第二步：
- sqlite-vec.o: sqlite-vec.c -I{SQLITE_DIR} -DSQLITE_CORE
- sqlite-lembed.o: sqlite-lembed.c -I{SQLITE_DIR} -I{LLAMA_DIR} -DSQLITE_CORE

##### 第三步：
- lsqlite3.o: lsqlite3.c -I{SQLITE_VEC_DIR} -I{SQLITE_LEMBED_DIR} -I{LUA_LIB}

##### 第四步：
- libsqlite.so: sqlite3.o sqlite-vec.o sqlite-lembed.o lsqlite3.o

##### 第五步：
- 将 libllama.a、common/libcommon.a（来自第一步）和 libsqlite.so（来自第四步）移动到 aos/process/libs

##### 第六步：
- Ao 编译模块以生成 wasm

### 源代码介绍

我们需要找到库的入口。因此，我们可以从测试文件中学习。

(来源: https://github.com/PeterFarber/AO-Llama/blob/main/test-llm/afs.test.js#L23)

```typescript
const res = await instance.cwrap('handle', 'string', ['string', 'string'], { async: true })(JSON.stringify(msg), JSON.stringify(env))
```

函数调用可以追踪到以下位置：

(来源: https://github.com/permaweb/aos/blob/main/process/process.lua#L247)

因此，该函数用于监控 aos 进程中的环境。

另外，我们还需要弄清楚源代码在 aos 进程中是如何捆绑的，以及如何访问 lua 蓝图中的函数。

我们知道所有的库 `.so`、`.a` 都是通过 `ao-build-module` 命令链接到 `p3rmaw3b/ao:0.1.4` 镜像中的。所以这个镜像可能来自 [https://github.com/permaweb/ao](https://github.com/permaweb/ao)。搜索 `ao-build-module` 后，我们可以找到以下 Dockerfile 中的构建命令。

```shell
COPY ./src/ao-build-module /usr/local/bin/ao-build-module
```

(来源: https://github.com/permaweb/ao/blob/a83cc872b48bd79e4b7f8f4d9c4451c745550fcb/dev-cli/container/Dockerfile#L87)

`ao-build-module` 命令的主要逻辑存在于以下文件中：[https://github.com/permaweb/ao/blob/a83cc872b48bd79e4b7f8f4d9c4451c745550fcb/dev-cli/container/src/ao-build-module](https://github.com/permaweb/ao/blob/a83cc872b48bd79e4b7f8f4d9c4451c745550fcb/dev-cli/container/src/ao-build-module)。


根据 ao-llama 项目的逻辑，这些库存储在 `aos/process/libs` 目录中。我们可以牢记这一点并检查源代码。

扩展库：
(来源: https://github.com/permaweb/ao/blob/a83cc872b48bd79e4b7f8f4d9c4451c745550fcb/dev-cli/container/src/ao-build-module#L142-L146)

加载库逻辑：
(来源: https://github.com/permaweb/ao/blob/a83cc872b48bd79e4b7f8f4d9c4451c745550fcb/dev-cli/container/src/ao-build-module#L84)
(来源: https://github.com/permaweb/ao/blob/a83cc872b48bd79e4b7f8f4d9c4451c745550fcb/dev-cli/container/src/ao_module_lib/libraries.py#L27)

扫描 `src/libs` 中的库包：
(来源: https://github.com/permaweb/ao/blob/a83cc872b48bd79e4b7f8f4d9c4451c745550fcb/dev-cli/container/src/ao_module_lib/libraries.py#L45-L48)

按模式加载库 `[^dD] _?luaopen_([0-9a-zA-Z!"#\$%&\'\(\)\*\+,\-\.\/:;\<=\>\?@\[\]^_`\{\|\}~]+)`
(来源: https://github.com/permaweb/ao/blob/a83cc872b48bd79e4b7f8f4d9c4451c745550fcb/dev-cli/container/src/ao_module_lib/libraries.py#L80-L85)

因此，这些库的入口是名为 `luaopen_XXXX()` 的函数。

如果我们希望通过简单的 `local sqlite = require('lsqlite3')` 语句在 sqlite 扩展中支持 `sqlite-vec` 和 `sqlite-lembed`，则这些源代码中应该有一个名为 `luaopen_lsqlite3` 的函数。在此函数中，应该加载 `vec` 和 `lembed` 扩展，因此我们可以学习 `sqlite-vec` 和 `sqlite-lembed` 项目，看看如何实现。

(sqlite-vec: https://github.com/asg017/sqlite-vec/blob/main/examples/simple-c/demo.c#L12

)
(sqlite-lembed: )

看起来 `sqlite-lembed` 项目中没有相关示例，但 `sqlite-vec.c` 和 `sqlite-lembed.c` 文件具有相似的结构和功能。
(sqlite-lembed: https://github.com/asg017/sqlite-lembed/blob/main/sqlite-lembed.c#L855C9-L855C28)

我们只需使用这两个函数来加载 sqlite3 扩展，所有支持 RAG 的功能都将被自动检测并添加。

![](./pics/5.png)

基础的 `lsqlite3.c` 来自 github 仓库 aos-sqlite。
(来源: https://github.com/permaweb/aos-sqlite/blob/main/container/src/lsqlite3.c)

在做出决定后，我必须考虑这样做是否合规。比如，为什么这个函数不需要 sqlite 实例，或这句话如何影响所有 sqlite3 实例等问题出现。

函数 `sqlite3_auto_extension` 可以在 sqlite3.c 中找到：L137920，

![](./pics/6.png)

我们可以清楚地看到该函数没有被调用，只是被注册在某处，附加在全局对象上。而函数 `sqlite3_vec_init` 和 `sqlite3_lembed_init` 都具有 `sqlite3 *db` 参数。因此，在 `luaopen_lsqlite3` 函数中的修改很可能会生效，因为我们只是将两个初始化方法加入了原本的队列中。然后，当创建新的 sqlite3 实例时，这些函数将回调以加载这些方法。

接下来，当前的编译逻辑过于复杂，难以调试和测试。不同的项目有不同的脚本或 makefile 来获取输出。我们应制作一个简单的 makefile 来完成所有任务。

`lsqlite` 入口肯定在最顶层，因为它是最接近 Lua 层的。接下来是 `sqlite-vec`，它没有依赖项，仅提供计算向量距离的功能。`sqlite-lembed` 组件负责文本分词和嵌入，依赖 `llama` 库。所有这些功能基于基础的 sqlite 库。

因此我们有三个依赖：
- aos，接收库文件输入并编译成 wasm 模块。
- llama.cpp，为 `sqlite-lembed` 提供功能。
- sqlite，所有项目的基础。

在编译这些对象文件时：
- `lsqlite` 访问 Lua 接口，因此它需要加载头文件和 Lua 库本身，因为我们不会单独编译 Lua 运行时。
- `sqlite-vec` 和 `sqlite-lembed` 需要开启 `SQLITE_CORE` 宏。
  \* 我最初以为不能在 `SQLITE_CORE` 模式下运行，因为函数 `sqlite3_column_type` 是一个宏函数 `sqlite3_api->column_type`，需要声明 `sqlite3_api`。实际上，相同函数在 `sqlite.h` 中有定义，因此启用 `SQLITE_CORE` 也可以正常工作。

  ```c
  // sqlite3_ext.h L433
  #define sqlite3_column_type            sqlite3_api->column_type
  ``` 
  ```c
  // sqlite.h L5281
  SQLITE_API int sqlite3_column_type(sqlite3_stmt*, int iCol);
  ```
- 保留 llama.cpp 的 make 逻辑，因为修改难度大。项目的输出是两个 `.a` 库文件，将这些文件放入 process/libs 即可。

到此为止，所有工作已完成，我们可以运行 make 和 test 以检查源代码本身。

`sqlite-lembed` 项目运行并不顺利，因此我们花了很多时间进行调试。  

我们遇到的第一个问题是本地环境在多线程模式下运行，但 wasm 仅支持单线程。出现了 `rc == 0` 的断言错误，并显示行号，因此我们查看 `vendor/llama.cpp/ggml.c:L19523` 文件的上下文，发现设置来自 llama 上下文，可以在 `lembed_modelsUpdate` 函数中将 `n_threads` 限制为 1，错误便会消失。

![](./pics/7.png)

接下来我们发现距离结果未显示，其他性能正常。所以我们在源代码中使用 `EM_ASM` 函数从 `emscription.h` 执行 JavaScript 代码来记录日志。

调用链如下所示：

![](./pics/8.png)

`lembed` 函数是 SQL 语句 `lembed(model_name, text)` 的入口。在该函数中，`api_model_from_name` 根据模型名称设置模型，并调用 `embed_single` 获取 `out_embeddings`。在 `llama_decode` 函数中，图将被构建并计算得到浮点数组结果。

此时遇到的问题是输出的嵌入数组全为 `NaN`。这是因为 `lctx` 的 `embd` 全为零，零数组平方和的根作为除数，导致生成的嵌入数组为 `NaN`。

我们开始研究可能的原因，排除许多可能后，我们开始怀疑可能是模型计算层面的问题，某些宏未启用。或者这可能是 WASM 兼容性问题，导致某些方法失效。

由于模型内部的计算主要是大量的向量运算，与底层关系不大，不应受到这种移植兼容性问题的影响，因此我们认为是模型加载的问题。

最后，不再深入，跳脱出来看，确实是模型文件加载出了问题，最终问题得到解决，模块成功编译发布。

不过，解决问题的思路和调试方法仍然值得记录，作为未来项目的基石。