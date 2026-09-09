# Java Deep Dive Labs

面向 Java 技术文章的可复现实验仓库。每个章节同时收纳正文和实验，其中 `lab/` 是独立 Maven 工程，可以单独选择 JDK、依赖和插件，避免章节之间互相污染。

## 仓库结构

```text
.
├── outline.md                 # 总提纲与章节索引
├── chapters/
│   ├── 01-project-baseline/
│   │   ├── article/           # 本章正文与图片
│   │   └── lab/               # 本章独立实验工程
│   └── _template/
│       ├── article/           # 新章节正文模板
│       └── lab/               # 新章节实验模板
└── scripts/
    └── verify-all.sh          # 逐章验证，不建立跨章依赖
```

## 开始使用

验证全部已启用章节：

```bash
./scripts/verify-all.sh
```

只运行某一章：

```bash
cd chapters/01-project-baseline/lab
./mvnw test
```

## 新增章节

1. 复制 `chapters/_template`，并以 `NN-topic-name` 命名。
2. 在新章节的 `article/` 中撰写正文并保存图片。
3. 在同章的 `lab/` 中实现实验源码和测试。
4. 修改 `outline.md` 中的章节链接与状态。

## 隔离约定

- 根目录不设置聚合构建，章节之间不能声明源码或模块依赖。
- 每章的 `lab/` 保留自己的 `pom.xml`、Maven Wrapper 和 `.java-version`。
- 章节产生的 `target/`、IDE 配置和本机环境文件不进入 Git。
- 如某章需要数据库或中间件，可在该章的 `lab/` 中增加专属 `compose.yaml` 和 `.env.example`。
