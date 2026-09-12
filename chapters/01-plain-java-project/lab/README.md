# 纯 Java 运行实验

本实验使用 JDK 21，不依赖 IDE、Maven 或 Gradle。在本目录执行：

```bash
./run-experiments.sh
```

脚本会检查 `java` 和 `javac` 都是 21，并在子 shell 中清除继承的 `CLASSPATH` 和 Java 启动选项，以保证演示结果一致。它不会修改终端原有的环境配置。默认执行会重新编译本轮用到的 class 文件，并验证缺少编译依赖、加载失败等预期错误。脚本还会清除应用 class 后反转两份源码的排列顺序，确认同一次编译无需按依赖顺序列出源码。

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

## 4. 准备两份源码和两个外部依赖

这次我们有两个自己的类：入口类 `Main` 调用同包下的 `MessageService`，后者直接使用 `Greeting` 和 `Punctuation` 两个外部类：

```text
Main
└── MessageService
    ├── Greeting
    └── Punctuation
```

`MessageService` 是一个独立的顶层类，具有包访问权限，不是嵌套在 `Main` 内部的类。它直接调用两个外部类，因此编译它和运行它时都需要这两个依赖。

在这个模拟场景里，`Greeting` 和 `Punctuation` 已由提供方定义，包名分别为 `dev.deepdive.greeting` 和 `dev.deepdive.punctuation`。我们使用提供方交付的 class 文件，并保留其包名；`lib001`、`lib002` 只是我们管理文件的目录。

为方便复现，仓库在 `multiple-classpath/src/greeting/` 和 `multiple-classpath/src/punctuation/` 下保留提供方源码。准备步骤编译它们，是在模拟提供方构建交付产物；自己的两份源码则直接保存在 `deployment/dev/deepdive/app/`，编译和运行时都使用已经准备好的外部 class。

在 `lab/` 中执行下面的命令，即可重建两份外部 class，并清除这次应用编译生成的 `Main.class` 和 `MessageService.class`：

```bash
./run-experiments.sh --prepare
```

此模式不会运行完整实验，也不会删除源码或清空目录。准备好的目录如下：

```text
deployment/
├── dev/
│   └── deepdive/
│       └── app/
│           ├── Main.java
│           └── MessageService.java
├── lib001/
│   └── dev/
│       └── deepdive/
│           └── greeting/
│               └── Greeting.class
└── lib002/
    └── dev/
        └── deepdive/
            └── punctuation/
                └── Punctuation.class
```

下面四张截图均在 `deployment/` 中按顺序录制。手工命令需要使用 JDK 21，并避免继承其他实验的 classpath 或 Java 选项。在 macOS 的 `lab/` 目录中，先进入临时子 shell 并选择已安装的 JDK 21，再准备产物并进入工作目录；即使原终端默认使用 JDK 8，也可以按此步骤执行：

```bash
bash --noprofile --norc
export JAVA_HOME="$(/usr/libexec/java_home -v 21)"
export PATH="$JAVA_HOME/bin:$PATH"
unset CLASSPATH JAVA_TOOL_OPTIONS JDK_JAVA_OPTIONS JDK_JAVAC_OPTIONS _JAVA_OPTIONS
./run-experiments.sh --prepare
cd deployment
```

这里的 JDK 选择和环境清理只作用于临时子 shell，录制完后执行 `exit` 即可回到原终端环境。其他系统将 `JAVA_HOME` 设置为本机 JDK 21 的实际安装目录即可。

## 5. 截图一：没有配置编译 classpath

把自己的两份源码一起交给 `javac`，暂时不指定编译依赖的位置：

```bash
javac \
  dev/deepdive/app/Main.java \
  dev/deepdive/app/MessageService.java
```

编译失败，输出中会出现：

```text
package dev.deepdive.greeting does not exist
package dev.deepdive.punctuation does not exist
```

`Greeting.class` 和 `Punctuation.class` 已经在磁盘上，但当前的默认搜索起点 `.` 无法对应到它们的存放位置。编译器需要从 `lib001` 和 `lib002` 开始，沿包名对应的目录结构查找这两个类型。

## 6. 截图二：补上编译 classpath

仍在 `deployment/`，为编译器指定依赖条目：

```bash
javac -cp "lib001:lib002" \
  dev/deepdive/app/Main.java \
  dev/deepdive/app/MessageService.java

ls dev/deepdive/app
```

`javac` 成功时不输出消息。`ls` 可以确认生成了 `Main.class` 和 `MessageService.class`；原有的两个 java 文件仍保留在同一目录：

```text
deployment/
├── dev/
│   └── deepdive/
│       └── app/
│           ├── Main.java
│           ├── Main.class
│           ├── MessageService.java
│           └── MessageService.class
├── lib001/...
└── lib002/...
```

这里配置的是一个 classpath，其中包含 `lib001` 和 `lib002` 两个目录条目；每个目录条目都是查找 class 文件的搜索起点。没有指定输出目录时，生成的 class 文件默认保存在对应的源码旁边。

这两个源码文件参与同一次编译，会作为一个整体进行分析，无需提前单独编译 `MessageService.java`。文件在命令中的排列顺序也不影响本例的编译结果；完整验证脚本会清除应用 class，再把两份源码反过来排列并重新编译，以确认这一点。

在这里，`javac -cp` 帮助编译器查找外部类的声明、方法签名和访问权限，以检查源码中的引用并生成字节码；它没有执行这些外部类。

## 7. 截图三：为运行配置完整 classpath

仍在 `deployment/`，启动刚刚编译的程序：

```bash
java -cp ".:lib001:lib002" dev.deepdive.app.Main
```

输出：

```text
Hello, classpath!
```

这次运行的 classpath 包含三个目录条目：

- `.`：查找 `Main.class` 和 `MessageService.class`。
- `lib001`：查找 `Greeting.class`。
- `lib002`：查找 `Punctuation.class`。

编译 classpath 与运行 classpath 需要分别配置。`java` 不会自动继承之前 `javac -cp` 的设置；此时由类加载器根据运行 classpath 查找字节码，并交给 JVM 定义和执行类。

## 8. 截图四：遗漏运行依赖条目

仍在 `deployment/`，这次只保留 `.` 和 `lib001`：

```bash
java -cp ".:lib001" dev.deepdive.app.Main
```

输出中会出现：

```text
Exception in thread "main" java.lang.NoClassDefFoundError: dev/deepdive/punctuation/Punctuation
```

调用栈中还会看到：

```text
Caused by: java.lang.ClassNotFoundException: dev.deepdive.punctuation.Punctuation
```

本次程序已经进入 `Main.main`，并成功使用 `MessageService` 和 `Greeting`。执行到 `Punctuation.mark()` 时，类加载器无法从当前 classpath 中找到 `Punctuation`。底层查找产生 `ClassNotFoundException`，JVM 执行到需要这个类的代码时未能完成加载，最终向程序报告 `NoClassDefFoundError`。

补回 `lib002` 条目，就回到截图三的成功命令。重新录制时，先回到 `lab/` 再执行 `./run-experiments.sh --prepare`，可以恢复到只有两份应用源码和两份外部 class 的准备状态。

## 9. 补充验证：把存放目录误写进类名

提供方编写 `Greeting.java` 时，包声明是 `package dev.deepdive.greeting;`，没有 `lib001`。`Greeting.class` 内部记录的完整类名也不包含 `lib001`。在 `deployment/` 中观察下面的错误命令：

```bash
java -cp . lib001.dev.deepdive.greeting.Greeting
```

虽然能按照这个名字找到 `lib001/dev/deepdive/greeting/Greeting.class`，请求的名称与文件内部记录的名称却不一致，因此在加载阶段出现 `NoClassDefFoundError`，并提示 `wrong name: dev/deepdive/greeting/Greeting`。

这一步专门观察名称不一致导致的错误；`Greeting` 本身是依赖类，没有 `main` 方法。它由我们的应用使用，搜索起点应当通过 classpath 条目指定，无需改变依赖的包名。
