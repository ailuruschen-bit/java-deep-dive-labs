# 第一篇中日英终稿审校记录

审校日期：2026-09-15。此文件记录编辑与验证过程，不属于文章正文。

## 范围与分工

- 中文：主编辑完整审读，独立技术审稿人复核模型、实验对应关系和参考依据。
- 日文、英文：分别由独立写作者按母语技术文章习惯撰写，再进行交叉审读与独立读者试阅。
- 保留作者的 11 张真实终端截图，不重绘、不更改截图中的命令或输出。
- Maven 与 Spring Boot 保持概念讲解，不恢复已取消的实验；不展开依赖树、插件机制、测试执行或真实类加载器源码。

## 已发现并修正的问题

| 问题 | 修正及依据 |
| --- | --- |
| 正文没有明确实验使用的 JDK 和终端语法范围 | 开头注明 JDK 21、macOS/Linux 命令；Windows classpath 分隔符说明保留在首次多条目命令处 |
| “JVM 不直接理解源码”容易与 `java Main.java` 的体验冲突 | 增加一条短注：源码文件启动仍由启动器在内存中先编译再执行，不改变本文分开观察编译与启动的主线；依据 JDK 21 `java` 手册 |
| “显式 classpath 只使用列出的条目”容易被泛化到带清单的 JAR | 将该句限定为当前目录实验；后文清单依赖仍按 JAR 规范解释 |
| 二进制名称的说明缺少最直接的语言规范引用 | 文末补充 JLS 21 §13.1，与普通顶层类场景对应 |
| IDE 组织 classpath 的说明缺少直接参考 | 补充 IntelliJ IDEA 官方模块依赖文档，支持从项目依赖生成编译与运行 classpath 的说明 |
| Boot 启动器的完整包名并非所有历史版本相同 | 清单示例轻量限定为 Spring Boot 3.5 默认可执行 JAR，不展开版本差异 |
| Boot “纳入查找范围”容易被读成只是生成普通 `-cp` | 首次阅读者复核后补清：启动器建立能读取应用目录与嵌套 JAR 的类加载器，普通 JAR 查找不会自动深入嵌套 JAR；沿用前文已有类加载器概念 |
| JAR 实验 README 仍保留无法显示百分号的提示符写法 | 改为 `PROMPT='%1~ %% '`；去掉“当前电脑已准备好”这种不适合仓库读者的时效性描述 |
| 原有验证脚本的运行时 wrong-name 检查不能替代正文 bad-import 编译错误 | 在隔离副本中实际修改 import 并编译，核实两个外部类均报告 `class file contains wrong class`；未动作者录制目录 |

## 命令与产物验证

使用已安装的 JDK 21.0.11，在仓库外的临时副本中验证：

- 原有 `lab/run-experiments.sh` 全部通过：源码旁输出、`-d` 输出、带包名启动、错误工作目录、`-cp` 修复、缺少编译依赖、反序列出两份源码、完整运行 classpath、运行时类名不匹配、遗漏运行依赖。
- 正文的 bad-import 补充检查：`lib001`、`lib002` 前缀能够对应物理文件，但编译器拒绝与文件内部类名不一致的引用，结果符合文章。
- `lab/jar-classpath/run-experiments.sh --verify` 全部通过：依赖归档路径与自动清单、目录/JAR 混合启动、全 JAR 启动、没有入口属性时失败、补充清单后启动、实际清单字段、跨工作目录启动。
- 验证过程不产生新的文章截图，也不重置作者已完成的真实实操。

## 参考资料核验

原稿的 19 个参考链接均返回 HTTP 200；另补 JLS 二进制名称和 IDE classpath 的直接依据。技术审查不仅检查链接可达，也对照以下官方文档中的相关条款：

| 正文结论 | 主要依据 |
| --- | --- |
| `javac` 默认输出在源码旁；多份源码成组编译；编译 classpath | [JDK 21 javac 手册](https://docs.oracle.com/en/java/javase/21/docs/specs/man/javac.html) |
| 启动入口、默认 classpath、源码文件启动、`-jar` 行为 | [JDK 21 java 手册](https://docs.oracle.com/en/java/javase/21/docs/specs/man/java.html) |
| 顶层类的二进制名称、类定义与加载错误 | [JLS §13.1](https://docs.oracle.com/javase/specs/jls/se21/html/jls-13.html#jls-13.1)、[ClassLoader API](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/ClassLoader.html)、[JVMS §5.3.2](https://docs.oracle.com/javase/specs/jvms/se21/html/jvms-5.html#jvms-5.3.2) |
| 归档输入目录、自动清单、清单 Class-Path 的分隔与相对位置 | [jar 手册](https://docs.oracle.com/en/java/javase/21/docs/specs/man/jar.html)、[JAR 规范](https://docs.oracle.com/en/java/javase/21/docs/specs/jar/jar.html) |
| Maven 目录、依赖范围、编译及打包产物 | [标准目录布局](https://maven.apache.org/guides/introduction/introduction-to-the-standard-directory-layout.html)、[依赖机制](https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html)、[构建生命周期](https://maven.apache.org/guides/introduction/introduction-to-the-lifecycle.html) |
| 源码 JAR、普通 JAR、清单配置、依赖收集、发行包与合并打包 | 正文所列 Maven Source、JAR、Archiver、Dependency、Assembly、Shade 官方资料 |
| IDE 从依赖列表形成编译和运行 classpath | [IntelliJ IDEA 模块依赖](https://www.jetbrains.com/help/idea/working-with-module-dependencies.html) |
| Boot 归档布局、清单入口和启动器职责 | 正文所列 Spring Boot 3.5 嵌套 JAR、启动及打包规范 |

## 多语言审读与交付检查

撰写与交叉审核完成后，在此补记实际发现、修改和最终检查结果。
