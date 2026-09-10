# 拆解 Java 启动：编译、类加载与 classpath

我们先把 Java 项目缩到最小：一个 `Main.java`，一套 JDK。不用 Eclipse 或 IntelliJ IDEA，不用 Maven，也不引入 Spring，编译和启动直接使用 `javac` 与 `java`。

沿着这条最短路径，我们逐步拆开程序的运行过程：写下的源码怎样变成 class 文件，传入的类名怎样对应到磁盘上的文件，以及 classpath 怎样决定这些文件能否被找到。

## 从 JDK 提供的工具开始

开发 Java 时，我们接触到的 JDK 和 JRE，区别就在于它们提供的能力：

- **JRE（Java Runtime Environment）** 提供运行 Java 程序所需的 JVM、类库和其他组件。
- **JDK（Java Development Kit）** 在运行环境的基础上，继续提供编译、调试、分析等开发工具。

作为开发者，我们既要运行程序，也要编译源码，因此日常使用的通常是 JDK。

> JRE 可以作为独立运行环境分发，是否提供独立安装包取决于发行版。本文使用 JDK 提供的工具完成编译和启动。

我们熟悉的 `javac`，就是 JDK 提供的开发工具之一。它读取 `.java` 源文件，编译生成 `.class` 字节码文件。随后，我们用 `java` 命令启动 JVM，加载并执行编译结果：

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

## 用 javac 生成 class 文件

先写一个没有包声明的 `Main.java`，只保留我们熟悉的 `main` 方法和一行输出：

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

编译成功后，目录里多了一个 `Main.class`：

```text
step-1/
├── Main.class
└── Main.java
```

`javac` 默认把生成的 class 文件放在对应源文件旁边。如果我们想把编译结果单独放进一个目录，可以用 `-d` 指定输出位置。仍然留在 `step-1`，执行：

```bash
javac -d out Main.java
```

这条命令生成的是 `out/Main.class`，不影响刚才留在源文件旁的 `Main.class`。

```text
step-1/
├── Main.class
├── Main.java
└── out/
    └── Main.class
```

### 字节码：面向 JVM 的中间代码

`Main.class` 不是换了后缀的源码。编译器把 Java 源码转换成了面向 JVM 的中间代码，也就是字节码。

我们写源码时，用的是便于人阅读的 Java 语法；编译后，class 文件保存的则是 JVM 能够识别的指令和数据。它已经不是适合直接阅读的文本，但也不是 CPU 直接执行的机器码。

编译在这里划出了一条明确的边界：**JVM 不直接理解 Java 源码，它处理的是编译后符合 class 文件格式的数据。**

> Java 也支持 `java Main.java` 这样的单文件源码启动方式：启动器先在内存中编译源码，再执行编译结果。省略的是手动调用 `javac`，不是编译本身。本文把编译和启动分开，便于观察生成的文件。

下面是这轮编译实验的完整操作。我们用 `tree --noreport` 查看每次编译前后的目录变化：

![编译实验完整演示：javac Main.java 在源码旁生成字节码，javac -d out Main.java 将编译结果输出到 out](assets/experiment-01-compilation.png)

## 从当前目录启动 Main

编译结果已经有了。我们留在 `step-1`，启动刚才编译的程序：

```bash
java Main
```

输出为：

```text
Hello, Java!
```

这里有个值得留意的细节：我们明明生成了 `Main.class`，启动时传入的却是类名 `Main`，不是文件名 `Main.class`。

为什么用类名，不用文件路径？先记下这个差别。给 `Main` 加上包声明后，它会更明显。

## 加上包名，再运行一次

我们另开一个 `step-2` 目录，像平时组织项目代码一样，把 `Main.java` 放进与包名对应的子目录。代码只增加一行包声明：

```java
package dev.deepdive.app;

public class Main {
    public static void main(String[] args) {
        System.out.println("Hello, Java!");
    }
}
```

源码放在最内层的 `app` 目录中：

```text
step-2/
└── out/
    └── dev/
        └── deepdive/
            └── app/
                └── Main.java
```

进入 `step-2/out`，在这个工作目录下编译：

```bash
javac dev/deepdive/app/Main.java
```

这次没有使用 `-d`，因此 `Main.class` 仍然生成在源文件旁边：

```text
out/  ← 当前工作目录
└── dev/
    └── deepdive/
        └── app/
            ├── Main.java
            └── Main.class
```

保持工作目录为 `out`，启动命令为：

```bash
java dev.deepdive.app.Main
```

输出仍然是 `Hello, Java!`。把刚才的两条命令放在一起看，我们传给 `javac` 的是源文件路径 `dev/deepdive/app/Main.java`，传给 `java` 的则是完整类名 `dev.deepdive.app.Main`。

对于这里的普通顶层类，`dev.deepdive.app.Main` 这种包含包名的完整类名，被称作类的**二进制名称**。在普通目录结构中，名称里的点会对应目录分隔，而末尾的 `Main` 对应 `Main.class`：

```text
dev.deepdive.app.Main
          │
          ▼
dev/deepdive/app/Main.class
```

从 `step-1` 中执行 `java Main`，到进入 `step-2/out` 编译并启动带包名的 `Main`，完整操作如下：

![启动实验完整演示：先执行 java Main，再进入 step-2/out，编译带包名的源码并执行 java dev.deepdive.app.Main](assets/experiment-02-class-name.png)

回到类名转换后的 `dev/deepdive/app/Main.class`，它看起来就是一个相对路径。但相对路径还缺一个信息：从哪个目录开始找？

要找到这个搜索起点，我们需要沿着刚才的启动命令再往下走一步。

## `java`、JVM 与类加载器

`java` 命令首先启动 JVM。程序执行所依赖的这套支撑机制，通常称为“运行时”；JVM 是 Java 运行时的核心。其他语言也有各自的运行时，实现方式各不相同。

我们在命令后面写下的 `dev.deepdive.app.Main`，则是在指定入口类：这次运行从它开始。

执行入口方法之前，需要先根据类名找到字节码，将其加载到内存，在 JVM 中建立对应的类。负责这项工作的组件，叫作**类加载器（ClassLoader）**。

本文中的应用类都以 class 文件的形式放在普通目录中。要根据类名找到它们，需要先确定从哪些目录开始查找。这组查找位置由 **classpath** 指定：**一个 classpath 可以包含多个条目；在本文中，每个条目都是一个目录，也就是类文件的搜索起点。**

针对这个场景，我们可以用下面这段伪代码描述查找和加载过程：

```text
relativePath = className.replace(".", "/") + ".class"

for each entry in classpath:  // Why multiple entries? We'll come back to this.
    classFile = joinPath(entry, relativePath)
    if classFile exists:
        bytes = read(classFile)
        return defineClass(className, bytes)

throw ClassNotFoundException
```

类名先被转换成相对路径，再与 classpath 中的各个目录条目拼接。找到文件后读取字节数据，`defineClass` 会检查请求的类名是否与文件内部记录的类名一致，并通过 JVM 提供的能力定义出运行时的 `Class` 对象。完成启动所需的准备后，运行环境调用 `Main.main`，进入我们写下的代码。

这样，我们就能把前面的启动参数理解清楚：`java` 接收的是要启动的类名，classpath 提供查找位置，类加载器负责将两者对应到实际文件。类名确定我们要用哪个类，查找位置则由 classpath 配置。

## classpath：给类名一个搜索起点

回到刚才的实验，我们一直留在 `step-2/out`，执行的是：

```bash
java dev.deepdive.app.Main
```

这个实验没有额外配置 classpath，默认只有一个条目 `.`，表示当前工作目录。因此搜索从 `out` 这一层开始，沿着类名对应的目录找到 `Main.class`：

```text
step-2/
└── out/                  ← 搜索起点：当前工作目录
    └── dev/
        └── deepdive/
            └── app/
                ├── Main.java
                └── Main.class  ← 找到目标
```

现在我们保持类名和文件不动，只把工作目录切换到 `out` 的父目录 `step-2`，执行相同的启动命令：

```bash
cd ..
java dev.deepdive.app.Main
```

我们没有改代码，甚至连启动命令都没改，但默认搜索起点已经变了。把它与类名对应的 `dev/deepdive/app/Main.class` 拼起来，问题就落在了具体的路径上：

| 当前工作目录 | 默认会查找的文件位置 | 结果 |
| --- | --- | --- |
| `step-2/out` | `step-2/out/dev/deepdive/app/Main.class` | 文件存在 |
| `step-2` | `step-2/dev/deepdive/app/Main.class` | 文件不存在，路径中少了 `out` |

这些路径都以 `step-2` 的父目录为参照。实际文件一直在第一行的位置，所以第二次启动会报告：

```text
Error: Could not find or load main class dev.deepdive.app.Main
Caused by: java.lang.ClassNotFoundException: dev.deepdive.app.Main
```

我们不必为此切回 `out`。留在 `step-2`，用 `-cp` 明确告诉启动器从 `out` 开始查找：

```bash
java -cp out dev.deepdive.app.Main
```

程序恢复正常。`-cp out` 将这次启动的 classpath 设置为只有 `out` 这一个条目。这里的 `out` 相对工作目录 `step-2` 解析，搜索起点回到 `step-2/out`。

**工作目录决定相对路径如何解析，classpath 的目录条目决定查找类时从哪里开始。** 条目可以使用相对路径，也可以使用绝对路径。

下面是这次切换工作目录后的完整操作：同一条启动命令先报告找不到主类，补上 `-cp out` 后恢复正常。

![切换到 step-2 后找不到主类，使用 java -cp out dev.deepdive.app.Main 后成功输出 Hello, Java!](assets/experiment-03-classpath-root.png)

## 一个 classpath 可以包含多个条目

现在回到前面伪代码里留下的那条注释：为什么这里用了 `for` 循环？刚才的 classpath 只有一个 `out` 条目，但 `-cp` 可以一次配置多个条目，查找时依次尝试它们。

当我们想把自己写的代码和外部依赖分开管理时，多个条目就派上用场了。这轮实验模拟使用外部依赖的场景：`Greeting.class` 和 `Punctuation.class` 已经由依赖提供方编译完成，我们站在使用方，只拿到并使用这些编译产物，不能为了适应自己的存放目录而修改它们的包名。

我们写的 `Main` 调用 `Greeting`，`Greeting` 再调用 `Punctuation`。自己的类放在项目的包目录下，两个依赖分别放进 `lib001`、`lib002`，目录结构如下：

```text
deployment/  ← 当前工作目录
├── dev/
│   └── deepdive/
│       └── app/
│           └── Main.class
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

`lib001`、`lib002` 只是我们管理依赖文件的目录，不是依赖作者声明的 package。例如，提供方编写 `Greeting.java` 时，包声明是：

```java
package dev.deepdive.greeting;
```

编译完成后，`Greeting.class` 内部已经记录了完整类名 `dev.deepdive.greeting.Greeting`。我们在 `Main` 中按照这个名字导入并使用它，和日常开发时一样：

```java
package dev.deepdive.app;

import dev.deepdive.greeting.Greeting;

public class Main {
    public static void main(String[] args) {
        System.out.println(Greeting.forName("classpath"));
    }
}
```

如果只从 `deployment` 开始找，`dev.deepdive.greeting.Greeting` 对应的路径是 `deployment/dev/deepdive/greeting/Greeting.class`。实际文件在 `deployment/lib001/dev/deepdive/greeting/Greeting.class`，多了一层 `lib001`，两者对不上。

看到中间多出的这一层，我们可能会想到让类加载器按 `lib001.dev.deepdive.greeting.Greeting` 这个名字查找。这样虽然能让查找路径指向文件，但文件内部记录的仍然是 `dev.deepdive.greeting.Greeting`。请求名称与文件内部的名称不一致，无法按这个名字定义类，加载时会报告 `wrong name`。

正确做法不是修改类名，而是把 `lib001` 配置为 classpath 的一个目录条目，让它成为搜索起点：

```text
搜索起点：lib001
类名对应路径：dev/deepdive/greeting/Greeting.class
最终位置：lib001/dev/deepdive/greeting/Greeting.class
```

同样，`Punctuation` 需要从 `lib002` 开始查找，而我们自己的 `Main` 要从当前目录开始查找。在 `deployment` 下，把这三个条目一起交给 `-cp`：

```bash
java -cp ".:lib001:lib002" dev.deepdive.app.Main
```

这里配置的是**一个 classpath，包含三个条目**：`.`、`lib001`、`lib002`。它们分别以当前的 `deployment` 目录、它下面的 `lib001` 和 `lib002` 作为搜索起点。在 macOS 和 Linux 中，条目之间用冒号 `:` 分隔；Windows 中则用分号 `;`，写成 `".;lib001;lib002"`。

查找本例中的类时，类加载器依次尝试这些目录条目。三个类最终分别在以下位置被找到：

| 要加载的类 | 在哪个 classpath 条目下找到 | 对应的 class 文件（相对 `deployment`） |
| --- | --- | --- |
| `dev.deepdive.app.Main` | `.` | `dev/deepdive/app/Main.class` |
| `dev.deepdive.greeting.Greeting` | `lib001` | `lib001/dev/deepdive/greeting/Greeting.class` |
| `dev.deepdive.punctuation.Punctuation` | `lib002` | `lib002/dev/deepdive/punctuation/Punctuation.class` |

这样，我们就能分开管理这些文件，同时保留各自的包目录树，不必修改代码中的包名和引用。程序输出为：

```text
Hello, classpath!
```

下面是完整操作：进入 `deployment`，确认三个类的存放位置，再配置包含三个条目的 classpath 启动程序。

![classpath 多条目实验：查看 deployment 目录结构，使用包含 .、lib001 和 lib002 三个条目的 classpath 成功运行程序](assets/experiment-04-multiple-classpath.png)

接着，我们故意漏掉 classpath 中的 `lib002` 条目，其他条件不变：

```bash
java -cp ".:lib001" dev.deepdive.app.Main
```

程序能够找到并启动 `Main`，也能够找到 `Greeting`，但执行到需要 `Punctuation` 时会失败：

```text
java.lang.NoClassDefFoundError: dev/deepdive/punctuation/Punctuation
Caused by: java.lang.ClassNotFoundException: dev.deepdive.punctuation.Punctuation
```

在这次实验中，我们已经进入了 `Main.main`。执行到 `Greeting` 需要使用 `Punctuation` 时，类加载器无法从当前 classpath 中找到它，因此抛出 `ClassNotFoundException`。JVM 执行代码时需要这个类，却未能加载到它，最终向我们报告 `NoClassDefFoundError`，并把前面的 `ClassNotFoundException` 列为原因。

我们没有删除 `Punctuation.class`，它还在磁盘上；缺失的是 classpath 中的 `lib002` 条目。以后遇到这类错误，**除了确认 class 文件存在，还要核对“classpath 目录条目 + 类名对应路径”是否真正指向它。**

这次失败的完整输出如下：

![遗漏 lib002 后的完整报错：NoClassDefFoundError 及其原因 ClassNotFoundException 均指向 Punctuation](assets/experiment-05-missing-dependency.png)

> 除了 `-cp`，`CLASSPATH` 环境变量也可以设置默认的 classpath。命令中的 `-cp` 优先于这个环境变量；两者都没有设置时，默认只有当前工作目录 `.` 这一个条目。本文前面的默认路径实验没有设置该变量，后面的实验则用 `-cp` 明确指定条目。

到这里，本文中这些放在普通目录里的类如何运行，已经可以归结为三件事：

- **先编译**：把自己写的 `.java` 编译成 `.class`，外部依赖使用提供方的编译产物。
- **指定入口类**：启动时传入类名，不把存放目录随意拼进包名。
- **配置 classpath**：用目录条目指定搜索起点，让入口类和运行需要的依赖都能按原有类名找到。

## 回到 IDE：这些信息被保存在哪里

现在把同样的 Java 程序交给 Eclipse 或 IntelliJ IDEA，编译输出、依赖位置和入口类依然需要确定。区别在于：我们不再每次手写命令，而是把这些信息交给 IDE 的项目设置和运行配置。

以使用 IDE 自身构建功能的普通 Java 项目为例，需要管理的信息可以对应到四项设置：

| 要确定的信息 | Eclipse | IntelliJ IDEA |
| --- | --- | --- |
| 哪些源码参与编译 | Java Build Path → Source | Project Structure → Modules → Sources |
| class 文件输出到哪里 | Java Build Path → Source 中的输出目录 | Project Structure → Modules → Paths 中的编译输出目录 |
| 编译和运行需要哪些依赖 | Java Build Path 中的依赖配置，以及启动配置中的 classpath | Project Structure → Modules → Dependencies，以及运行配置中的 classpath |
| 从哪个类、哪个工作目录启动 | Run Configurations → Java Application | Run → Edit Configurations → Application |

这里的源码目录，是我们告诉 IDE 去哪里读取 `.java`；编译输出目录，则决定 `.class` 生成在哪里，对应前面 `javac -d` 指定的输出位置。IDE 按照这些设置组织编译工作。Eclipse 把它们放在 [Java Build Path](https://help.eclipse.org/latest/topic/org.eclipse.jdt.doc.user/reference/ref-properties-build-path.htm) 中；IntelliJ IDEA 分别通过 [Sources](https://www.jetbrains.com/help/idea/content-roots.html) 和 [Paths](https://www.jetbrains.com/help/idea/configure-modules.html#module-compiler-output) 管理。

依赖路径则同时关系到编译和运行。编译我们自己的代码时，编译器需要找到引用的外部类；启动程序时，类加载器也需要找到执行中用到的类。IDE 会根据项目中的依赖配置组织这两次查找所使用的路径，但**编译时能找到，不等于这次启动时也一定能找到**。Eclipse 的运行 classpath 默认从项目配置推导，也允许单独调整；IntelliJ IDEA 同样允许运行配置使用不同于编译阶段的 classpath。[Eclipse 启动配置](https://help.eclipse.org/latest/topic/org.eclipse.jdt.doc.user/tasks/tasks-java-local-configuration.htm)、[IntelliJ IDEA 依赖配置](https://www.jetbrains.com/help/idea/working-with-module-dependencies.html)、[Application 运行配置](https://www.jetbrains.com/help/idea/run-debug-configuration-java-application.html)

刚才遗漏 `lib002` 的实验就是一个具体例子：`Main.class` 已经编译好了，但这次启动使用的 classpath 少了一个条目，程序仍然会在执行中失败。在 IDE 中排查同样的问题，也要检查本次运行配置实际包含的条目。

运行配置还保存了入口类、工作目录、选用的 Java 运行环境，以及需要传入的参数。对应我们最后的实验，入口类是 `dev.deepdive.app.Main`，工作目录是 `deployment`，运行 classpath 包含 `.`、`lib001`、`lib002`。IDE 可以把这些位置转换成绝对路径传给启动进程；对类加载而言，关键是它们指向同一组目录。

所以，回到 IDE 点击运行时，我们已经知道该检查什么：**源码编译到了哪里，启动的是哪个类，运行 classpath 是否覆盖了它需要的类。** 这些信息在命令行里由我们显式写出，在 IDE 中则由项目设置和运行配置保存并传递。

## 参考资料

- [Oracle Java SE 8 Platform Overview：JRE 与 JDK](https://docs.oracle.com/javase/8/docs/technotes/guides/)
- [Oracle JDK 21：`javac` 命令](https://docs.oracle.com/en/java/javase/21/docs/specs/man/javac.html)
- [Oracle JDK 21：`java` 命令与 classpath](https://docs.oracle.com/en/java/javase/21/docs/specs/man/java.html)
- [Oracle Java SE 21：`ClassLoader` API](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/ClassLoader.html)
- [Java 虚拟机规范 21：class 文件格式](https://docs.oracle.com/javase/specs/jvms/se21/html/)
- [Eclipse：Java Build Path](https://help.eclipse.org/latest/topic/org.eclipse.jdt.doc.user/reference/ref-properties-build-path.htm)
- [Eclipse：Java Application 启动配置](https://help.eclipse.org/latest/topic/org.eclipse.jdt.doc.user/tasks/tasks-java-local-configuration.htm)
- [IntelliJ IDEA：源码目录](https://www.jetbrains.com/help/idea/content-roots.html)
- [IntelliJ IDEA：编译输出设置](https://www.jetbrains.com/help/idea/configure-modules.html#module-compiler-output)
- [IntelliJ IDEA：依赖配置](https://www.jetbrains.com/help/idea/working-with-module-dependencies.html)
- [IntelliJ IDEA：Application 运行配置](https://www.jetbrains.com/help/idea/run-debug-configuration-java-application.html)
