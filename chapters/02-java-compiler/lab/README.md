# 第二篇实验：编译器检查什么，运行时又检查什么

使用 JDK 21，不需要 Maven 或第三方依赖。每个例子都是默认包中的独立 `Main`，不要把不同例子的源码一起编译。源码不需要互相覆盖：`broken` 保留失败版本，`fixed` 保留修复版本；最后一例只有可正常编译的 `valid` 版本。

所有手动编译都使用 `-d out`，不会把 class 文件写到源码旁边。`out` 已被本章的 `.gitignore` 忽略。真实截图由作者实操提供，验证脚本不生成或改写截图。

## 开始之前

从仓库根目录进入本章实验目录：

```bash
cd chapters/02-java-compiler/lab
java -version
javac -version
```

两者都应显示版本 21。如需在 macOS 的当前终端切换，可以执行：

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
export PATH="$JAVA_HOME/bin:$PATH"
```

为了避免已有环境变量改变实验结果，并固定截图中的诊断语言，可在当前终端执行一次：

```bash
unset CLASSPATH JAVA_TOOL_OPTIONS _JAVA_OPTIONS JDK_JAVA_OPTIONS JDK_JAVAC_OPTIONS
alias javac='javac -J-Duser.language=en -J-Duser.country=US'
alias java='java -Duser.language=en -Duser.country=US'
```

这只影响当前 shell，不会改写全局配置。关闭窗口即可结束这次设置；上述别名只补充诊断语言，不改变源码和类路径。每组说明都从 `lab` 开始，最后返回 `lab`。如果中途停下，请先确认 `pwd`，不要直接接着另一组的相对路径执行。

编译失败后不要继续运行旧的 `out/Main.class`：失败不等于清除了上次编译产物。本仓库的失败版本和修复版本分开存放，便于避免混用。下面没有删除命令，不会清理你已有的截图现场。

## 01：缺少分号，语法检查失败

工作目录：先 `01-syntax/broken`，再 `01-syntax/fixed`。

```bash
cd 01-syntax/broken
cat Main.java
javac -d out Main.java
cd ../fixed
cat Main.java
javac -d out Main.java
java -cp out Main
cd ../..
```

失败版本在 `String message = "Hello, compiler!"` 后缺少 `;`，关键诊断为 `';' expected`。补上分号后编译成功，运行输出 `Hello, compiler!`。

## 02：名字没有对应的声明

工作目录：先 `02-name/broken`，再 `02-name/fixed`。

```bash
cd 02-name/broken
cat Main.java
javac -d out Main.java
cd ../fixed
cat Main.java
javac -d out Main.java
java -cp out Main
cd ../..
```

失败版本直接使用尚未声明的 `message`，诊断包含 `cannot find symbol` 和 `variable message`。修复版本先声明并赋值，再输出 `Hello, compiler!`。

## 03：名字找到了，类型仍不匹配

工作目录：先 `03-type/broken`，再 `03-type/fixed`。

```bash
cd 03-type/broken
cat Main.java
javac -d out Main.java
cd ../fixed
cat Main.java
javac -d out Main.java
java -cp out Main
cd ../..
```

失败版本使用 `String message = 42;`，关键诊断为 `incompatible types: int cannot be converted to String`。修复版本改成字符串字面量 `"42"`，编译后运行输出 `42`。

## 04：有声明，不等于使用前一定赋过值

工作目录：先 `04-flow/broken`，再 `04-flow/fixed`。

```bash
cd 04-flow/broken
cat Main.java
javac -d out Main.java
cd ../fixed
cat Main.java
javac -d out Main.java
java -cp out Main
java -cp out Main Alice
cd ../..
```

失败版本只在 `args.length > 0` 分支中给 `message` 赋值，关键诊断为 `variable message might not have been initialized`。修复版本增加 `else`，保证两条路径都会赋值。无参数时输出 `Hello, compiler!`，有参数时输出 `Alice`。

## 05：声明异常后能编译，不代表文件一定存在

源码固定读取相对于工作目录的 `message.txt`。仓库在 `05-checked/with-file` 中提供了这个文件，内容为 `Hello, file!`。

先比较失败与修复版本：工作目录从 `05-checked/broken` 切换到 `05-checked/fixed`。

```bash
cd 05-checked/broken
cat Main.java
javac -d out Main.java
cd ../fixed
cat Main.java
javac -d out Main.java
```

失败版本没有处理或声明 `Files.readString` 可能抛出的 `IOException`，关键诊断为 `unreported exception IOException; must be caught or declared to be thrown`。修复版本导入 `IOException`，并在 `main` 上添加 `throws IOException`。编译成功并不说明任何实际读取已经发生。

接着使用同一份编译结果运行两次，不重新编译，也不删除任何文件：

```bash
cd ../with-file
pwd
cat message.txt
java -cp ../fixed/out Main
cd ../fixed
pwd
java -cp out Main
cd ../..
```

第一次的工作目录是 `with-file`，能够读取 `message.txt`，输出 `Hello, file!`。文件末尾的换行加上 `println` 的换行，还会留下一个空行。第二次的工作目录是 `fixed`；默认布局下这里没有 `message.txt`，因此出现 `java.nio.file.NoSuchFileException: message.txt`。

两次启动的 classpath 都正确指向同一份 `Main.class`。变化的是读取数据文件时的工作目录，不是类加载失败。`throws IOException` 允许异常继续向调用者传播，并没有替我们创建文件或解决读取失败。

为了复现实验，请不要向 `05-checked/fixed` 复制 `message.txt`。如果你已经自行调整过实验目录，可以使用下面的验证脚本，在独立临时目录检查预期行为，不必清理现场。

## 06：编译成功，仍可能发生运行时异常

工作目录：`06-runtime/valid`。

```bash
cd 06-runtime/valid
cat Main.java
javac -d out Main.java
java -cp out Main Alice
java -cp out Main
cd ../..
```

这份源码本身可以编译。给出一个参数时，`args[0]` 有对应元素，输出 `Alice`；不给参数时，数组长度为零，出现 `java.lang.ArrayIndexOutOfBoundsException`。

这里不存在需要先修复的编译错误，所以目录名为 `valid`，不是 `fixed`。实验要比较的是同一份字节码在不同运行输入下的结果。

## 独立验证全部案例

在 `lab` 目录执行：

```bash
bash verify.sh
```

脚本会检查 `java` 和 `javac` 都属于 JDK 21，清除本次子进程中的 Java 参数及类路径注入变量，并将诊断语言固定为英文。它在新建的临时目录中编译和运行，验证以下结果：

- 五个失败版本均以非零状态退出，关键诊断匹配，而且本次干净输出目录中没有生成 `Main.class`。这是对这五个单文件案例的断言，不代表所有编译失败都不会生成任何 class 文件。
- 五个修复版本和一个运行时例子都能编译。
- 修复后的正常运行、确定赋值的两条分支、读文件成功与失败、数组访问成功与失败均符合预期。

全部通过时输出 `SUMMARY: 20 项检查全部通过（JDK 21）。`。脚本保留本轮独立的 class 文件与诊断日志，并打印临时目录的具体位置，方便核对；不删除、覆盖或复用实操目录中的 `out`。
