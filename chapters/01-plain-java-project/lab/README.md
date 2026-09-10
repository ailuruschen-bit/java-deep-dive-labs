# 纯 Java 运行实验

本实验使用 JDK 21，不依赖 IDE、Maven 或 Gradle。在本目录执行：

```bash
./run-experiments.sh
```

脚本会检查 `java` 和 `javac` 都是 21，并在子 shell 中清除继承的 `CLASSPATH` 和 Java 启动选项，以保证演示结果一致。它不会修改终端原有的环境配置。每次执行都会重新编译本轮用到的 class 文件；下面出现的三个加载失败也是验证内容，脚本会检查对应错误。

命令使用 macOS/Linux 的 classpath 分隔符 `:`；Windows 手工执行时使用 `;`。代码注释统一使用英文。

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

继续留在 `step-2/`，通过 `-cp out` 将搜索起点设为 `step-2/out/`：

```bash
java -cp out dev.deepdive.app.Main
```

这次输出 `Hello, Java!`。这里的 `out` 是相对于当前工作目录的路径。

## 4. 用多个 classpath 分开存放自己的类和依赖

三个源文件保存在 `multiple-classpath/src/` 下。`Main` 调用 `Greeting`，`Greeting` 再调用 `Punctuation`；它们的包名分别为 `dev.deepdive.app`、`dev.deepdive.greeting`、`dev.deepdive.punctuation`。

脚本会创建 `deployment/`。以下命令均以它作为工作目录：

```bash
javac -d lib002 \
  ../multiple-classpath/src/punctuation/dev/deepdive/punctuation/Punctuation.java

javac -cp lib002 -d lib001 \
  ../multiple-classpath/src/greeting/dev/deepdive/greeting/Greeting.java

javac -cp 'lib001:lib002' -d . \
  ../multiple-classpath/src/app/dev/deepdive/app/Main.java
```

编译时的 `javac -cp` 指明依赖所在的搜索起点，`-d` 指明这次编译结果的输出起点。生成的目录是：

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

输出为 `Hello, classpath!`。`.`、`lib001`、`lib002` 分别是三个搜索起点；进入每个起点后，都按照类名对应的包结构继续寻找。

## 5. 把存放目录误写进类名

`Greeting.java` 中写的是 `package dev.deepdive.greeting;`，没有 `lib001`。`lib001` 是我们保存依赖的目录，不能因此给类名增加一个 `lib001.` 前缀。

仍在 `deployment/`，观察下面的错误命令：

```bash
java -cp . lib001.dev.deepdive.greeting.Greeting
```

虽然能按照这个名字找到 `lib001/dev/deepdive/greeting/Greeting.class`，文件内记录的名称却是 `dev.deepdive.greeting.Greeting`，因此在加载阶段出现 `NoClassDefFoundError`，并提示 `wrong name: dev/deepdive/greeting/Greeting`。

这一步专门观察名称不一致导致的错误；`Greeting` 本身只是依赖类，没有 `main` 方法。

## 6. 漏掉一个依赖目录

仍在 `deployment/`，只配置 `.` 和 `lib001`：

```bash
java -cp '.:lib001' dev.deepdive.app.Main
```

`Main` 和 `Greeting` 能被找到，但执行到 `Greeting` 对 `Punctuation` 的调用时，缺少 `lib002`，因此报告：

```text
Exception in thread "main" java.lang.NoClassDefFoundError: dev/deepdive/punctuation/Punctuation
```

调用栈中还会看到：

```text
Caused by: java.lang.ClassNotFoundException: dev.deepdive.punctuation.Punctuation
```

补回 `lib002` 后，就回到第 4 步的成功命令。
