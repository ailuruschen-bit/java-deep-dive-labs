# 纯 Java 运行实验

本实验使用 JDK 21，不依赖 IDE、Maven 或 Gradle。在本目录执行：

```bash
./run-experiments.sh
```

脚本会检查 `java` 和 `javac` 都是 21，并在子 shell 中清除继承的 `CLASSPATH` 和 Java 启动选项，以保证演示结果一致。它不会修改终端原有的环境配置。每次执行都会重新编译本轮用到的 class 文件；下面出现的三个加载失败也是验证内容，脚本会检查对应错误。

命令使用 macOS/Linux 的 classpath 条目分隔符 `:`；Windows 手工执行时使用 `;`。代码注释统一使用英文。

## 1. 从当前目录编译并启动

工作目录是 `step-1/`：

```bash
javac Main.java
java Main
```

输出：

```text
Hello, Java!
```

`javac` 默认把 class 文件生成在对应的源文件旁。在这里，源文件恰好也位于工作目录。仍在 `step-1/`，使用 `-d` 指定输出位置：

```bash
javac -d out Main.java
```

```text
step-1/
├── Main.java
├── Main.class
└── out/
    └── Main.class
```

## 2. 为类增加包名

将新的 `Main.java` 放入 `step-2/out/dev/deepdive/app/`，包声明为 `package dev.deepdive.app;`。编译和启动时，工作目录一直是 `step-2/out/`：

```bash
javac dev/deepdive/app/Main.java
java dev.deepdive.app.Main
```

输出仍然是 `Hello, Java!`。编译后：

```text
step-2/
└── out/                         ← 此时的工作目录
    └── dev/
        └── deepdive/
            └── app/
                ├── Main.java
                └── Main.class
```

## 3. 改变工作目录，再指定搜索起点

现在从 `out/` 返回父目录 `step-2/`：

```bash
cd ..
java dev.deepdive.app.Main
```

此时默认从 `step-2/` 开始找，拼接出的路径是 `step-2/dev/deepdive/app/Main.class`，缺少真正存放 class 文件的那层 `out/`，因此报告：

```text
Error: Could not find or load main class dev.deepdive.app.Main
Caused by: java.lang.ClassNotFoundException: dev.deepdive.app.Main
```

继续留在 `step-2/`，通过 `-cp out` 将 classpath 设为只包含 `out` 这一个目录条目，以 `step-2/out/` 作为类文件的搜索起点：

```bash
java -cp out dev.deepdive.app.Main
```

这次输出 `Hello, Java!`。这里的 `out` 是相对于当前工作目录的路径。

## 4. 在一个 classpath 中配置多个条目

这里模拟一个使用外部依赖的项目：我们编写的 `Main` 调用 `Greeting`，`Greeting` 再调用 `Punctuation`。`Greeting` 和 `Punctuation` 已由依赖提供方定义，包名分别为 `dev.deepdive.greeting` 和 `dev.deepdive.punctuation`。作为使用方，我们只使用它们编译好的 class 产物，并保留提供方定义的包名；自己的 `Main` 则位于 `dev.deepdive.app` 包中。

为了让实验能够完整复现，仓库在 `multiple-classpath/src/` 下保留了这三个类的源码。下面先编译两个依赖，是在模拟提供方构建产物的步骤；接着编译和运行 `Main` 时，使用的是这些 class 产物。

脚本会创建 `deployment/`。以下命令均以它作为工作目录：

```bash
javac -d lib002 \
  ../multiple-classpath/src/punctuation/dev/deepdive/punctuation/Punctuation.java

javac -cp lib002 -d lib001 \
  ../multiple-classpath/src/greeting/dev/deepdive/greeting/Greeting.java

javac -cp 'lib001:lib002' -d . \
  ../multiple-classpath/src/app/dev/deepdive/app/Main.java
```

编译时的 `javac -cp` 设置 classpath，本例中的每个目录条目都提供一个类文件搜索起点；`-d` 指明这次编译结果的输出起点。生成的目录是：

```text
deployment/                     ← 工作目录，也是 Main 的搜索起点
├── dev/
│   └── deepdive/
│       └── app/
│           └── Main.class
├── lib001/                     ← Greeting 的搜索起点
│   └── dev/
│       └── deepdive/
│           └── greeting/
│               └── Greeting.class
└── lib002/                     ← Punctuation 的搜索起点
    └── dev/
        └── deepdive/
            └── punctuation/
                └── Punctuation.class
```

仍在 `deployment/` 启动：

```bash
java -cp '.:lib001:lib002' dev.deepdive.app.Main
```

输出为 `Hello, classpath!`。这里配置的是一个 classpath，其中包含 `.`、`lib001`、`lib002` 三个目录条目。每个条目都是一个类文件搜索起点，从该目录出发，再按照类名对应的包结构继续寻找。

## 5. 把存放目录误写进类名

提供方编写 `Greeting.java` 时，包声明是 `package dev.deepdive.greeting;`，没有 `lib001`。`lib001` 是我们保存依赖的目录，不能因此给类名增加一个 `lib001.` 前缀。

仍在 `deployment/`，观察下面的错误命令：

```bash
java -cp . lib001.dev.deepdive.greeting.Greeting
```

虽然能按照这个名字找到 `lib001/dev/deepdive/greeting/Greeting.class`，文件内记录的名称却是 `dev.deepdive.greeting.Greeting`，因此在加载阶段出现 `NoClassDefFoundError`，并提示 `wrong name: dev/deepdive/greeting/Greeting`。

这一步专门观察名称不一致导致的错误；`Greeting` 本身只是依赖类，没有 `main` 方法。

## 6. 漏掉一个依赖目录

仍在 `deployment/`，让 classpath 只包含 `.` 和 `lib001` 两个条目：

```bash
java -cp '.:lib001' dev.deepdive.app.Main
```

这次 `Main` 已经启动，`Greeting` 也能被找到。但执行到 `Greeting` 对 `Punctuation` 的调用时，classpath 中缺少 `lib002` 条目，类加载器找不到 `Punctuation`。本例的这次加载失败以 `ClassNotFoundException` 作为原因，最终向程序报告 `NoClassDefFoundError`：

```text
Exception in thread "main" java.lang.NoClassDefFoundError: dev/deepdive/punctuation/Punctuation
```

调用栈中还会看到：

```text
Caused by: java.lang.ClassNotFoundException: dev.deepdive.punctuation.Punctuation
```

补回 `lib002` 这个条目后，就回到第 4 步的成功命令。
