# 拆解 Java 启动：编译、类加载与 classpath

[中文](zh-CN.md) · [日本語](ja.md) · [English](en.md)

我们先把 Java 项目缩到最小：一个 `Main.java`，一套 JDK。不用 Eclipse 或 IntelliJ IDEA，不用 Maven，也不引入 Spring，编译和启动直接使用 `javac` 与 `java`。

沿着这条最短路径，我们逐步拆开程序的运行过程：写下的源码怎样变成 class 文件，传入的类名怎样对应到磁盘上的文件，以及编译和运行阶段各自的 classpath 怎样决定从哪里查找所需的类。

然后，我们把这些 class 文件收进 JAR，再回到 Maven 和 Spring Boot 项目中，观察同一套查找关系怎样继续发挥作用。

本文实验使用 JDK 21，终端命令采用 macOS/Linux 的写法。源码与复现步骤见本章的 [lab](../lab/README.md)，阅读时也可以直接对照实操截图。

## 从 JDK 提供的工具开始

我们熟悉的 `javac` 和 `java` 都由 JDK 提供。本文用 `javac` 将 `.java` 源文件编译成 `.class` 字节码文件，再用 `java` 启动 JVM，加载并执行编译结果：

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

> JDK 21 也支持 `java Main.java` 这样的单文件源码启动方式：由启动器先在内存中编译，再执行。本文把编译与启动拆开，观察生成的 class 文件及其查找位置。

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

至此，我们完成了最小的一轮编译和运行。不过，编译不只是转换代码的形式：`javac` 还需要根据类和方法的声明，检查源码中的类引用和方法调用是否成立。到了运行阶段，JVM 则需要加载实际参与执行的字节码。两步都需要找到我们使用的类，但目的不同。

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

## classpath：给类名一个搜索起点

当前实验中的应用类都以 class 文件的形式放在普通目录中。要根据类名找到它们，需要先确定从哪些目录开始查找。这组查找位置由 **classpath** 指定：**一个 classpath 可以包含多个条目；在当前实验中，每个条目都是一个目录，也就是类文件的搜索起点。**

classpath 并不只用于启动程序。编译器需要查找依赖类的声明，运行时需要查找参与执行的字节码，两者分别使用各自的 classpath 配置。`javac -cp` 配置编译阶段的查找位置，`java -cp` 配置运行阶段的查找位置。

我们先沿着刚才的 `java` 命令，观察运行阶段怎样使用这些搜索起点。

### `java`、JVM 与类加载器

`java` 命令首先启动 JVM。理解 Java 的底层机制时，我们会反复遇到“运行时（runtime）”这个词。这里，它指的是支撑程序执行的一套机制，JVM 是 Java 运行时的核心。接下来要看的类加载，就是其中一项工作。

我们在命令后面写下的 `dev.deepdive.app.Main`，则是在指定入口类：这次运行从它开始。

执行入口方法之前，需要先根据类名找到字节码，将其加载到内存，在 JVM 中建立对应的类。负责这项工作的组件，叫作**类加载器（ClassLoader）**。

针对当前这种从普通目录中查找应用类的场景，我们可以用下面这段伪代码描述运行时的查找和加载过程：

```text
relativePath = className.replace(".", "/") + ".class"

for each entry in classpath:  // 为什么需要多个条目？后面用实验说明。
    classFile = joinPath(entry, relativePath)
    if classFile exists:
        bytes = read(classFile)
        return defineClass(className, bytes)

throw ClassNotFoundException
```

类名先被转换成相对路径，再与 classpath 中的各个目录条目拼接。找到文件后读取字节数据，`defineClass` 会检查请求的类名是否与文件内部记录的类名一致，并通过 JVM 提供的能力定义出运行时的 `Class` 对象。完成启动所需的准备后，运行环境调用 `Main.main`，进入我们写下的代码。

这样，我们就能把前面的启动参数理解清楚：`java` 接收的是要启动的类名，classpath 提供查找位置，类加载器负责将两者对应到实际文件。类名确定我们要用哪个类，查找位置则由 classpath 配置。

### 用 `java -cp` 明确搜索起点

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

我们没有改代码，甚至连启动命令都没改，但默认搜索起点已经变了。把 `.` 展开成当时的工作目录，再拼上类名对应的路径，从 `step-2` 这一层写起，就能直接看出差别：

| 当前工作目录 | 默认 classpath 条目 | 实际查找路径 | 结果 |
| --- | --- | --- | --- |
| `step-2/out` | `.` | `step-2/out/dev/deepdive/app/Main.class` | 文件存在 |
| `step-2` | `.` | `step-2/dev/deepdive/app/Main.class` | 文件不存在 |

两次启动使用的默认 classpath 都是 `.`，但 `.` 始终表示当时的工作目录。工作目录从 `step-2/out` 变成 `step-2` 后，类加载器实际搜索的位置也随之改变。文件没有移动，所以第二次启动会报告：

```text
Error: Could not find or load main class dev.deepdive.app.Main
Caused by: java.lang.ClassNotFoundException: dev.deepdive.app.Main
```

我们不必为此切回 `out`。留在 `step-2`，用 `-cp` 明确告诉启动器从 `out` 开始查找：

```bash
java -cp out dev.deepdive.app.Main
```

程序恢复正常。`-cp out` 将这次启动的 classpath 设置为只有 `out` 这一个条目。这里的 `out` 相对工作目录 `step-2` 解析，搜索起点回到 `step-2/out`。

**工作目录决定 classpath 中相对路径如何解析，classpath 的目录条目决定查找类时从哪里开始。** 条目可以使用相对路径，也可以使用绝对路径。

下面是这次切换工作目录后的完整操作：同一条启动命令先报告找不到主类，补上 `-cp out` 后恢复正常。

![切换到 step-2 后找不到主类，使用 java -cp out dev.deepdive.app.Main 后成功输出 Hello, Java!](assets/experiment-03-classpath-root.png)

## 一个 classpath 可以包含多个条目

现在回到前面伪代码里留下的那条注释：为什么这里用了 `for` 循环？刚才的 classpath 只有一个 `out` 条目，但一个 classpath 可以包含多个条目，查找时依次尝试它们。

比如，我们拿到了别人编译好的 `Greeting.class` 和 `Punctuation.class`，想把它们与自己的代码分开存放，就可以分别放进 `lib001`、`lib002`。

这次也把我们自己的代码拆成两个源文件：`Main.java` 负责启动，同包中的 `MessageService.java` 负责组合消息。我们进入下面的 `deployment` 目录，接下来的编译和运行都在这里进行：

```text
deployment/  ← 当前工作目录
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

先看 `Main.java`：

```java
package dev.deepdive.app;

public class Main {
    public static void main(String[] args) {
        System.out.println(MessageService.messageFor("classpath"));
    }
}
```

再看同一个包中的 `MessageService.java`：

```java
package dev.deepdive.app;

import dev.deepdive.greeting.Greeting;
import dev.deepdive.punctuation.Punctuation;

final class MessageService {
    private MessageService() {
    }

    static String messageFor(String name) {
        return Greeting.forName(name) + Punctuation.mark();
    }
}
```

两个外部类的用法已经由提供方确定：`Greeting.forName("classpath")` 返回 `Hello, classpath`，`Punctuation.mark()` 返回 `!`。`MessageService` 直接使用这两个类，把它们的结果拼在一起：

```text
Main
└── MessageService
    ├── Greeting
    └── Punctuation
```

### 编译器也需要查找依赖

编译器不只是把源码“翻译”成字节码。`javac` 还会做语法检查，并确认源码中的类型和依赖引用是否合法。

比如 `MessageService` 中的 `Greeting.forName(name)`：编译器首先得找到 `Greeting` 的声明，再检查它是否提供了可访问的 `forName` 方法、能否接收这里的参数，以及返回值能否参与后面的表达式。对 `Punctuation.mark()` 也一样。

这些检查需要用到类和方法的声明。我们自己的两个类，可以从本次交给 `javac` 的源码中获得声明；两个外部类没有源码，就需要读取 `Greeting.class` 和 `Punctuation.class` 中的类型信息。**这里读取的是声明，不会执行 `Greeting.forName` 或 `Punctuation.mark`。**

仍在 `deployment` 下，把两个源码文件一起交给 `javac`。先不配置编译阶段的 classpath：

```bash
javac \
  dev/deepdive/app/Main.java \
  dev/deepdive/app/MessageService.java
```

这次编译失败，关键报错是：

```text
package dev.deepdive.greeting does not exist
package dev.deepdive.punctuation does not exist
```

`Main.java` 和 `MessageService.java` 都已经明确交给编译器了，缺少的是两个外部类的位置。默认从当前目录开始查找时，编译器找不到 `dev/deepdive/greeting/Greeting.class` 和 `dev/deepdive/punctuation/Punctuation.class`；它们实际分别在 `lib001`、`lib002` 下面。

下面是这次编译失败的完整操作。两个外部 class 文件已经在目录中，但编译器还没有得到它们的搜索起点：

![未配置编译 classpath：目录中已有 Greeting.class 和 Punctuation.class，同时编译 Main.java 与 MessageService.java 时仍报告两个外部包不存在](assets/experiment-04-compile-classpath-missing.png)

### 用 `javac -cp` 补上依赖的搜索起点

现在用 `javac -cp` 把 `lib001`、`lib002` 这两个目录条目交给编译器，再执行一次。在 macOS 和 Linux 中，条目之间用冒号 `:` 分隔；Windows 中则用分号 `;`，这里应写成 `"lib001;lib002"`。

```bash
javac -cp "lib001:lib002" \
  dev/deepdive/app/Main.java \
  dev/deepdive/app/MessageService.java
```

这次编译器能够找到两个外部类的声明，完成对源码的检查。编译成功后，两个 class 文件默认生成在对应的源码旁边：

```text
deployment/
├── dev/
│   └── deepdive/
│       └── app/
│           ├── Main.java
│           ├── Main.class
│           ├── MessageService.java
│           └── MessageService.class
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

虽然 `Main` 要调用 `MessageService`，但我们不必先手动编译 `MessageService.java`。**同一次 `javac` 调用中明确列出的源码会成组编译，文件顺序不影响它们之间声明的解析。** 两个文件交换位置，仍然可以完成这次编译。

### 把 `lib001` 写进 `import` 呢？

编译已经通过。回头看这个目录结构，也许我们会想到另一种省事的写法：不配置 `-cp`，直接把 `MessageService` 里的 `import` 改成与存放目录一致的样子：

```diff
-import dev.deepdive.greeting.Greeting;
-import dev.deepdive.punctuation.Punctuation;
+import lib001.dev.deepdive.greeting.Greeting;
+import lib002.dev.deepdive.punctuation.Punctuation;
```

这样让编译器从当前的 `deployment` 目录开始找，看起来正好能找到两个 class 文件。但找到文件，只完成了一半。

以 `Greeting` 为例，别人编写它时，声明的包是 `dev.deepdive.greeting`。编译后的 `Greeting.class` 内部已经记录了完整类名 `dev.deepdive.greeting.Greeting`。我们把文件放进 `lib001`，不会给它的包名加上一层 `lib001`；修改自己源码中的 `import`，也不会改写这个 class 文件。

把修改后的查找过程展开，就能看到冲突在哪里：

```text
import 请求的类名
lib001.dev.deepdive.greeting.Greeting
                  │
                  ▼
从 deployment 开始，找到文件
lib001/dev/deepdive/greeting/Greeting.class
                  │
                  ▼
文件内部记录的类名
dev.deepdive.greeting.Greeting
                  │
                  ▼
类名不一致 → 编译失败
```

这次在编译阶段就会被拒绝，编译器会报告 `class file contains wrong class`：文件确实找到了，但里面的类不是 `import` 请求的那个。`Punctuation` 也是同样的问题。

所以我们保留原来的 `import`，用 `-cp "lib001:lib002"` 调整搜索起点。**classpath 决定去哪里找类，`import` 指明源码引用的是哪个类；修改 `import`，不能给外部类重命名。**

### 运行时仍要单独配置 classpath

刚才的 `-cp` 告诉了编译器去哪里读取依赖。现在字节码已经生成，启动程序时，我们还需要告诉运行时去哪里加载这些类。**`java` 不会自动继承刚才 `javac -cp` 的设置。**

我们仍在 `deployment` 下，这次把自己的 class 文件和外部依赖的搜索起点一起交给 `java`：

```bash
java -cp ".:lib001:lib002" dev.deepdive.app.Main
```

这里配置的是**一个 classpath，包含三个条目**：`.`、`lib001`、`lib002`。

### 为什么运行时的 classpath 多了一个 `.`

对照刚才的编译命令，`javac -cp` 后面只有 `"lib001:lib002"`，这里却变成了 `".:lib001:lib002"`。多出来的 `.`，是我们把当前的 `deployment` 目录也列为搜索起点，并不是改变工作目录。

编译时，我们已经把 `Main.java` 和 `MessageService.java` 的文件路径直接交给了 `javac`。它不需要再通过 classpath 寻找这两份输入源码，因此这条命令只需用 classpath 补上两个外部依赖的位置。加入 `.` 也可以，只是本次编译不需要它。

运行时不同。我们只给了 `java` 一个入口类名 `dev.deepdive.app.Main`，没有直接给它文件路径。类加载器需要自己找到 `Main.class`，以及程序用到的 `MessageService.class`。这两个文件都位于 `deployment/dev/deepdive/app/` 下，所以要从 `deployment` 这一层，也就是 `.`，开始查找。

**在这组目录实验中，显式设置 `-cp` 后，使用的就是列出的那些条目，不会自动附加默认的 `.`。** 如果这里只写 `"lib001:lib002"`，类加载器不会再从 `deployment` 这一层查找，连入口类 `Main` 都无法找到。

每个目录条目都作为类文件的搜索起点。四个类分别在以下位置被找到：

| 要加载的类 | 在哪个 classpath 条目下找到 | 对应的 class 文件（相对 `deployment`） |
| --- | --- | --- |
| `dev.deepdive.app.Main` | `.` | `dev/deepdive/app/Main.class` |
| `dev.deepdive.app.MessageService` | `.` | `dev/deepdive/app/MessageService.class` |
| `dev.deepdive.greeting.Greeting` | `lib001` | `lib001/dev/deepdive/greeting/Greeting.class` |
| `dev.deepdive.punctuation.Punctuation` | `lib002` | `lib002/dev/deepdive/punctuation/Punctuation.class` |

目录和参数对应后，程序输出：

```text
Hello, classpath!
```

把编译和运行连起来，完整操作如下：先用 `javac -cp "lib001:lib002"` 编译两份源码，确认生成的 class 文件，再用 `java -cp ".:lib001:lib002"` 启动程序。

![分别配置编译与运行 classpath：生成 Main.class 和 MessageService.class 后，启动程序并输出 Hello, classpath!](assets/experiment-05-compile-and-run-classpath.png)

### 遗漏一个运行依赖

接着，我们故意漏掉运行 classpath 中的 `lib002` 条目，其他条件不变：

```bash
java -cp ".:lib001" dev.deepdive.app.Main
```

这次不是编译报错，而是程序执行中出现异常：

```text
java.lang.NoClassDefFoundError: dev/deepdive/punctuation/Punctuation
Caused by: java.lang.ClassNotFoundException: dev.deepdive.punctuation.Punctuation
```

在本次实验中，程序已经进入 `Main.main`，并成功加载了 `MessageService` 和 `Greeting`。执行到需要使用 `Punctuation` 时，类加载器无法从当前 classpath 中找到它，因此查找产生 `ClassNotFoundException`。JVM 执行代码时需要这个类，却未能完成加载，最终向程序报告 `NoClassDefFoundError`，并把前面的 `ClassNotFoundException` 列为原因。

我们没有删除 `Punctuation.class`，它还在磁盘上；缺失的是运行 classpath 中的 `lib002` 条目。编译时找到了所需声明，不意味着下一次启动程序时仍然能找到这些类。**除了确认 class 文件存在，还要核对“classpath 目录条目 + 类名对应路径”是否真正指向它。**

下面的实操中，目录树仍然能看到 `Punctuation.class`；去掉运行 classpath 中的 `lib002` 后，异常出现在 `MessageService.messageFor` 中：

![遗漏运行 classpath 中的 lib002：Punctuation.class 仍在磁盘上，程序执行到 MessageService.messageFor 时报告 NoClassDefFoundError，并以 ClassNotFoundException 为原因](assets/experiment-06-runtime-classpath-missing.png)

> 除了 `-cp`，`CLASSPATH` 环境变量也可以设置默认的 classpath。命令中的 `-cp` 优先于这个环境变量；两者都没有设置时，默认只有当前工作目录 `.` 这一个条目。本文的默认路径实验没有设置该变量，其他实验则用 `-cp` 明确指定条目。

到这里，我们已经把编译和运行的关系分开了：编译器需要拿到源码与依赖的类型声明，生成自己的 class 文件；启动时，再指定入口类，并让运行 classpath 覆盖程序需要的字节码。这两次查找分别配置，但都要遵守类名与目录的对应关系。

## 把 class 文件收进 JAR

实际开发中，我们使用的外部依赖通常是一个个 JAR 包，而不是前面实验中单独存放的 class 文件。那么，把 `lib001` 和 `lib002` 换成 JAR 之后，编译和启动的命令需要怎样调整？

先看 JAR 里面装了什么。**JAR（Java Archive）** 是以 ZIP 格式为基础的归档，可以把 class 文件及其他资源收在一个文件里，并保留内部的目录结构。前面按类名查找 class 文件的思路仍然适用，只是查找的位置从目录变成了归档内部。

`javac` 负责把源码编译成 class 文件，JDK 提供的另一个命令 `jar` 则把已有文件复制进归档。**编译改变代码的表示形式，打包改变文件的组织方式。** 打包完成后，原目录里的 class 文件仍然保留。

> 下载依赖时，我们还可能看到配套的 `xxx-sources.jar`。它通常是单独提供的源码归档：`xxx.jar` 存放编译好的 class 文件，`xxx-sources.jar` 存放对应的 `.java` 源码，方便我们在 IDE 中阅读源码、对照源码调试。JAR 格式也允许把源码和字节码装在同一个包里，但“提供源码”不一定意味着二者混装。对于本文的启动方式，运行时使用的仍是 class 文件，源码包不能替代编译好的依赖 JAR。

下面继续使用 `Main`、`MessageService`、`Greeting` 和 `Punctuation`，但换到独立的 `lab/jar-classpath/work` 实验目录，不改动前面的文件。准备好的两份应用源码在 `src/dev/deepdive/app/` 下，两个外部 class 文件仍分别位于 `lib001` 和 `lib002`：

```text
work/  ← 接下来命令的工作目录
├── src/dev/deepdive/app/
│   ├── Main.java
│   └── MessageService.java
├── lib001/dev/deepdive/greeting/Greeting.class
├── lib002/dev/deepdive/punctuation/Punctuation.class
└── lib/  ← 用来放打包后的依赖
```

### 先读懂 jar 命令的结构

我们先按“做什么、操作哪个 JAR、还需要哪些输入”的顺序来读命令：

```text
jar --create --file 目标JAR 要打包的文件
jar --list   --file 目标JAR
```

`--create` 和 `--list` 指定行为：前者创建归档，后者列出已有归档的内容。`--file` 后面跟这次操作的目标 JAR 路径；创建时，它决定文件生成在哪里，查看时，它决定读取哪个文件。

打包时，我们还要决定从哪里取文件。这里可以加上 `-C`，把读取文件的位置切换到指定目录。**可以把 C 按 change directory（切换目录）来记。** 例如，把 `lib001` 中的内容打进 `lib/greeting.jar`：

```bash
jar --create --file lib/greeting.jar -C lib001 .
```

把这条命令拆开看：

| 命令片段 | 本次操作的含义 |
| --- | --- |
| `--create` | 创建归档 |
| `--file lib/greeting.jar` | 把生成的 JAR 放在当前工作目录的 `lib` 下 |
| `-C lib001` | 接下来从 `lib001` 目录中取文件 |
| `.` | 收入该目录的全部内容，包括子目录 |

这里有两个不同的位置：`--file` 决定 **JAR 写到哪里**，`-C` 决定 **从哪里读取要打包的文件**。`-C` 不会切换我们终端的工作目录，也不会让 `lib/greeting.jar` 生成在 `lib001` 下面。

最后的 `.` 是相对于 `-C` 指定的 `lib001` 来解释的。因此，收进包里的是从 `dev` 开始的内容，**不包含外面的 `lib001` 这一层**。这正好保留了类名对应的路径。

第二个依赖沿用同样的结构，只换掉输出文件和输入目录：

```bash
jar --create --file lib/punctuation.jar -C lib002 .
```

![将 lib001 和 lib002 中的依赖分别打包到 lib 目录，原有 class 文件仍然保留](assets/experiment-07-jar-packaging.png)

要查看刚才生成的包，把行为换成 `--list`，仍用 `--file` 指定目标。这次只读取 JAR，不需要再提供打包的输入：

```bash
jar --list --file lib/greeting.jar
```

把列出的条目画成目录树，结构是：

```text
greeting.jar
├── META-INF/
│   └── MANIFEST.MF  ← 本次打包自动生成的文件
└── dev/
    └── deepdive/
        └── greeting/
            └── Greeting.class
```

我们可以观察到两处变化。原来的 `Greeting.class` 已经收进包里，路径仍然是 `dev/deepdive/greeting/Greeting.class`，与它相对于 `lib001` 的路径一致。

另外，包里还多出了一个我们没有手动准备的 `META-INF/MANIFEST.MF`。这是 `jar` 在本次打包时自动生成的文本文件，称为 **清单文件（manifest）**，用来记录这份 JAR 的相关信息。除了文件本身，JAR 还可以携带这样的说明；稍后我们就会用它记录应用的启动入口和依赖位置。

![查看两份依赖 JAR：包内的类路径从 dev 开始，同时包含自动生成的 META-INF/MANIFEST.MF](assets/experiment-08-jar-contents.png)

### 使用 JAR，仍然是同一套 classpath

打包需要我们安排输入目录和包内结构，使用时反而没有增加新的步骤：**把 `-cp` 中的目录条目换成 JAR 路径即可，类名和代码都不用改。** 对前面的 `Greeting` 来说，两种查找方式只是容器不同：

```text
类名：dev.deepdive.greeting.Greeting

目录条目 lib001
  → 查找 lib001/dev/deepdive/greeting/Greeting.class

JAR 条目 lib/greeting.jar
  → 查找包内条目 dev/deepdive/greeting/Greeting.class
```

对编译器也是一样。仍在 `work` 目录，使用这两个 JAR 编译自己的代码：

```bash
javac -cp "lib/greeting.jar:lib/punctuation.jar" -d app-classes \
  src/dev/deepdive/app/Main.java \
  src/dev/deepdive/app/MessageService.java
```

这次我们用前面见过的 `-d`，把生成的 class 文件放进 `app-classes`，与源码分开。自己的代码仍放在目录中，依赖放在 JAR 中，也可以直接启动：

```bash
java -cp "app-classes:lib/greeting.jar:lib/punctuation.jar" dev.deepdive.app.Main
```

一个 classpath 可以同时包含目录和 JAR 条目，不要求所有文件采用同一种存放方式。

![使用两份依赖 JAR 编译应用到 app-classes，再用目录与 JAR 混合的 classpath 启动，输出 Hello, classpath!](assets/experiment-09-jar-compile-and-run.png)

如果也想把自己的代码打成 JAR，仍然使用刚才的打包结构。这次从 `app-classes` 取文件，写入当前工作目录下的 `app.jar`：

```bash
jar --create --file app.jar -C app-classes .
```

启动时只把第一个条目从 `app-classes` 换成 `app.jar`：

```bash
java -cp "app.jar:lib/greeting.jar:lib/punctuation.jar" dev.deepdive.app.Main
```

预期输出仍然是 `Hello, classpath!`。三个条目现在都是 JAR：`app.jar` 提供我们自己的两个类，其余两个 JAR 提供外部依赖。运行时可以直接读取包内的 class 文件，不需要我们先手动解压。

![将应用字节码打包成 app.jar，查看包内结构，再使用三个 JAR 条目启动应用](assets/experiment-10-application-jar.png)

### 让 JAR 记录自己的启动信息

我们平时还会见到 `java -jar app.jar` 这样的启动方式：只指定 JAR 文件，不再在命令中列出入口类和依赖。怎样才能让刚才的应用也这样启动？

这时就用到了刚才在包内看到的 `META-INF/MANIFEST.MF`。`app.jar` 按同样的方式打包，也会生成这份清单，但打包工具不会自动替我们选择入口类、填写依赖位置。因此，刚才的 `app.jar` 还不能直接用 `java -jar` 启动，我们需要先把这些信息补进它的清单。

不用解压 JAR 去修改里面的文件。我们先在当前工作目录准备一个文本文件 `app-manifest.mf`，写下要补充的两项信息，再让打包命令把它们写入包内的清单：

```text
Main-Class: dev.deepdive.app.Main
Class-Path: lib/greeting.jar lib/punctuation.jar

```

`Main-Class` 指定从哪个类的 `main` 方法开始。`Class-Path` 则给出这份应用 JAR 需要的外部依赖。这里仍然是三个独立的 JAR，没有把两个依赖复制进 `app.jar`。

这次不需要换一套打包命令，只在原来的 `-C` 前加上 `--manifest app-manifest.mf`，指定要一并写入的清单信息。输出位置、输入目录和收取内容的方式都不变：

```bash
jar --create --file app.jar \
  --manifest app-manifest.mf \
  -C app-classes .
```

这会重新生成 `app.jar`，并把清单内容写入包内的 `META-INF/MANIFEST.MF`。现在就可以用下面的命令启动：

```bash
java -jar app.jar
```

这里传给 `-jar` 的确实是 JAR 文件路径；入口类和依赖位置改由清单提供。清单文件末尾要保留换行，`Class-Path` 中的多个位置用空格分隔，而不是命令行 `-cp` 的冒号。这里的 `lib/greeting.jar`、`lib/punctuation.jar` 相对于 **`app.jar` 所在目录** 解析，不是相对于启动命令的工作目录。

这就解释了为什么我们可以把 `app.jar` 与整个 `lib` 目录一起交付：只要它们的相对位置保持不变，清单就能继续指向那两份依赖。

**`java -jar` 不会沿用命令行 `-cp` 的那套设置。** 所以不能指望写成 `java -cp "lib/greeting.jar:lib/punctuation.jar" -jar app.jar` 就补上依赖；本例使用的是应用清单里的 `Class-Path`。

![创建并查看清单后重新打包，在 work 中执行 java -jar app.jar，再切换到父目录执行 java -jar work/app.jar，两次均成功输出 Hello, classpath!](assets/experiment-11-manifest-launch.png)

## 回看 Maven：依赖位置与目录约定

还记得标准的 Maven 项目结构吗？我们在根目录的 `pom.xml` 中声明需要的依赖，把代码写在 `src/main/java` 下。执行 `mvn compile` 后，编译得到的字节码出现在 `target/classes` 中；对于普通 JAR 项目，执行 `mvn package`，还会在 `target` 下生成 JAR 包。

结合前面亲手完成的编译、启动和打包，我们能不能大致推测出：**Maven 是怎样找到依赖、编译源码，再把结果打成 JAR 的？**

我们可以把 Maven 做的这些工作分成两部分：**一是管理外部依赖的位置，二是管理项目自身的源码、资源和编译产物。** 前面这些位置由我们写进命令；在 Maven 项目中，它们有了统一的配置和约定。

### 1. 管理外部依赖：需要的 JAR 在哪里？

前面我们手动把依赖放进 `lib001`、`lib002`，或打成 `lib` 下的 JAR，再把这些位置写进 `-cp`。使用 Maven 时，我们改为在 `pom.xml` 中声明依赖的名称、版本等信息。Maven 根据这些声明，整理出当前项目所需的完整依赖列表；对于这里讨论的普通 Java 类库，它们通常就是一个个 JAR 包。

这些 JAR 不必再由我们逐份放进项目目录。Maven 使用一个**本地仓库**统一存放依赖，供不同项目复用。它默认位于用户主目录下的 `.m2/repository`，其中按依赖的名称、版本等信息组织文件。本地缺少所需的 JAR 时，Maven 通常会从远程仓库下载并保存到这里。

有了这份依赖列表和统一的存放位置，Maven 就能定位所需的 JAR，把它们的实际路径组织成当前阶段使用的 classpath，让编译时能够找到所需的类。**这正对应前面我们查找依赖文件，再把路径填进 `-cp` 的工作。** 只是现在由 Maven 根据项目配置完成，不再需要我们逐个抄写路径。

既然 Maven 已经能帮我们组织 classpath，为不同的使用场景分别准备一份也就顺理成章了：编译主代码、编译测试代码、运行应用，不必使用完全相同的依赖列表。

`pom.xml` 中依赖项的 `scope` 就是在说明：**这份依赖应该出现在哪些场景的 classpath 中。** 比如，我们通常只在测试代码中使用 JUnit，便可以为它配置 `<scope>test</scope>`。对照两次编译来看：编译测试代码时，classpath 中会包含 JUnit；编译主代码时，则不会把它加进去。这样就能让两类源码使用不同的编译依赖。

### 2. 管理项目文件：源码放哪里，编译结果放哪里？

再看一份采用默认约定的普通 Maven JAR 项目。下面把源码目录和构建后的典型产物放在一起：

```text
project/
├── pom.xml
├── src/
│   ├── main/
│   │   ├── java/             ← 主代码，下面按 package 组织
│   │   └── resources/        ← 主代码使用的配置等资源
│   └── test/
│       ├── java/             ← 测试代码，下面同样按 package 组织
│       └── resources/        ← 测试使用的资源
└── target/                   ← 构建产物，不只包含字节码
    ├── classes/              ← 主代码的 class 和主资源
    ├── test-classes/         ← 测试代码的 class 和测试资源
    └── example-1.0.0.jar     ← 打包产物，名称由项目配置决定
```

我们可以按两层来记：`main` 和 `test` 区分用途，`java` 和 `resources` 区分 Java 源码与资源。构建时，源码需要编译，资源通常按相对路径复制到对应的输出目录。主代码的 class 文件与资源汇集到 `target/classes`，测试代码的 class 文件与资源则汇集到 `target/test-classes`。

这与前面指定 `javac -d app-classes` 是同一种安排：我们手动选择了 `app-classes`，而 Maven 项目默认约定把构建产物放在 `target` 下，其中主代码的编译结果放进 `target/classes`，测试代码的编译结果放进 `target/test-classes`。`src/main/java` 也不是包名的一部分：`dev.deepdive.app.Main` 的源码位于它下面的 `dev/deepdive/app/Main.java`，编译后则位于 `target/classes/dev/deepdive/app/Main.class`。启动时，应用类的搜索起点就是 `target/classes`，不需要把 `src`、`main` 或 `java` 写进类名。

### 把构建过程还原成我们已经理解的操作

有了依赖位置和目录约定，我们就能大致还原普通 Java 项目的构建过程：

| 构建中的操作 | 用前面的知识理解 |
| --- | --- |
| 编译主代码 | 为编译器提供主源码、编译依赖的 classpath，以及输出位置 `target/classes` |
| 编译测试代码 | 测试也需要编译；它的 classpath 包含主代码输出和测试所需依赖，结果放进 `target/test-classes` |
| 打包普通 JAR | 把 `target/classes` 中的主代码与资源收进 JAR，默认不收入测试类，也不把外部依赖 JAR 一起装进去 |

两类源码的编译都对应我们熟悉的 `javac -cp … -d …`，只是参与编译的源码、依赖列表和输出目录不同。打包时的文件组织方式，则可以用 `jar --create --file … -C target/classes .` 来理解。这是在还原各步需要的信息，并不是说 Maven 必须逐条启动这些终端命令。

这样再看熟悉的构建命令，我们就能对应到具体产物：`mvn compile` 生成主代码的 class 文件，`mvn test-compile` 会继续编译测试代码；对于默认配置的普通 JAR 项目，`mvn package` 成功后会在 `target` 下得到打包产物。源码在哪里、编译要用哪些依赖、结果写到哪里，都由 Maven 根据配置和约定来安排。

那我们平时又是怎样启动 Maven 项目的呢？Maven 没有一个适用于所有项目的标准应用启动命令。在日常开发中，我们往往是在 IDE 里选中入口类，点击运行。IDE 能读取 Maven 项目配置，把编译好的应用类目录和运行所需的依赖 JAR 路径组织成 classpath，再用我们选定的入口类启动程序。前面手动填写启动命令的工作，就这样被简化成了一次点击。

如果离开 IDE，直接在终端使用 `java -cp` 启动，仍然需要像前面的实验一样提供完整的 classpath。依赖只有两个时，手写路径很容易；如果项目有几十甚至上百个依赖，逐条整理就既繁琐又容易遗漏，因此通常会借助工具生成这些路径。**一键启动省去了手动组织命令的过程，并没有省去 classpath。**

这样再看 Maven，它并没有改变类名与物理文件的对应关系。我们前面手动安排的搜索位置、编译输出和归档内容，在这里变成了可复用的项目约定和构建配置。

### 打包成功，能直接拿到服务器上启动吗？

`mvn package` 生成的 JAR，能不能像前面的实验一样，复制到服务器上就用 `java -jar` 启动？

回想刚才的操作：我们不仅打包了 class 文件，还为清单补上了入口和依赖位置。**普通 Maven JAR 项目的默认打包并不会自动填写 `Main-Class` 和依赖的 `Class-Path`。** 要直接启动，也需要补上这一步。

即使补上清单，还要解决另一个问题：依赖现在位于开发电脑的本地仓库里，只复制应用 JAR，并不会把这些依赖带到服务器上。清单中的路径必须能对应到服务器上实际存放的文件，不能指望服务器恰好具有开发电脑上的目录结构。

我们可以沿用前面的办法，把交付目录约定为：

```text
release/
├── app.jar
└── lib/
    ├── greeting-1.0.0.jar
    ├── punctuation-1.0.0.jar
    └── … 其他运行依赖
```

这里，清单中的 `Class-Path` 写成 `lib/greeting-1.0.0.jar` 这样的相对路径。把整个 `release` 目录一起部署，应用 JAR 与依赖的位置关系就保持不变，无需照搬开发电脑上的本地仓库。

这套目录和清单不需要手动整理。**Maven 提供了自动收集运行依赖、生成清单和组装发行包的手段**，配置好后，构建就能生成这样的部署产物。也可以选择把应用和依赖中的类、资源合并到一个 JAR 中，再配置启动入口。

具体配置可以按项目需要查阅文末资料，后续文章再展开。这里先抓住一点：无论采用哪种打包方式，都要让启动配置中的查找位置与交付文件的实际布局对应起来。

## 回看 Spring Boot：一个 JAR 怎样带上应用和依赖

我们平时部署 Spring Boot 项目，往往只需要复制一份可执行 JAR，再用 `java -jar` 启动。不用另带 `lib` 目录，也不用逐个填写依赖路径。沿着前面的思路，我们可以从文件组织和启动入口两方面理解它。

### 1. 组织文件：把应用和依赖放进同一个 JAR

配置好 Spring Boot 的打包方式后，构建会把应用类和运行依赖收进同一个 JAR。依赖仍保持各自的 JAR 文件，并没有拆开合并。沿用前面的类名，包内与类查找有关的结构可以画成：

```text
app.jar
├── META-INF/
│   └── MANIFEST.MF
├── org/springframework/boot/loader/
│   └── … 启动器的 class 文件
└── BOOT-INF/
    ├── classes/
    │   └── dev/deepdive/app/
    │       ├── Main.class
    │       └── MessageService.class
    └── lib/
        ├── greeting-1.0.0.jar
        ├── punctuation-1.0.0.jar
        └── … Spring Boot 等依赖 JAR
```

自己的类放在 `BOOT-INF/classes`，依赖 JAR 放在 `BOOT-INF/lib`。原来需要一起交付的应用和 `lib` 目录，现在都在这一份文件里。

### 2. 启动程序：先找到启动器，再找到应用入口

不过，应用类前面多了 `BOOT-INF/classes`，依赖也装进了 JAR 内部，前面的查找方式还能直接使用吗？以 Spring Boot 3.5 默认的可执行 JAR 布局为例，我们先看清单中的入口：

```text
Main-Class: org.springframework.boot.loader.launch.JarLauncher
Start-Class: dev.deepdive.app.Main
```

`java -jar` 仍然读取 `Main-Class`，但这次先执行的是 Spring Boot 提供的 `JarLauncher`。它也是包内的一个 Java 类，位于从归档根部开始的 `org/springframework/boot/loader/launch/` 路径下，因此可以按前面的规则找到。

`JarLauncher` 按 Boot 的目录约定建立类加载器，让它能从 `BOOT-INF/classes` 和 `BOOT-INF/lib` 中的嵌套 JAR 查找类，再根据 `Start-Class` 调用我们自己入口类的 `main` 方法。这不只是生成一串普通的 `-cp`：普通 JAR 的查找不会自动深入其中嵌套的 JAR。**先执行一段负责安排类加载的代码，再执行应用入口**，就是这里多出的一步。

```text
java -jar app.jar
        │
        ▼
Main-Class → Spring Boot 启动器
        │
        ├── 应用类：BOOT-INF/classes
        ├── 依赖类：BOOT-INF/lib 中的各份 JAR
        │
        ▼
Start-Class → dev.deepdive.app.Main.main
```

## 存放形式变了，查找的问题没变

从手动执行 `javac`、`java`，到 Maven 构建和 Spring Boot 可执行 JAR，我们始终在处理同一条链路：**把源码编译成 class 文件，让启动入口和它用到的类能够被找到。** 工具替我们组织了依赖、输出目录和启动信息，类名与物理文件之间的对应关系依然存在。

现在不妨打开一个熟悉的项目，找出它的编译输出和打包产物，再看看实际的启动命令：入口类是谁，所需的类放在哪里，又由哪一段启动配置或代码把这些位置连接起来？试着用本文的知识，还原它从源码到运行的过程。

## 参考资料

- [Oracle JDK 21：`javac` 命令、多源码编译与类型声明查找](https://docs.oracle.com/en/java/javase/21/docs/specs/man/javac.html)
- [Oracle JDK 21：`java` 命令与 classpath](https://docs.oracle.com/en/java/javase/21/docs/specs/man/java.html)
- [Oracle Java SE 21：`ClassLoader` API](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/ClassLoader.html)
- [Java 语言规范 21：二进制名称](https://docs.oracle.com/javase/specs/jls/se21/html/jls-13.html#jls-13.1)
- [Java 虚拟机规范 21：class 文件格式](https://docs.oracle.com/javase/specs/jvms/se21/html/jvms-4.html)
- [Java 虚拟机规范 21：使用用户定义的类加载器创建类](https://docs.oracle.com/javase/specs/jvms/se21/html/jvms-5.html#jvms-5.3.2)
- [Oracle JDK 21：jar 命令](https://docs.oracle.com/en/java/javase/21/docs/specs/man/jar.html)
- [Oracle JDK 21：JAR 文件规范](https://docs.oracle.com/en/java/javase/21/docs/specs/jar/jar.html)
- [Maven Source Plugin：生成配套的源码 JAR](https://maven.apache.org/plugins/maven-source-plugin/usage.html)
- [Maven：标准目录布局](https://maven.apache.org/guides/introduction/introduction-to-the-standard-directory-layout.html)
- [Maven：依赖机制](https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html)
- [Maven：构建生命周期](https://maven.apache.org/guides/introduction/introduction-to-the-lifecycle.html)
- [IntelliJ IDEA：从项目依赖组织编译与运行 classpath](https://www.jetbrains.com/help/idea/working-with-module-dependencies.html)
- [Maven JAR Plugin：普通 JAR 的输入目录](https://maven.apache.org/plugins/maven-jar-plugin/jar-mojo.html)
- [Maven Archiver：清单中的入口与依赖路径](https://maven.apache.org/shared/maven-archiver/examples/classpath.html)
- [Maven Dependency：自动收集依赖文件](https://maven.apache.org/plugins/maven-dependency-plugin/copy-dependencies-mojo.html)
- [Maven Assembly：组装发行包](https://maven.apache.org/plugins/maven-assembly-plugin/)
- [Maven Shade：将应用和依赖合并打包](https://maven.apache.org/plugins/maven-shade-plugin/)
- [Spring Boot 3.5：嵌套 JAR 的结构](https://docs.spring.io/spring-boot/3.5/specification/executable-jar/nested-jars.html)
- [Spring Boot 3.5：可执行 JAR 的启动](https://docs.spring.io/spring-boot/3.5/specification/executable-jar/launching.html)
- [Spring Boot 3.5：可执行 JAR 的打包配置](https://docs.spring.io/spring-boot/3.5/maven-plugin/packaging.html)
