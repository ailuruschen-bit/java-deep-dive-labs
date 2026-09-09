# 一个纯净的 Java 项目如何运行起来

平时开发 Java 项目时，我们习惯了在 IDE 中点击运行，或者把编译和启动交给 Maven、Gradle。一个项目能跑起来似乎是理所当然的，但在这些工具替我们完成工作之前，Java 最基础的运行链路是什么？

这篇文章暂时放下 IDE、构建工具和框架，只使用 JDK 自带的命令，从一份源代码开始，看看它如何变成 JVM 中真正运行的程序。

## 我们使用的 Java 开发环境

开始实验前，先梳理两个经常出现的概念：JDK 和 JRE。

- **JRE（Java Runtime Environment）** 提供运行 Java 程序所需的 JVM、类库和其他组件。
- **JDK（Java Development Kit）** 在运行环境的基础上，继续提供编译、调试、分析等开发工具。

JRE 关注的是“运行”，JDK 关注的是“开发和运行”。因此，对 Java 开发者来说，日常真正需要安装和接触的通常是 JDK。

> JRE 曾经被广泛作为独立产品安装。现在是否提供独立 JRE，取决于采用的 JDK 发行版和部署方式；现代 Java 也可以为应用生成定制运行时。这个差异不影响本文的知识主线：开发者使用 JDK，而 JVM 负责执行编译后的 Java 程序。

我们熟悉的 `javac`，就是 JDK 提供的核心开发工具之一。它会读取 `.java` 源文件，将其编译成 `.class` 字节码文件。

```text
Java 源代码（.java）
        │
        │ javac
        ▼
Java 字节码（.class）
        │
        │ java
        ▼
JVM 加载并执行
```

接下来，我们从最简单的情况开始验证这条链路。

## 编译第一个 Java 文件

先创建一个没有包声明的 `Main.java`：

```java
public class Main {
    public static void main(String[] args) {
        System.out.println("Hello, Java!");
    }
}
```

当前目录只有这一个源文件：

```text
step-1/
└── Main.java
```

进入 `step-1`，执行编译：

```bash
javac Main.java
```

<!-- Media: show javac creating Main.class beside Main.java. -->

编译成功后，目录里多了一个 `Main.class`：

```text
step-1/
├── Main.class
└── Main.java
```

在没有指定输出位置时，`javac` 默认把生成的 class 文件放在对应源文件旁边。我们也可以使用 `-d` 指定统一的输出目录：

```bash
javac -d out Main.java
```

这一次，编译结果会出现在 `out/Main.class`。

### 暂时怎样理解字节码

如果没有接触过需要显式编译的语言，可以先把字节码理解为 Java 源码翻译出来的一种中间代码。

源码是为人类阅读和编写的；字节码则遵循 JVM 规定的 class 文件格式，其中保存着 JVM 能够识别的指令和数据。它仍然不是 CPU 直接执行的机器码，但已经脱离了 Java 源码的文本形式，人类直接阅读会费劲得多。

这里不需要急着研究每一条字节码指令，也不必简单地把它理解成“为了提高执行效率”。目前只需要建立一个边界：**JVM 不直接理解 Java 源码，它处理的是编译后符合 class 文件格式的数据。**

JDK 提供的 `javap` 可以帮助我们观察 class 文件。例如：

```bash
javap -c Main.class
```

输出中会出现 `getstatic`、`ldc`、`invokevirtual`、`return` 等 JVM 指令。我们暂时不展开这些指令，只用它证明 `Main.java` 已经被翻译成另一种表示形式。

> Java 也支持 `java Main.java` 这样的单文件源码启动方式。它看起来跳过了 `javac`，实际上启动器仍会先在内存中编译源码，再执行编译结果。本文先坚持显式编译，因为这样更容易看清 class 文件和后续的加载过程。

## 从当前目录启动 Main

`Main.class` 已经生成，现在让 `java` 启动它：

```bash
java Main
```

输出为：

```text
Hello, Java!
```

这里传给 `java` 的不是 `Main.class` 这个文件名，而是去掉 `.class` 后缀的类名 `Main`。

为什么 `java` 不直接接收文件路径？我们先把代码放进一个更接近真实项目的包结构，再观察一次。

## 当 class 文件进入子目录

给 `Main` 增加包声明：

```java
package dev.deepdive.app;

public class Main {
    public static void main(String[] args) {
        System.out.println("Hello, Java!");
    }
}
```

编译后，我们得到这样的目录：

```text
out/
└── dev/
    └── deepdive/
        └── app/
            └── Main.class
```

如果当前工作目录是 `out`，启动命令为：

```bash
java dev.deepdive.app.Main
```

<!-- Media: run Main from out, then show the class file tree. -->

`dev.deepdive.app.Main` 这种包含包名的完整类名，被称作类的**二进制名称**。在普通目录结构中，名称里的点会对应目录分隔，而末尾的 `Main` 对应 `Main.class`：

```text
dev.deepdive.app.Main
          │
          ▼
dev/deepdive/app/Main.class
```

观察这个转换结果，它看起来很像一个相对路径。那么，它究竟是相对哪里开始寻找的？

在回答这个问题之前，我们先看看 `java` 命令启动程序时发生了什么。

## `java`、JVM 与类加载器

`java` 命令首先启动 JVM。JVM 是 Java 运行时的核心；在编程语言的语境里，我们经常把程序执行期间所需的这套机制称为“运行时”。其他语言同样会有自己的运行时，只是具体设计不同。

而 `java` 后面的 `dev.deepdive.app.Main`，是在告诉 JVM：这一次要从哪个类开始执行。

接下来，JVM 需要根据这个名称找到对应的字节码，将字节码加载到内存，并在运行时建立出我们熟悉的 Java 类。负责完成这项工作的组件，叫作**类加载器（ClassLoader）**。

暂时不看 JDK 内部的真实代码，可以先用下面这段伪代码理解它的核心工作：

```text
relativePath = className.replace(".", "/") + ".class"

for each root in classpath:
    classFile = root + relativePath
    if classFile exists:
        bytes = read(classFile)
        return defineClass(className, bytes)

throw ClassNotFoundException
```

它先把类名转换成 class 文件的相对位置，然后从若干搜索起点中寻找这个文件。读取到字节数据后，再通过 JVM 提供的能力定义出运行时的 `Class` 对象。

这里提到的若干“搜索起点”，就是 **classpath**。

## classpath 从哪里开始找

回到刚才的命令：

```bash
cd out
java dev.deepdive.app.Main
```

在这个最简单的场景里，classpath 就是当前工作目录，也就是 `out`。类加载器从 `out` 开始，再拼接 `dev/deepdive/app/Main.class`，最终找到完整文件。

```text
classpath root                 relative class path
out/                         + dev/deepdive/app/Main.class
                              ↓
out/dev/deepdive/app/Main.class
```

这解释了为什么我们在 `out` 中可以直接启动，但切换到其他工作目录后，同样的命令可能报告找不到主类。

那我们是否可以不改变工作目录，直接告诉 JVM 应该从哪里开始搜索？可以，这就是 `-cp` 参数的作用。

```bash
java -cp out dev.deepdive.app.Main
```

`-cp` 是 `--class-path` 的简写。上面的命令把 `out` 明确设置成 classpath，因此无论当前是否位于 `out`，应用类加载器都知道应该从哪里寻找 `dev.deepdive.app.Main`。

## 为什么需要多个 classpath

现在考虑一个更接近真实项目的情况。我们希望把自己编译的代码和外部提供的代码分开管理：

```text
deployment/
├── app/
│   └── dev/deepdive/app/Main.class
└── lib/
    └── dev/deepdive/greeting/Greeting.class
```

`Main` 的类名是 `dev.deepdive.app.Main`，`Greeting` 的类名是 `dev.deepdive.greeting.Greeting`。

物理目录里的 `app` 和 `lib` 只是我们为了管理文件增加的分区，它们并不是 Java 包名的一部分。我们当然不希望因为把第三方代码放进了 `lib`，就在代码里把 `Greeting` 改成 `lib.dev.deepdive.greeting.Greeting`。事实上，即使想这样写也不应该成功，因为 class 文件内部记录的真实类名并没有 `lib` 前缀。

更自然的做法，是把 `app` 和 `lib` 都设置成搜索根：

```bash
java \
  -cp "deployment/app:deployment/lib" \
  dev.deepdive.app.Main
```

类加载器寻找 `Main` 时，从 `deployment/app` 得到：

```text
deployment/app/dev/deepdive/app/Main.class
```

寻找 `Greeting` 时，则从 `deployment/lib` 得到：

```text
deployment/lib/dev/deepdive/greeting/Greeting.class
```

这就是多个 classpath 最直观的价值：**物理文件可以分开放置，但 Java 代码中的包名和类名不需要为存储目录妥协。**

在 macOS 和 Linux 中，多个路径使用冒号 `:` 分隔；Windows 使用分号 `;`。

实验继续把依赖拆得更散：

```text
deployment/app/               Main.class
deployment/lib/greeting/      Greeting.class
deployment/lib/punctuation/   Punctuation.class
```

完整启动命令为：

```bash
java \
  -cp "deployment/app:deployment/lib/greeting:deployment/lib/punctuation" \
  dev.deepdive.app.Main
```

如果漏掉最后一个搜索根：

```bash
java \
  -cp "deployment/app:deployment/lib/greeting" \
  dev.deepdive.app.Main
```

程序能够找到并启动 `Main`，也能够找到 `Greeting`，但执行到需要 `Punctuation` 时会失败：

```text
java.lang.NoClassDefFoundError: dev/deepdive/punctuation/Punctuation
Caused by: java.lang.ClassNotFoundException: dev.deepdive.punctuation.Punctuation
```

这类错误并不一定说明 class 文件不存在。它也可能只是存在于某个目录中，却没有把那个目录加入 classpath。

<!-- Media: compare the successful and missing-classpath executions. -->

## `-cp` 之外的另一种设置方式

刚才使用 `-cp`，只为当前这一次 `java` 命令指定 classpath。除此之外，还可以设置 `CLASSPATH` 环境变量：

```bash
export CLASSPATH="deployment/app:deployment/lib/greeting:deployment/lib/punctuation"
java dev.deepdive.app.Main
```

可以把两种方式理解为：

- `-cp`：只影响当前一次命令，并且表达最明确。
- `CLASSPATH`：为当前 shell 环境中的后续 Java 命令提供默认值。

如果两者同时出现，命令中的 `-cp` 会覆盖 `CLASSPATH` 环境变量。若两者都没有设置，用户 classpath 才回到我们一开始使用的当前工作目录 `.`。

在实验和问题排查中，显式使用 `-cp` 往往更容易看出一个程序究竟依赖哪些搜索路径；全局 `CLASSPATH` 则可能让相同命令在不同人的机器上表现不一致。

## class 文件能否直接作为部署产物

从技术上说，只要服务器上有兼容的 Java 运行环境，并准备好正确的 classpath，编译后的 `.class` 文件当然可以脱离源码部署和运行。

真实项目通常不会像实验这样逐个散放 class 文件，而是把一组 class 和资源打包成 JAR，Web 应用还可能使用 WAR。它们与 VB 的 EXE 并不是同一种文件格式，但在“服务器运行的是构建产物，而开发人员维护的是源码”这一点上，面临的是相同的版本管理问题。

Java 的独立批处理也并非只存在于理论中。企业调度器通常通过脚本启动一个新的 JVM 来执行批处理；Spring Batch 官方文档就把命令行作为对接企业调度器的主要方式。日本厂商日立的 JP1 产品文档中，也提供了用于执行 Java 批处理应用的 `adshjava` 命令。因此，一个服务器上部署并调度多个独立 Java 批处理产物，是完全成立的使用方式。

当服务器上的构建产物与团队手中的源码可能不一致时，`javap` 确实比面对一个完全不透明的文件多提供了一层观察手段：

```bash
javap -p -c -l SomeJob.class
javap -sysinfo SomeJob.class
```

`-p` 可以显示所有成员，`-c` 可以反汇编方法的字节码，`-l` 可以显示行号和局部变量表，而 `-sysinfo` 还能显示文件路径、大小、时间和 SHA-256 哈希。

不过，`javap` 展示的是 class 结构和字节码，不会还原注释，也不能单独证明它由哪一次 Git 提交构建而来。处理“服务器产物是否对应手中源码”这个问题，更可靠的做法仍然是在构建和发布时记录源码提交、构建编号与产物哈希；`javap` 更适合作为缺少这些信息时的辅助调查工具。

关于 class 文件还能透露哪些信息、类加载器的真实实现以及 JAR 的加载方式，可以留到后续文章再逐步深入。本篇先建立最重要的框架：

```text
javac 负责编译
java 负责启动 JVM
类加载器根据类名和 classpath 寻找字节码
JVM 将字节码加载到运行时并执行
```

## 参考资料

- [Oracle Java SE 8 Platform Overview：JRE 与 JDK](https://docs.oracle.com/javase/8/docs/technotes/guides/)
- [Oracle JDK 21：`javac` 命令](https://docs.oracle.com/en/java/javase/21/docs/specs/man/javac.html)
- [Oracle JDK 21：`java` 命令与 classpath](https://docs.oracle.com/en/java/javase/21/docs/specs/man/java.html)
- [Oracle Java SE 21：`ClassLoader` API](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/ClassLoader.html)
- [Java 虚拟机规范 21：class 文件格式](https://docs.oracle.com/javase/specs/jvms/se21/html/)
- [Oracle JDK 21：`javap` 命令](https://docs.oracle.com/en/java/javase/21/docs/specs/man/javap.html)
- [Oracle JDK 21：创建定制 Java 运行时](https://docs.oracle.com/en/java/javase/21/jpackage/image-and-runtime-modifications.html)
- [Spring Batch：从命令行运行批处理](https://docs.spring.io/spring-batch/reference/job/running.html)
- [Hitachi JP1：Java 批处理应用执行环境](https://itpfdoc.hitachi.co.jp/manuals/3021/3021313340/H0313340.PDF)
