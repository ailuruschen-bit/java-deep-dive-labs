# 拆解 Java 编译：编译器检查了什么

第一篇中，我们用 `javac` 生成 class 文件，再用 `java` 启动程序。编译器需要从 classpath 找到依赖，但找到文件只是开始：类找到了，为什么调用还是会报错？有些问题不运行就能发现，另一些却要等到程序执行时才出现，这条边界在哪里？

这次我们把注意力放到 `javac` 的诊断上。仍然不借助构建工具，只改变少量源码，观察编译器接受什么、拒绝什么，再从这些结果还原它需要完成的检查。

实验使用 JDK 21，命令采用 macOS/Linux 写法。每个实验都是独立的 `Main.java`，源码与操作步骤放在本章 [lab](../lab/README.md) 中。文中的实操位置暂留给作者后续提供真实截图。

## 编译失败，不是 main 抛出了异常

先看一个熟悉的程序，只是故意少写了一个分号：

```java
public class Main {
    public static void main(String[] args) {
        String message = "Hello, compiler!"
        System.out.println(message);
    }
}
```

在 `lab/01-syntax/broken` 中执行：

```bash
javac -d out Main.java
```

这次 `javac` 没有完成编译，诊断是：

```text
Main.java:3: error: ';' expected
        String message = "Hello, compiler!"
                                           ^
1 error
```

我们还没有执行 `java`，`main` 自然也没有运行。这里发生的是**编译器拒绝了源码**，不是程序执行到这行后抛出了异常。给应用代码加 `try/catch`，不能接住这个编译错误。

把分号补上，在 `lab/01-syntax/fixed` 编译、启动：

```bash
javac -d out Main.java
java -cp out Main
```

输出才真正出现：

```text
Hello, compiler!
```

`-d out` 只是在本章把编译产物与源码分开。每份独立示例使用自己的 `out`，避免前一次的 class 文件影响观察。

> 实操截图待补：缺少分号时编译失败；修正后生成 `out/Main.class`，启动才输出消息。

读 `javac` 的报错时，先找源码文件、行号和 `error:` 后面的内容。诊断中的源码摘录与 `^` 标记指出编译器发现问题的位置。这里先修复分号再重新编译，比把后续每条诊断都当成独立问题更有效：一个结构错误可能让后面的代码也难以识别。

## 语句能读懂，还要知道名称指向谁

修好刚才的语法错误，编译器还需要知道代码中的名称指向什么声明。

在 `lab/02-name/broken` 中，程序换成这样：

```java
public class Main {
    public static void main(String[] args) {
        System.out.println(message);
    }
}
```

```bash
javac -d out Main.java
```

关键诊断是：

```text
error: cannot find symbol
  symbol:   variable message
  location: class Main
```

`symbol` 在这里就是源码中需要对应到声明的名称。编译器知道这是一条方法调用语句，但找不到 `message` 对应的变量声明，因此还无法判断它的类型和能否使用。

这和第一篇缺少 classpath 条目的现象有关，但修法不同。第一篇缺少的是外部类的声明，需要补上依赖的搜索位置；这里缺少的是当前代码中的变量声明，调整 classpath 没有意义。

把下面一行加回 `println` 前面，编译器就能把这个名称和一个 `String` 类型的局部变量对应起来：

```java
String message = "Hello, compiler!";
```

完整修正版在 `lab/02-name/fixed`，编译与运行命令仍然是：

```bash
javac -d out Main.java
java -cp out Main
```

所以看到 `cannot find symbol` 时，不必立刻去找依赖：先看 `symbol` 中写的是变量、方法还是类，再看对应声明是否拼写正确、是否在当前位置可以使用。

> 实操截图待补：没有 `message` 声明时的诊断，以及补回声明后的编译结果。

## 找到声明之后，还要检查类型是否允许

现在 `message` 已经声明了。我们把它的初始值改成整数：

```java
public class Main {
    public static void main(String[] args) {
        String message = 42;
        System.out.println(message);
    }
}
```

在 `lab/03-type/broken` 中编译：

```bash
javac -d out Main.java
```

```text
error: incompatible types: int cannot be converted to String
```

这次不缺名称，也不缺分号。左边声明要保存 `String`，右边的 `42` 是 `int`，Java 没有规定这里可以自动把整数转成字符串，所以编译器拒绝了这次赋值。

在这个例子里，我们想保存的就是文本，把它写成 `"42"` 即可。完整修正版在 `lab/03-type/fixed`：

```java
String message = "42";
```

```bash
javac -d out Main.java
java -cp out Main
```

输出为 `42`。显示出来的字符虽然一样，源码中的整数和字符串却是两种类型，允许参与的操作也不同。

方法调用同样需要这些检查。回到上一章的 `Greeting.forName(name)`，光找到 `Greeting.class` 还不够：编译器需要确认方法名称、是否可访问、参数能否传入，随后才能使用它声明的返回类型检查外层表达式。**classpath 解决声明在哪里，类型检查解决这段用法是否成立。**

这不要求先运行一次 `forName`。方法接收什么类型、返回什么类型，都已经写在声明中；依赖只有 class 文件时，编译器也能读取这些信息。

> 实操截图待补：把整数赋给 `String` 时编译失败；改成字符串后编译并输出。

## 类型正确，也不代表使用前一定有值

接下来让消息来自启动参数。有参数就使用第一个参数，没有参数时暂时什么也不做：

```java
public class Main {
    public static void main(String[] args) {
        String message;
        if (args.length > 0) {
            message = args[0];
        }
        System.out.println(message);
    }
}
```

在 `lab/04-flow/broken` 中编译：

```bash
javac -d out Main.java
```

```text
error: variable message might not have been initialized
```

名称存在，类型也对。问题是到达 `println` 的路径不止一条：

```text
args.length > 0 ?
├── 是 → message = args[0] ──┐
└── 否 → 没有给 message 赋值 ─┤
                            ▼
                   println(message)
```

`message` 是局部变量，不会像对象的字段那样自动获得默认值。Java 要求在读取它之前，按照语言规定的分析规则能够确定它已经被赋值。这项检查叫作**确定赋值**。

我们即使保证自己每次启动都会传参数，编译器也不会采用这份口头约定；源码中仍然存在不经过赋值就到达读取位置的分支。

在 `lab/04-flow/fixed`，补上另一条分支：

```java
public class Main {
    public static void main(String[] args) {
        String message;
        if (args.length > 0) {
            message = args[0];
        } else {
            message = "Hello, compiler!";
        }
        System.out.println(message);
    }
}
```

```bash
javac -d out Main.java
java -cp out Main Alice
java -cp out Main
```

两次分别输出 `Alice` 和 `Hello, compiler!`。这次不是因为编译器提前试跑了两次，而是两个分支都明确进行了赋值。

> 实操截图待补：遗漏 `else` 时的确定赋值错误，以及两个分支补齐后的两次运行。

## “必须处理 IOException”，不代表编译时读了文件

我们再换一种消息来源：从文件读取。程序放在 `lab/05-checked/broken`：

```java
import java.nio.file.Files;
import java.nio.file.Path;

public class Main {
    public static void main(String[] args) {
        String message = Files.readString(Path.of("message.txt"));
        System.out.println(message);
    }
}
```

```bash
javac -d out Main.java
```

关键诊断变成：

```text
error: unreported exception IOException; must be caught or declared to be thrown
```

这句话很容易让我们以为编译器已经尝试读取文件，发现出了问题。实际上，编译器看的是 `Files.readString` 的方法声明。这个方法声明了可能抛出 `IOException`，调用方需要遵守 Java 对这类异常的检查规则。

`IOException` 属于**受检异常**：在这里，我们必须用 `try/catch` 处理它，或者在当前方法的 `throws` 中声明它可以继续向外传播。不是每种异常都有这项强制要求，例如后面会遇到的数组越界异常就没有。

本实验选择后一种，让文件读取失败时的异常直接暴露出来。在 `lab/05-checked/fixed`，完整代码是：

```java
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;

public class Main {
    public static void main(String[] args) throws IOException {
        String message = Files.readString(Path.of("message.txt"));
        System.out.println(message);
    }
}
```

```bash
javac -d out Main.java
```

这次可以编译。注意，`throws IOException` 没有修复任何文件，也没有读取文件，更没有保证读取成功；它明确了这个方法不在本地处理该异常。

运行阶段才真的需要 `message.txt`。实验目录中的 `with-file` 已经准备好这个文件，内容是 `Hello, file!`；`fixed` 中没有该文件。接着上面的编译，从 `fixed` 切换到 `with-file` 启动：

```bash
cd ../with-file
java -cp ../fixed/out Main
```

这次输出 `Hello, file!`。随后回到没有消息文件的目录，不重新编译：

```bash
cd ../fixed
java -cp out Main
```

同一份 `Main.class` 会报告 `java.nio.file.NoSuchFileException: message.txt`。`NoSuchFileException` 是 `IOException` 的一种，属于这份声明覆盖的失败情况。

这里的 `message.txt` 按进程的工作目录定位，不是从 classpath 查找。`-cp` 告诉 JVM 类在哪里，不会改变 `Files.readString` 读取相对路径文件的起点。

> 实操截图待补：未声明异常时编译失败；添加 `throws` 后编译成功；同一份 class 在有、无消息文件时出现不同运行结果。

**编译器检查的是异常处理责任有没有交代，运行时才会发生具体的文件访问。** 把受检异常叫作“编译时抛出的异常”，会把这两个阶段混在一起。

## 编译成功的边界：声明允许，不等于输入有效

看到前面的分支检查，我们可能会期待编译器顺手检查所有危险操作。下面这个版本直接使用第一个启动参数，位于 `lab/06-runtime/valid`：

```java
public class Main {
    public static void main(String[] args) {
        String message = args[0];
        System.out.println(message);
    }
}
```

```bash
javac -d out Main.java
java -cp out Main Alice
```

编译通过，运行输出 `Alice`。再启动一次，这次不传参数：

```bash
java -cp out Main
```

会出现：

```text
java.lang.ArrayIndexOutOfBoundsException: Index 0 out of bounds for length 0
```

编译器能够确认 `args` 是 `String[]`，下标 `0` 是整数，读取元素的结果可以赋给 `String`。但这次执行的数组是否包含第一个元素，是运行时要检查的条件。

这与刚才的确定赋值并不矛盾：变量在使用前有没有按规则完成赋值，是 Java 要求编译器检查的事；每次访问数组时下标有没有越界，是运行时的检查。**编译成功表示通过了相应的编译检查，不是对所有输入和执行环境的正确性证明。**

这个例子的修法也就在前面的确定赋值实验里：先检查 `args.length`，再决定读取第一个元素还是使用默认消息。给代码加上不必要的强制转换、换一个 classpath，都不能解决实际缺少参数的问题。

> 实操截图待补：同一份编译产物，有参数时成功，无参数时数组越界。

## 把诊断还原成编译器的问题

我们可以把本篇的检查组织成一个阅读模型。它描述的是理解这些实验所需的关系，不要求每条诊断严格按下面的顺序出现：

```text
源码
 │
 ├── 结构能否识别？                 缺分号
 ├── 名称能否对应到声明？           message 没有声明
 ├── 这组类型能否这样使用？         int 赋给 String
 ├── 局部变量在读取前是否确定赋值？ 某个分支没有赋值
 └── 受检异常是否捕获或声明？       IOException 没有交代
 │
 ▼
class 文件 → java 启动 → 用实际参数和环境执行
```

回到日常开发，下次遇到红线，可以先回答两个问题：**这是编译器在拒绝哪一条规则，还是已经开始执行后出现的失败？诊断指向的是结构、名称、类型、控制流，还是异常声明？**

第一篇解决了类从哪里来，这一篇补上了编译器凭什么接受这些类的用法。带着这两个问题，我们可以继续追问：生成的 class 文件里，究竟保留了哪些声明和操作。

## 参考资料

- [JDK 21：javac 与声明查找](https://docs.oracle.com/en/java/javase/21/docs/specs/man/javac.html)
- [JLS 21 §14.4：局部变量声明](https://docs.oracle.com/javase/specs/jls/se21/html/jls-14.html#jls-14.4)
- [JLS 21 §6.5.6.1：简单表达式名称](https://docs.oracle.com/javase/specs/jls/se21/html/jls-6.html#jls-6.5.6.1)
- [JLS 21 §5.2：赋值上下文](https://docs.oracle.com/javase/specs/jls/se21/html/jls-5.html#jls-5.2)
- [JLS 21 §15.12.2：编译时确定可调用的方法](https://docs.oracle.com/javase/specs/jls/se21/html/jls-15.html#jls-15.12.2)
- [JLS 21 第 16 章：确定赋值](https://docs.oracle.com/javase/specs/jls/se21/html/jls-16.html)
- [JLS 21 §11.2：编译时异常检查](https://docs.oracle.com/javase/specs/jls/se21/html/jls-11.html#jls-11.2)
- [JDK 21：Files.readString](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/file/Files.html#readString(java.nio.file.Path))
- [JLS 21 §15.10.4：数组访问的运行时求值](https://docs.oracle.com/javase/specs/jls/se21/html/jls-15.html#jls-15.10.4)
