# 一个纯净的 Java 项目是如何跑起来的？

> 本文仍在撰写中。

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

## 从源码到字节码

先写一个最小的 Java 类：

```java
package dev.deepdive.basic;

public final class Hello {
    private Hello() {
    }

    public static void main(String[] args) {
        System.out.println("Hello from a plain Java project.");
    }
}
```

按照 Java 最经典的工作方式，运行程序需要两步：先用 `javac` 编译，再用 `java` 启动。

```bash
javac -d build/basic src/basic/dev/deepdive/basic/Hello.java
cd build/basic
java dev.deepdive.basic.Hello
```

第一条命令会生成：

```text
build/basic/dev/deepdive/basic/Hello.class
```

`.java` 文件保存的是人类编写的 Java 源码，`.class` 文件保存的则是 JVM 规定的 class 文件格式，其中包含 JVM 指令，也就是我们常说的 Java 字节码。

如果没有接触过 C 等需要显式编译的语言，可以先把字节码理解成 Java 源码翻译出来的一种中间形式：它不是写给人直接阅读的，却有明确、紧凑且与具体操作系统和 CPU 无关的二进制结构，可以交给 JVM 处理。

这里不把它简单描述成“执行效率更高的代码”。程序最终如何执行、是否解释运行、何时被即时编译为机器码，是 JVM 后续阶段的工作。对这一章来说，只要先记住下面这条边界：JVM 的输入是符合规范的 class 数据，而不是我们看到的 Java 语法。

JDK 还提供了 `javap`，可以反汇编 class 文件。运行：

```bash
javap -cp build/basic -c dev.deepdive.basic.Hello
```

会看到类似 `getstatic`、`ldc`、`invokevirtual`、`return` 这样的 JVM 指令。我们暂时不解释每一条指令，只用它确认源代码已经被翻译成另一套表示形式。

### Java 21 真的不能直接运行源码吗？

如果我们使用 Java 21，下面这条命令其实也能成功：

```bash
java src/basic/dev/deepdive/basic/Hello.java
```

这是 Java 11 引入的单文件源码启动模式。`java` 启动器识别到参数是一个现存的 `.java` 文件后，会先在内存中编译源码，再加载编译结果并执行；它不会在源码目录旁留下普通的 `.class` 文件。

所以“JRE 不能运行 Java 源码，必须手动调用 `javac`”对于 Java 21 并不严谨。更准确的说法是：**JVM 不直接执行 Java 源码；即使使用 `java Hello.java`，中间仍然发生了编译。**

本文仍然先使用显式的 `javac` → `java` 两步流程，因为它能让编译产物、类名和 classpath 的作用都暴露出来。

## `java` 后面为什么不是 class 文件名

在 class 模式下，`java` 命令的参数不是文件路径：

```bash
# Incorrect
java dev/deepdive/basic/Hello.class

# Correct
java dev.deepdive.basic.Hello
```

`dev.deepdive.basic.Hello` 是这个类的二进制名称。名字里的点也不是通用的“向下进入一层目录”语法，而是在分隔包名与类名。对于存放在普通目录里的 class 文件，包结构通常映射成目录结构，因此这个名称对应的相对文件位置是：

```text
dev.deepdive.basic.Hello
            ↓
dev/deepdive/basic/Hello.class
```

还缺少一个关键问题：这条相对路径应当从哪里开始找？答案就是 classpath。

## classpath：寻找用户类的起点

classpath 是一组搜索根。每一项可以是目录、JAR 文件或 ZIP 文件。应用类加载器需要查找用户类时，会在这些根中搜索相应的 class 数据。

当我们既没有传入 `-cp`，也没有设置 `CLASSPATH` 环境变量时，默认的用户 classpath 是当前工作目录 `.`。因此下面的命令能够成功：

```bash
cd build/basic
java dev.deepdive.basic.Hello
```

此时当前目录是 `build/basic`。类加载器以它作为搜索根，再根据类名找到 `dev/deepdive/basic/Hello.class`。

我们也可以用 `-cp`（`--class-path` 和 `-classpath` 的缩写）明确指定搜索根：

```bash
java -cp build/basic dev.deepdive.basic.Hello
```

classpath 可以包含多项。在 macOS 和 Linux 上使用冒号 `:` 分隔，在 Windows 上使用分号 `;` 分隔。通常应该把整个 classpath 参数放在引号中，避免空格或 shell 展开造成干扰。

## class 文件可以分散在不同位置吗？

实验里还有三个类：

```text
Main.class             位于 build/app
Greeting.class         位于 build/greeting
Punctuation.class      位于 build/punctuation
```

它们形成 `Main → Greeting → Punctuation` 的依赖关系。只要把三个搜索根都交给 `java`，这些 class 文件并不需要集中在同一个目录：

```bash
java \
  -cp "build/app:build/greeting:build/punctuation" \
  dev.deepdive.app.Main
```

输出为：

```text
Hello, classpath!
```

如果漏掉保存主类的 `build/app`：

```bash
java \
  -cp "build/greeting:build/punctuation" \
  dev.deepdive.app.Main
```

启动器连入口类都找不到，因此会报告：

```text
Error: Could not find or load main class dev.deepdive.app.Main
Caused by: java.lang.ClassNotFoundException: dev.deepdive.app.Main
```

如果保留主类和 `Greeting`，却漏掉运行时需要的 `Punctuation`：

```bash
java \
  -cp "build/app:build/greeting" \
  dev.deepdive.app.Main
```

这一次 JVM 能启动 `Main`，但程序执行到相关依赖时会失败：

```text
java.lang.NoClassDefFoundError: dev/deepdive/punctuation/Punctuation
Caused by: java.lang.ClassNotFoundException: dev.deepdive.punctuation.Punctuation
```

这两个错误的出现阶段不同，但都能说明一件事：字节码确实存在于磁盘上还不够，它所在的位置必须能被负责加载它的类加载器发现。

## 从类名到内存中的类

Oracle 对 `java` 命令的描述很直接：它会启动 JVM、加载指定的类，然后调用这个类的 `main` 方法。

“加载指定的类”并不是一句无法继续拆解的魔法。Java 中的 `ClassLoader` 就是负责类加载的对象。官方 API 对它的定义是：给定一个类的二进制名称，类加载器应当尝试定位或生成构成该类定义的数据。一种典型策略是把类名转换成文件名，读取对应 class 文件，再通过 `defineClass` 把字节转换为 JVM 中的 `Class` 对象。

实验里实现了一个刻意简化的 `DirectoryClassLoader`，其中最关键的逻辑是：

```java
String relativePath = binaryName.replace('.', '/') + ".class";

for (Path root : classPathRoots) {
    Path classFile = root.resolve(relativePath);
    if (Files.isRegularFile(classFile)) {
        byte[] classBytes = Files.readAllBytes(classFile);
        return defineClass(binaryName, classBytes, 0, classBytes.length);
    }
}
```

这段代码不是 JVM 内置类加载器的完整实现，它只是把核心关系展示出来：

```text
二进制类名
    + classpath 搜索根
    ↓
找到或生成 class 数据
    ↓
defineClass
    ↓
JVM 中的 Class 对象
```

真实实现还要处理父加载器委派、模块、JAR、权限、并发加载、链接等问题。类也不一定来自一个物理 `.class` 文件，它还可以来自 JAR、网络或运行时生成的数据。因此，“JVM 根据类名直接读取某个磁盘文件”可以作为第一层直觉，但更准确的主语应该是类加载器。

OpenJDK 21 的内置类加载器源码中可以看到对 classpath 的搜索过程；而 Java 21 的 `ClassLoader` API 则给出了稳定、公开的加载与定义模型。本文先用自己的小实现理解机制，不依赖 JDK 内部类的具体细节。

## 资料来源

- [Oracle Java SE 8 Platform Overview：JRE 与 JDK](https://docs.oracle.com/javase/8/docs/technotes/guides/)
- [Oracle Java SE 8：JDK 与 JRE 的文件结构](https://docs.oracle.com/javase/8/docs/technotes/tools/windows/jdkfiles.html)
- [Oracle JDK 21：JDK 安装概览](https://docs.oracle.com/en/java/javase/21/install/overview-jdk-installation.html)
- [Oracle JDK 21：JDK 安装目录结构](https://docs.oracle.com/en/java/javase/21/install/installed-directory-structure-jdk.html)
- [Oracle JDK 21：`javac` 命令](https://docs.oracle.com/en/java/javase/21/docs/specs/man/javac.html)
- [Oracle JDK 21：`java` 命令、单文件源码模式与 classpath](https://docs.oracle.com/en/java/javase/21/docs/specs/man/java.html)
- [Oracle Java SE 21：`ClassLoader` API](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/ClassLoader.html)
- [Java 虚拟机规范 21：class 文件、加载、链接与初始化](https://docs.oracle.com/javase/specs/jvms/se21/html/)
- [OpenJDK：`BuiltinClassLoader` 源码](https://github.com/openjdk/jdk/blob/jdk-21%2B35/src/java.base/share/classes/jdk/internal/loader/BuiltinClassLoader.java)
- [Oracle JDK 21：创建自定义运行时镜像](https://docs.oracle.com/en/java/javase/21/jpackage/image-and-runtime-modifications.html)
