# 一个纯净的 Java 项目是如何跑起来的？

> 本文仍在撰写中。本轮先从本机安装的 Java 环境开始。

## 先弄清楚：我们安装的 Java 到底是什么

在写第一行代码之前，我想先回答一个看似简单的问题：电脑里安装的“Java”到底是什么？

我们经常会看到两个名字：JDK 和 JRE。

- **JDK** 的全称是 **Java Development Kit**，可以理解为 Java 开发工具包。
- **JRE** 的全称是 **Java Runtime Environment**，可以理解为 Java 运行时环境。

这里需要先修正两个容易记错的地方：JDK 不是 *Develop Kit*，JRE 也不是 *Running Environment*。`Development` 强调它是一套用于开发的工具，`Runtime` 指程序运行期间所需要的环境。

### 用 Java 8 的结构理解 JDK 和 JRE

Oracle 的 Java SE 8 文档给出了一个很直观的关系：JRE 提供运行 Java 程序所需的类库、Java 虚拟机以及其他组件；JDK 则包含 JRE，并在它的基础上提供编译器、调试器等命令行开发工具。

可以暂时把它理解成：

```text
JDK
├── 用于运行 Java 程序的环境（JRE）
└── 用于开发 Java 程序的工具
```

这个模型很适合入门，因为它解释了为什么安装 JDK 后既能编译程序，也能运行程序；而传统的独立 JRE 主要面向只需要运行 Java 程序的机器。

但这不是所有 Java 版本都可以原样套用的目录结构。Java 8 的 JDK 目录中确实包含一个 `jre/` 子目录；到了模块化之后的现代 JDK，安装目录已经不再沿用这套布局。以 Oracle JDK 21 为例，官方安装指南直接建议：无论开发还是运行 Java 应用，都安装 JDK。现代 Java 还可以通过 `jlink` 为具体应用生成裁剪后的运行时镜像。

因此，文章后面可以继续使用“JDK 提供开发能力和运行能力”这个概念，但不应该让读者误以为现代 Java 必然存在一个可以单独找到的 `jre/` 目录，或者任何版本都应当分别选择 JDK 与 JRE 安装包。

### `javac` 是 JDK 单独提供的吗？

是的，`javac` 是 JDK 提供的核心开发工具之一，它的职责是读取 `.java` 源文件，并把它们编译为可以在 Java 虚拟机上运行的 `.class` 文件。

与它相对，`java` 命令是 Java 应用启动器。先不考虑 JAR、模块和构建工具，一个 Java 程序最基础的路径可以写成：

```text
源代码（.java）
    │
    │ javac 编译
    ▼
字节码（.class）
    │
    │ java 启动
    ▼
Java 虚拟机执行程序
```

这也给出了本文后续实验的起点：暂时不使用 Maven、Gradle 或 IDE，只使用 JDK 自带的 `javac` 和 `java`，观察一个最小 Java 项目究竟如何从源文件变成正在运行的程序。

## 先检查当前机器实际使用的环境

在终端中运行：

```bash
command -v java
command -v javac
java -version
javac -version
```

将主环境切换到 Java 21 后，这台实验机器得到的关键信息是：

```text
JAVA_HOME=/Users/apple/Library/Java/JavaVirtualMachines/jbr-21.0.11/Contents/Home
java:  $JAVA_HOME/bin/java
javac: $JAVA_HOME/bin/javac
openjdk version "21.0.11"
javac 21.0.11
java.home=$JAVA_HOME
```

`java` 和 `javac` 都存在，并且版本一致，只能初步说明当前命令行能够同时运行和编译 Java 程序。这里使用的是 JetBrains 提供的 OpenJDK 21 构建，它包含本文目前需要的完整编译与运行工具。`java.home` 不再指向 JDK 内部的 `jre/` 子目录，也正好印证了现代 JDK 已经不再沿用 Java 8 的目录布局。

这些结果仍然不能证明机器上只安装了一个 JDK。`PATH`、`JAVA_HOME`、操作系统的命令转发机制，以及多个并存的 JDK 都可能影响最终执行的是哪一个程序。

下一步需要继续追踪命令解析过程，并弄清楚 `JAVA_HOME` 在其中扮演的角色。

## 本轮资料来源

- [Oracle Java SE 8 Platform Overview：JRE 与 JDK](https://docs.oracle.com/javase/8/docs/technotes/guides/)
- [Oracle Java SE 8：JDK 与 JRE 的文件结构](https://docs.oracle.com/javase/8/docs/technotes/tools/windows/jdkfiles.html)
- [Oracle JDK 21：JDK 安装概览](https://docs.oracle.com/en/java/javase/21/install/overview-jdk-installation.html)
- [Oracle JDK 21：JDK 安装目录结构](https://docs.oracle.com/en/java/javase/21/install/installed-directory-structure-jdk.html)
- [Oracle JDK 21：`javac` 命令](https://docs.oracle.com/en/java/javase/21/docs/specs/man/javac.html)
- [Oracle JDK 21：创建自定义运行时镜像](https://docs.oracle.com/en/java/javase/21/jpackage/image-and-runtime-modifications.html)
