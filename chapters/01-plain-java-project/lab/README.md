# 纯 Java 运行实验

本实验只使用 JDK 21 自带的工具，不依赖 IDE、Maven 或 Gradle。

```bash
./run-experiments.sh
```

实验按文章顺序覆盖：

1. `javac` 默认在源文件旁生成 `Main.class`。
2. 使用 `javap` 观察字节码。
3. 使用 `javac -d` 指定输出目录。
4. 从当前工作目录启动具有多层包名的类。
5. 将自己的代码和依赖编译到三个独立的 classpath 根。
6. 分别使用 `-cp` 和 `CLASSPATH` 启动程序。
7. 演示漏掉依赖目录时的加载失败。
8. 简单验证 Java 21 的单文件源码启动方式。

Java 源码中不包含非英文注释。
