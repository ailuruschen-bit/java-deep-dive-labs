# 第一篇扩展与读者视角优化记录

本文是编辑过程记录，不属于待发布正文。真实终端操作及截图由作者完成；这里记录的隔离验证不冒充实操素材。

## 阶段性提交状态

- 第一篇新增正文已形成初稿，尚未达到发布状态。
- 已完成并落实修改的读者视角优化为 2 轮，目标至少 11 轮，尚余至少 9 轮。
- 新增实验的目录、版本与命令方案已研究；`jar-classpath` 和 `maven-boot-classpath` 的文件尚未落盘，也尚未完成构建验证。正文中对这两个项目的描述目前属于预定实验设计，不能视为已有可运行环境。
- 现有六张真实截图保留；新增四处实操截图待补。
- 第二篇编译器主题尚未正式选题或撰写初稿。
- 后续阅读已发现但尚未落实：补充目录与 JAR 条目可以混合；明确首次展示 `java -jar app.jar` 时普通应用 JAR 还未写入启动入口。这次检查不计为已完成的优化轮次。
- 下一步：先落实并验证新增实验，再继续第一篇逐轮修改；完成第一篇后才进入第二篇。

## 本轮范围

- 起点：已推送的 `46b5be0`，保留现有六张真实截图。
- 增补：普通 JAR 的打包与查找、Maven 项目的编译产物和依赖位置、Spring Boot 可执行 JAR 中应用与依赖的位置。
- 不增补：Maven 完整生命周期教程、Spring 容器原理、自动配置、加载器层次或源码分析。
- 核心问题不变：类名已经确定后，编译器和运行环境从哪里找到所需的类。
- 新实验必须与 `step-1`、`step-2`、`deployment` 隔离，不改变现有录制状态。
- 中文版代码注释用中文。正式正文不插入要求读者跳转阅读的资料链接，核验资料集中在文末及本文档。

## 计划中的独立阅读轮次

每轮在读完整个相关段落后再修改，并记录实际发现与处理；不把一次检查拆成多轮计数。

1. 读者是否清楚本文新增内容仍在回答同一个问题。
2. 读者是否知道 JAR 是已有文件的归档，而不是另一种编译结果。
3. 读者能否独立推导 `-C`、包内路径与目录前缀的关系。
4. 读者能否区分目录条目、JAR 条目以及编译和运行各自的配置。
5. 读者能否解释 `java -cp` 与 `java -jar` 的入口及依赖来源。
6. 读者是否会把 Maven 的依赖声明误认为 JVM 直接读取的配置。
7. 读者是否清楚普通 Maven JAR 与 Boot 重打包产物的差别。
8. 读者能否用包结构和清单解释 Boot 启动，而不必先学习框架内部机制。
9. 读者照着实验目录和命令能否得到文中的现象，哪些位置需要真实截图。
10. 读者是否会因重复解释、术语前置或版本细节失去阅读节奏。
11. 从第一段到开放式结尾完整阅读，检查承诺、结论及前后模型是否一致。

## 核验依据

- [JDK 21：jar 命令](https://docs.oracle.com/en/java/javase/21/docs/specs/man/jar.html)：归档、目录切换、列举条目、清单。
- [JDK 21：JAR 文件规范](https://docs.oracle.com/en/java/javase/21/docs/specs/jar/jar.html)：包内路径、`Main-Class`、`Class-Path` 的含义。
- [JDK 21：java 命令](https://docs.oracle.com/en/java/javase/21/docs/specs/man/java.html)：`-cp` 与 `-jar` 的启动方式。
- [Maven：标准目录布局](https://maven.apache.org/guides/introduction/introduction-to-the-standard-directory-layout.html)：源码与构建产物的约定。
- [Maven：依赖机制](https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html)：依赖声明及不同阶段的可见性。
- [Spring Boot：嵌套 JAR 格式](https://docs.spring.io/spring-boot/specification/executable-jar/nested-jars.html)：`BOOT-INF/classes` 和 `BOOT-INF/lib`。
- [Spring Boot：启动可执行 JAR](https://docs.spring.io/spring-boot/specification/executable-jar/launching.html)：入口清单及启动器的职责。

## 已完成轮次

### 第 1 轮：同一个问题能否贯穿工具变化

- 阅读范围：从开头承诺到 JAR、Maven、Boot 与 IDE 开放结尾，完整检查扩展后的主线。
- 发现：手工依赖 JAR 到 Maven 依赖之间缺少一环；读者可能以为 Maven 会自动发现项目旁边的 JAR。
- 修改：在 Maven 命令之前说明实验专用本地依赖仓库，并展示 `greeting` 的实际依赖声明，区分依赖标识与 Java 包名。
- 结论：JAR 负责文件组织，Maven 负责依赖信息与构建，Boot 负责其可执行包启动安排，仍然共同回答“类从哪里找到”。新实验的可执行验证另行进行，不把文稿审阅当作运行验证。

### 第 2 轮：读者会不会把打包理解成另一轮编译

- 阅读范围：字节码解释、目录实验收束以及普通 JAR 一节。
- 发现：“移进归档”可能被理解为打包后原 class 消失；“原来的包内路径”在还没有 JAR 时也不够准确。
- 修改：明确编译改变代码表示、打包改变文件组织，原文件仍保留；路径改为“相对于 lib001 的路径”，再说明其作为归档条目保存。
- 结论：读者只需要沿用已有 class 文件的认识，不必再建立一种“JAR 字节码”模型。
