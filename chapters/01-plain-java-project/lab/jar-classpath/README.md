# JAR 与 classpath：实操截图

本实验独立于前面的 `deployment`，使用 JDK 21，不需要 Maven。`provider-src` 保留依赖提供方源码；准备脚本只把它们编译为 `work/lib001` 和 `work/lib002` 下的两份 class，不提前执行文章中的打包与应用编译。

## 进入截图环境

下面的绝对路径对应当前电脑。先在终端进入独立的 zsh 子会话，选择 JDK 21；这些设置不会写入终端配置，完成后用 `exit` 返回。

```bash
zsh -f
export JAVA_HOME="$(/usr/libexec/java_home -v 21)"
export PATH="$JAVA_HOME/bin:$PATH"
unset CLASSPATH JAVA_TOOL_OPTIONS JDK_JAVA_OPTIONS JDK_JAVAC_OPTIONS _JAVA_OPTIONS
PROMPT='%1~ %% '
cd /Users/apple/Documents/java-deep-dive-labs/chapters/01-plain-java-project/lab/jar-classpath/work
clear
```

首次使用时，先从 `jar-classpath` 执行 `./run-experiments.sh --prepare`，再进入 `work`。准备脚本遇到已有实验产物会停止，不会清空或覆盖你的录制内容；如果已经完成准备，可以直接从下面第一组开始。

## 第一组：把目录中的依赖打成 JAR

全部命令在 `work` 中执行。`tree` 仅用于展示目录；如果没有安装，可以省略这一行。

```bash
tree --noreport
jar --create --file lib/greeting.jar -C lib001 .
jar --create --file lib/punctuation.jar -C lib002 .
jar --list --file lib/greeting.jar
```

观察包内从 `dev` 开始的类路径，以及自动生成的 `META-INF/MANIFEST.MF`。没有多出 `lib001` 这一层。

## 第二组：使用 JAR 编译和运行

```bash
javac -cp "lib/greeting.jar:lib/punctuation.jar" -d app-classes \
  src/dev/deepdive/app/Main.java \
  src/dev/deepdive/app/MessageService.java
java -cp "app-classes:lib/greeting.jar:lib/punctuation.jar" dev.deepdive.app.Main
jar --create --file app.jar -C app-classes .
java -cp "app.jar:lib/greeting.jar:lib/punctuation.jar" dev.deepdive.app.Main
```

两次启动都应输出 `Hello, classpath!`。第一次混用目录和 JAR 条目，第二次只把应用目录换成 `app.jar`。前两组对应文章中普通 JAR 部分的截图，可按终端高度分别录制。

## 第三组：清单启动

仓库已在 `work` 外准备好文章中的清单文本，到这一步再复制进来，不干扰最初的目录截图。

```bash
cp ../app-manifest.mf .
cat app-manifest.mf
jar --create --file app.jar \
  --manifest app-manifest.mf \
  -C app-classes .
java -jar app.jar
cd ..
java -jar work/app.jar
```

两次输出仍然是 `Hello, classpath!`。最后一次的工作目录已经不是 `work`，清单中的依赖路径仍相对于 `app.jar` 所在目录查找。

如需查看打包后的实际清单，可从当前 `jar-classpath` 目录执行以下只读命令（macOS 自带 `unzip`），不会解压文件到截图目录：

```bash
unzip -p work/app.jar META-INF/MANIFEST.MF
```

## 隔离验证

在 `jar-classpath` 中执行 `./run-experiments.sh --verify`。脚本在新的临时目录验证文章命令、包内路径、清单字段、未配置入口时的失败和切换工作目录后的启动，不改变录制用的 `work`。临时目录会保留，具体路径由脚本输出。这是命令验证，不代替作者的真实实操截图。
