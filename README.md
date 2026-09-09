# Java Deep Dive Labs

面向 Java 技术文章的可复现实验仓库。文章正文与实验代码使用相同的章节编号；每一章都是独立 Maven 工程，可以单独选择 JDK、依赖和插件，避免章节之间互相污染。

## 仓库结构

```text
.
├── article/                   # 文章正文、提纲与图片
│   ├── outline.md
│   └── chapters/
│       └── 01-project-baseline.md
├── chapters/                  # 可运行的章节实验
│   ├── 01-project-baseline/   # 独立 Maven 工程
│   └── _template/             # 新章节模板
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
cd chapters/01-project-baseline
./mvnw test
```

## 新增章节

1. 复制 `chapters/_template`，并以 `NN-topic-name` 命名。
2. 将实验源码、测试和本章说明放在新目录内。
3. 在 `article/chapters/` 新建同编号的 Markdown 正文。
4. 在 `article/outline.md` 中补充章节链接和实验链接。

## 隔离约定

- 根目录不设置聚合构建，章节之间不能声明源码或模块依赖。
- 每章保留自己的 `pom.xml`、Maven Wrapper 和 `.java-version`。
- 章节产生的 `target/`、IDE 配置和本机环境文件不进入 Git。
- 如某章需要数据库或中间件，可在该章目录内增加专属 `compose.yaml` 和 `.env.example`。
