# Plain Java project lab

This lab uses only the tools provided by JDK 21. It does not use an IDE, Maven, or Gradle.

Inspect the active Java environment:

```bash
./inspect-environment.sh
```

Compile all source sets and run the class path experiments:

```bash
./run-experiments.sh
```

The experiment covers:

- compilation from `.java` source files to `.class` files;
- the Java 21 single-file source-code mode;
- bytecode inspection with `javap`;
- the default class path;
- multiple class path roots;
- a missing main class;
- a missing dependency;
- a small custom `ClassLoader` that maps binary names to class files.

The scripts deliberately do not install or select a JDK. They use the Java environment resolved by the current shell.
