# How Java Starts: Compilation, Class Loading, and the Classpath

Strip a Java project down to one `Main.java` and a JDK. No Eclipse or IntelliJ IDEA, no Maven, no Spring: just `javac` to compile and `java` to run.

That gives us a direct view of the connection between our code and the files on disk. How does source code become a class file? How does a class name identify that file? And how do the compilation and runtime classpaths determine where to look for the classes we need?

Once that connection is clear, we can package the files into JARs and recognize the same arrangement in Maven and Spring Boot projects.

The examples use JDK 21 and macOS/Linux command syntax, with the `CLASSPATH` environment variable unset. Each example includes its source or dependency description, file layout, working directory, commands, and results. The text and screenshots tell the full story; no download or hands-on setup is needed to follow it.

## Start with the JDK tools

Both `javac` and `java` come with the JDK. We will use `javac` to compile `.java` source files into `.class` files, then use `java` to start a JVM that loads and executes the result:

```text
Java source (.java)
        │
        │ javac
        ▼
Java bytecode (.class)
        │
        │ java
        ▼
Loaded and executed by the JVM
```

## Compile a class file with javac

Start with a `Main.java` that has no package declaration—just the familiar `main` method and a line of output:

```java
public class Main {
    public static void main(String[] args) {
        System.out.println("Hello, Java!");
    }
}
```

There is only one file in the directory:

```text
step-1/
└── Main.java
```

With `step-1` as the working directory, the compilation command is:

```bash
javac Main.java
```

A successful compilation adds `Main.class`:

```text
step-1/
├── Main.class
└── Main.java
```

By default, `javac` writes each generated class file beside its source file. To keep the output in a separate directory, use `-d`. Still in `step-1`, run:

```bash
javac -d out Main.java
```

This produces `out/Main.class`. It does not remove the `Main.class` from our first compilation:

```text
step-1/
├── Main.class
├── Main.java
└── out/
    └── Main.class
```

### Bytecode is code for the JVM

`Main.class` is not the source file with a different extension. The compiler has translated Java source into an intermediate representation for the JVM: bytecode.

The source uses Java syntax that we can read and edit. The class file contains instructions and data in a format the JVM understands. It is no longer ordinary readable text, but it is not native machine code for the CPU either.

That is the boundary compilation establishes here: **the JVM does not execute Java source directly; it works with compiled data in the class-file format.**

> JDK 21 also supports launching a single source file with a command such as `java Main.java`. In that case, the launcher compiles the source in memory before running it. Here, we keep compilation and execution separate so that we can inspect the class files ourselves.

The screenshot shows both compilations. `tree --noreport` makes the changes to the directory visible:

![Compiling Main.java beside its source, then using javac -d out to write a second class file under out](https://raw.githubusercontent.com/ailuruschen-bit/java-deep-dive-labs/main/chapters/01-plain-java-project/article/assets/experiment-01-compilation.png)

## Run Main from the current directory

With the class file in place and `step-1` still the working directory, the launch command is:

```bash
java Main
```

The output is:

```text
Hello, Java!
```

We have completed a minimal compile-and-run cycle. There is more to compilation than changing the representation of the code, though. `javac` uses class and method declarations to check whether our references and method calls are valid. At runtime, the JVM needs the actual bytecode of the classes involved in execution. Both stages need to find classes, but for different reasons.

There is another detail worth noticing: we created `Main.class`, but passed `Main` to `java`—a class name, not a filename.

Why a class name instead of a file path? Keep that distinction in mind. It becomes clearer once we add a package.

## Add a package and run it again

The next example uses a separate `step-2` directory, with `Main.java` placed in directories matching its package, as in a regular project. The only code change is the package declaration:

```java
package dev.deepdive.app;

public class Main {
    public static void main(String[] args) {
        System.out.println("Hello, Java!");
    }
}
```

The source sits inside the innermost `app` directory:

```text
step-2/
└── out/
    └── dev/
        └── deepdive/
            └── app/
                └── Main.java
```

This compilation runs with `step-2/out` as the working directory:

```bash
javac dev/deepdive/app/Main.java
```

We did not use `-d`, so the class file is again written beside the source:

```text
out/  ← working directory
└── dev/
    └── deepdive/
        └── app/
            ├── Main.java
            └── Main.class
```

Stay in `out` and launch the program:

```bash
java dev.deepdive.app.Main
```

It still prints `Hello, Java!`. Compare the two commands: `javac` received the source path `dev/deepdive/app/Main.java`; `java` received the fully qualified class name `dev.deepdive.app.Main`.

For an ordinary top-level class like this one, that package-qualified name is called its **binary name**. In a directory containing class files, the dots map to directory separators, and the final `Main` maps to `Main.class`:

```text
dev.deepdive.app.Main
          │
          ▼
dev/deepdive/app/Main.class
```

Here is the complete sequence, from running `java Main` in `step-1` to compiling and running the packaged class in `step-2/out`:

![Running java Main, then compiling and running dev.deepdive.app.Main from step-2/out](https://raw.githubusercontent.com/ailuruschen-bit/java-deep-dive-labs/main/chapters/01-plain-java-project/article/assets/experiment-02-class-name.png)

The resulting `dev/deepdive/app/Main.class` looks like a relative path. A relative path still needs one more piece of information: where do we start looking?

## The classpath supplies the search locations

So far, all our application classes are ordinary class files in directories. To find a file from its class name, we need to know which directories to search. Those locations are specified by the **classpath**. **One classpath can contain multiple entries; in our current examples, each entry is a directory from which class-file lookup starts.**

The classpath is not just a runtime setting. The compiler needs dependency declarations, and the runtime needs bytecode. They use separate classpath configurations: `javac -cp` sets the locations for compilation; `java -cp` sets them for execution.

Let us follow the `java` command first and see how those locations are used at runtime.

### From java to the class loader

The `java` command starts the JVM. As we explore Java internals, we will repeatedly encounter the word *runtime*: the mechanisms that support a program while it executes. The JVM is at the core of the Java runtime, and class loading is one of those mechanisms.

The `dev.deepdive.app.Main` after the command identifies our entry class. Before its entry method can run, the runtime needs to locate its bytecode, load it into memory, and establish the corresponding class in the JVM. The component responsible for this is a **class loader**.

For the particular case we are studying—finding application classes in ordinary directories—we can model lookup and loading with this pseudocode:

```text
relativePath = className.replace(".", "/") + ".class"

for each entry in classpath:  // Why multiple entries? The next example will show us.
    classFile = joinPath(entry, relativePath)
    if classFile exists:
        bytes = read(classFile)
        return defineClass(className, bytes)

throw ClassNotFoundException
```

The class name becomes a relative path, which is joined to each directory entry in the classpath. Once a file is found, its bytes are read. `defineClass` checks that the requested name matches the name recorded inside the file and uses the JVM's facilities to define the runtime `Class` object. After the preparations required for startup, the runtime calls `Main.main` and enters our code.

The arguments now have distinct jobs: the class name identifies what we want to run, the classpath says where to look, and the class loader connects them to the file on disk.

### Make the search location explicit with java -cp

In the last example, we were in `step-2/out` and ran:

```bash
java dev.deepdive.app.Main
```

We have not configured a classpath for this example, so it defaults to a single entry, `.`, meaning the current working directory. Lookup starts at `out` and follows the path derived from the class name:

```text
step-2/
└── out/                  ← search starts in the working directory
    └── dev/
        └── deepdive/
            └── app/
                ├── Main.java
                └── Main.class  ← found
```

Leave the class name and files unchanged, but move up to `step-2` and repeat the launch command:

```bash
cd ..
java dev.deepdive.app.Main
```

Neither the code nor the command changed. The default search location did. Expand `.` to the working directory in each case, and the difference is visible:

| Working directory | Default classpath entry | Path searched, shown from `step-2` | Result |
| --- | --- | --- | --- |
| `step-2/out` | `.` | `step-2/out/dev/deepdive/app/Main.class` | File exists |
| `step-2` | `.` | `step-2/dev/deepdive/app/Main.class` | File does not exist |

Both commands use `.` as their default classpath, but `.` refers to the working directory at the time of execution. The file has not moved, so the second launch reports:

```text
Error: Could not find or load main class dev.deepdive.app.Main
Caused by: java.lang.ClassNotFoundException: dev.deepdive.app.Main
```

We do not have to change back to `out`. From `step-2`, use `-cp` to specify it as the search location:

```bash
java -cp out dev.deepdive.app.Main
```

The program runs again. `-cp out` sets this launch's classpath to a single entry, `out`. That relative path is resolved against our working directory, `step-2`, so lookup starts at `step-2/out` once more.

**The working directory determines how relative classpath entries are resolved. The directory entries in the classpath determine where class lookup starts.** Entries can use either relative or absolute paths.

The screenshot captures the failure after changing directories and the successful launch after adding `-cp out`:

![The main class cannot be found from step-2 until java -cp out supplies the correct search location](https://raw.githubusercontent.com/ailuruschen-bit/java-deep-dive-labs/main/chapters/01-plain-java-project/article/assets/experiment-03-classpath-root.png)

## One classpath, multiple entries

Now return to the comment in our pseudocode: why a `for` loop? The previous classpath had just one entry, `out`, but it can contain several, which are searched in order.

Suppose we receive two compiled classes, `Greeting.class` and `Punctuation.class`, from another developer. To manage them separately from our own code, we put them in `lib001` and `lib002`.

We also split our own code into two source files. `Main.java` is the entry point; `MessageService.java`, in the same package, assembles the message. All the following commands run from `deployment`:

```text
deployment/  ← working directory
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

Here is `Main.java`:

```java
package dev.deepdive.app;

public class Main {
    public static void main(String[] args) {
        System.out.println(MessageService.messageFor("classpath"));
    }
}
```

And here is `MessageService.java`:

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

The dependency provider has already defined their APIs: `Greeting.forName("classpath")` returns `Hello, classpath`, and `Punctuation.mark()` returns `!`. Our `MessageService` combines the results:

```text
Main
└── MessageService
    ├── Greeting
    └── Punctuation
```

### The compiler needs to find dependencies too

`javac` is not simply a source-to-bytecode translator. It also checks syntax and verifies that the types and dependency references in the source are valid.

Consider `Greeting.forName(name)`. The compiler must first find the declaration of `Greeting`. It can then check whether an accessible `forName` method exists, whether it accepts the supplied argument, and whether its return type works in the surrounding expression. The same applies to `Punctuation.mark()`.

For our two application classes, the declarations are available in the source files we pass to `javac`. We have no source for the external classes, so the compiler needs the type information in `Greeting.class` and `Punctuation.class`. **Reading those declarations does not execute `Greeting.forName` or `Punctuation.mark`.**

The first compilation runs from `deployment`, passing both source files to `javac` without explicitly configuring the compilation classpath:

```bash
javac \
  dev/deepdive/app/Main.java \
  dev/deepdive/app/MessageService.java
```

Compilation fails. The key messages are:

```text
package dev.deepdive.greeting does not exist
package dev.deepdive.punctuation does not exist
```

We supplied `Main.java` and `MessageService.java` explicitly. What is missing is the location of the external classes. Starting from the current directory, the compiler cannot find `dev/deepdive/greeting/Greeting.class` or `dev/deepdive/punctuation/Punctuation.class`: those paths actually start inside `lib001` and `lib002`.

Both files are present on disk, but the compiler has not been told where to begin looking for them:

![Compilation fails with missing-package errors even though Greeting.class and Punctuation.class are present under lib001 and lib002](https://raw.githubusercontent.com/ailuruschen-bit/java-deep-dive-labs/main/chapters/01-plain-java-project/article/assets/experiment-04-compile-classpath-missing.png)

### Supply those locations with javac -cp

Add the two directory entries to the compilation classpath and try again. On macOS and Linux, entries are separated by `:`. Windows uses `;`, so the corresponding value there would be `"lib001;lib002"`.

```bash
javac -cp "lib001:lib002" \
  dev/deepdive/app/Main.java \
  dev/deepdive/app/MessageService.java
```

The compiler can now read the dependency declarations and check our source. The two generated class files appear beside their source files:

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

Although `Main` calls `MessageService`, we do not need to compile `MessageService.java` first. **Source files explicitly supplied in a single `javac` invocation are compiled as a group; their order does not control how declarations between them are resolved.** Reversing the two filenames still works.

### Could we put lib001 in the import instead?

Looking at the directories, there is a tempting shortcut: skip `-cp` and change the imports in `MessageService` to match the storage paths:

```diff
-import dev.deepdive.greeting.Greeting;
-import dev.deepdive.punctuation.Punctuation;
+import lib001.dev.deepdive.greeting.Greeting;
+import lib002.dev.deepdive.punctuation.Punctuation;
```

Starting from `deployment`, those names appear to lead to the right files. But finding a file is only half the job.

The author of `Greeting` declared its package as `dev.deepdive.greeting`. Its class file already records the full name `dev.deepdive.greeting.Greeting`. Placing the file under `lib001` does not add `lib001` to that package, and changing an import in our own source does not rewrite the dependency's class file.

The mismatch looks like this:

```text
Class requested by the import
lib001.dev.deepdive.greeting.Greeting
                  │
                  ▼
File found, starting from deployment
lib001/dev/deepdive/greeting/Greeting.class
                  │
                  ▼
Class name recorded inside the file
dev.deepdive.greeting.Greeting
                  │
                  ▼
Names differ → compilation fails
```

The compiler rejects this with `class file contains wrong class`. It found a file, but that file does not define the class requested by the import. `Punctuation` has the same problem.

Keep the original imports and use `-cp "lib001:lib002"` to set the search locations. **The classpath says where to find a class; an import says which class the source refers to. Changing an import cannot rename an external class.**

### Configure the runtime classpath separately

The compilation `-cp` told `javac` where to read dependency declarations. Now that our bytecode exists, the runtime needs its own locations. **`java` does not inherit the setting from the earlier `javac -cp` command.**

Still in `deployment`, include both our class files and the external dependencies:

```bash
java -cp ".:lib001:lib002" dev.deepdive.app.Main
```

This is **one classpath with three entries**: `.`, `lib001`, and `lib002`.

### Why does the runtime classpath need the extra dot?

Our compilation classpath was `"lib001:lib002"`; the runtime classpath is `".:lib001:lib002"`. The added `.` makes the current `deployment` directory a search location. It does not change the working directory.

At compile time, we passed the file paths of `Main.java` and `MessageService.java` directly to `javac`. It did not need to find those two input files through the classpath. Only the external dependencies needed additional search locations. We could include `.`, but this compilation does not need it.

At runtime, we pass `java` only the entry class name, `dev.deepdive.app.Main`, not its file path. The class loader must locate `Main.class` and the `MessageService.class` it uses. Both are under `deployment/dev/deepdive/app/`, so lookup must start at `deployment`—that is, `.`.

**An explicit `-cp` replaces the default classpath; it does not automatically add `.`.** If we used only `"lib001:lib002"` here, lookup would not start at `deployment`, and even `Main` would be missing.

Each class is found through one of our directory entries:

| Class | Classpath entry | Class file, relative to `deployment` |
| --- | --- | --- |
| `dev.deepdive.app.Main` | `.` | `dev/deepdive/app/Main.class` |
| `dev.deepdive.app.MessageService` | `.` | `dev/deepdive/app/MessageService.class` |
| `dev.deepdive.greeting.Greeting` | `lib001` | `lib001/dev/deepdive/greeting/Greeting.class` |
| `dev.deepdive.punctuation.Punctuation` | `lib002` | `lib002/dev/deepdive/punctuation/Punctuation.class` |

With the files and arguments aligned, the output is:

```text
Hello, classpath!
```

Here is the full sequence: compile the two sources with `javac -cp "lib001:lib002"`, inspect the generated class files, then launch with `java -cp ".:lib001:lib002"`:

![Compiling with the dependency classpath, then launching with a runtime classpath that also includes the application classes](https://raw.githubusercontent.com/ailuruschen-bit/java-deep-dive-labs/main/chapters/01-plain-java-project/article/assets/experiment-05-compile-and-run-classpath.png)

### Leave out a runtime dependency

Now deliberately omit `lib002` from the runtime classpath, changing nothing else:

```bash
java -cp ".:lib001" dev.deepdive.app.Main
```

This is no longer a compilation error. The program fails during execution:

```text
java.lang.NoClassDefFoundError: dev/deepdive/punctuation/Punctuation
Caused by: java.lang.ClassNotFoundException: dev.deepdive.punctuation.Punctuation
```

In this run, execution has entered `Main.main`, and `MessageService` and `Greeting` have loaded successfully. When the code needs `Punctuation`, the class loader cannot find it using the current classpath, producing `ClassNotFoundException`. Because execution requires the class and loading fails, the JVM reports `NoClassDefFoundError` to the program, with that `ClassNotFoundException` as its cause.

We did not delete `Punctuation.class`. The file is still on disk; its search location, `lib002`, is missing from this launch's classpath. Finding a declaration at compile time does not guarantee that the class will be found on the next run. **Check not just whether the file exists, but whether “classpath directory entry + path derived from the class name” actually leads to it.**

The directory listing still shows `Punctuation.class`, while the failure points to `MessageService.messageFor`:

![Punctuation.class remains on disk, but omitting lib002 causes NoClassDefFoundError with ClassNotFoundException as its cause](https://raw.githubusercontent.com/ailuruschen-bit/java-deep-dive-labs/main/chapters/01-plain-java-project/article/assets/experiment-06-runtime-classpath-missing.png)

> The `CLASSPATH` environment variable can also supply a default classpath. An explicit `-cp` takes precedence over it. When neither is set, the default is the single entry `.`. The default-path examples here run without that environment variable; the other examples specify their entries with `-cp`.

We now have separate roles for compilation and execution. The compiler reads source and dependency declarations to produce our class files. At launch, we specify an entry class and a runtime classpath that makes the required bytecode available. Each stage has its own configuration, but both depend on the same relationship between class names and file locations.

## Package the class files into JARs

In everyday development, dependencies usually arrive as JARs rather than individual class files. What changes in our compile and launch commands if we replace `lib001` and `lib002` with JAR files?

First, consider the contents. A **JAR (Java Archive)** is a ZIP-based archive that holds class files and other resources while preserving their directory structure. We can still locate a class file by its class name; the lookup now happens inside an archive rather than a directory.

`javac` compiles source into class files. Another JDK command, `jar`, copies existing files into an archive. **Compilation changes the representation of the code; packaging changes how its files are organized.** The original class files remain in place after packaging.

> A dependency may also provide a companion `xxx-sources.jar`. Usually, `xxx.jar` contains compiled class files and `xxx-sources.jar` contains the corresponding `.java` files for source browsing and debugging in an IDE. A JAR can contain both, but providing source does not necessarily mean bundling it with the bytecode. For the launch mechanisms in this article, the runtime still needs class files; a sources JAR is not a replacement for the compiled dependency.

The JAR example uses the same four classes in a separate directory named `work`. Initially, the two application sources are under `src/dev/deepdive/app/`, the compiled dependencies are under `lib001` and `lib002`, and `lib` is an empty directory for the resulting archives. Unless noted otherwise, the packaging, compilation, and launch commands below run with `work` as their working directory:

```text
work/  ← working directory for the following commands
├── src/dev/deepdive/app/
│   ├── Main.java
│   └── MessageService.java
├── lib001/dev/deepdive/greeting/Greeting.class
├── lib002/dev/deepdive/punctuation/Punctuation.class
└── lib/  ← destination for the dependency JARs
```

### Read the jar command in parts

Read the command in this order: what to do, which archive to operate on, and which input files it needs:

```text
jar --create --file target.jar files-to-package
jar --list   --file target.jar
```

`--create` creates an archive; `--list` lists the contents of an existing one. `--file` identifies the target JAR. For creation, that path determines where the output goes; for listing, it identifies the file to read.

When packaging, we also need to choose where to read the input files. `-C` switches the input location to a specified directory—think of **C as “change directory.”** To put the contents of `lib001` into `lib/greeting.jar`, use:

```bash
jar --create --file lib/greeting.jar -C lib001 .
```

The pieces have separate jobs:

| Command fragment | Meaning in this command |
| --- | --- |
| `--create` | Create an archive |
| `--file lib/greeting.jar` | Write the JAR under `lib` in the working directory |
| `-C lib001` | Read the following input from `lib001` |
| `.` | Include that directory's contents, including subdirectories |

There are two locations here: `--file` says **where to write the JAR**, while `-C` says **where to read its input**. `-C` does not change our shell's working directory, and it does not put `lib/greeting.jar` inside `lib001`.

The final `.` is interpreted relative to `lib001`, as selected by `-C`. The archive therefore contains the structure starting at `dev`, **without the enclosing `lib001` directory**. That preserves the path derived from the class name.

The second dependency uses the same structure, with different input and output locations:

```bash
jar --create --file lib/punctuation.jar -C lib002 .
```

![Packaging the contents of lib001 and lib002 into dependency JARs while leaving the original class files in place](https://raw.githubusercontent.com/ailuruschen-bit/java-deep-dive-labs/main/chapters/01-plain-java-project/article/assets/experiment-07-jar-packaging.png)

To inspect a JAR, change the action to `--list` and identify it with `--file`. Listing does not need packaging input:

```bash
jar --list --file lib/greeting.jar
```

Shown as a tree, the entries are:

```text
greeting.jar
├── META-INF/
│   └── MANIFEST.MF  ← generated automatically during packaging
└── dev/
    └── deepdive/
        └── greeting/
            └── Greeting.class
```

Notice two things. `Greeting.class` retains the path `dev/deepdive/greeting/Greeting.class`, just as it did relative to `lib001`.

There is also a file we did not supply: `META-INF/MANIFEST.MF`. `jar` generated this text file during packaging. It is called the **manifest**, and it records information about the JAR. We will use it shortly to record the application's entry point and dependency locations.

![Listing both dependency JARs: class paths begin at dev, and each archive includes an automatically generated manifest](https://raw.githubusercontent.com/ailuruschen-bit/java-deep-dive-labs/main/chapters/01-plain-java-project/article/assets/experiment-08-jar-contents.png)

### Using a JAR is still a classpath operation

Packaging requires us to arrange input directories and archive contents. Using the result is simpler: **replace directory entries in `-cp` with JAR paths. The class names and source code stay the same.** For `Greeting`, only the container changes:

```text
Class name: dev.deepdive.greeting.Greeting

Classpath entry (directory): lib001
  → file: lib001/dev/deepdive/greeting/Greeting.class

Classpath entry (JAR): lib/greeting.jar
  → archive entry: dev/deepdive/greeting/Greeting.class
```

This works for the compiler too. Still in `work`, compile against the two JARs:

```bash
javac -cp "lib/greeting.jar:lib/punctuation.jar" -d app-classes \
  src/dev/deepdive/app/Main.java \
  src/dev/deepdive/app/MessageService.java
```

We use the familiar `-d` to put the output in `app-classes`, separate from the source. We can run with our own classes in a directory and dependencies in JARs:

```bash
java -cp "app-classes:lib/greeting.jar:lib/punctuation.jar" dev.deepdive.app.Main
```

A single classpath can mix directory and JAR entries. It does not require all classes to use the same storage format.

![Compiling against dependency JARs into app-classes, then running with a classpath containing both a directory and JARs](https://raw.githubusercontent.com/ailuruschen-bit/java-deep-dive-labs/main/chapters/01-plain-java-project/article/assets/experiment-09-jar-compile-and-run.png)

To package our application too, use the same command structure. This time the input is `app-classes`, and the output is `app.jar` in the working directory:

```bash
jar --create --file app.jar -C app-classes .
```

For launch, replace only the first entry, `app-classes`, with `app.jar`:

```bash
java -cp "app.jar:lib/greeting.jar:lib/punctuation.jar" dev.deepdive.app.Main
```

The output is still `Hello, classpath!`. All three entries are now JARs: `app.jar` supplies our two classes, and the other JARs supply the dependencies. The runtime reads the class files directly from the archives; we do not need to unpack them first.

![Packaging the application as app.jar, inspecting it, and launching with three JAR entries on the classpath](https://raw.githubusercontent.com/ailuruschen-bit/java-deep-dive-labs/main/chapters/01-plain-java-project/article/assets/experiment-10-application-jar.png)

### Let the JAR describe how to start it

We often see applications launched as `java -jar app.jar`, with no entry class or dependency paths in the command. How can we launch our application that way?

This is where `META-INF/MANIFEST.MF` comes in. Packaging `app.jar` also creates a manifest, but the tool does not choose our entry class or fill in our dependency locations. Our current `app.jar` is therefore not yet ready for `java -jar`.

There is no need to unpack the JAR and edit its contents. Prepare a text file named `app-manifest.mf` in the working directory, then let the packaging command add its information to the manifest:

```text
Main-Class: dev.deepdive.app.Main
Class-Path: lib/greeting.jar lib/punctuation.jar

```

`Main-Class` identifies the class whose `main` method starts the application. `Class-Path` supplies the external dependencies. We still have three separate JARs; the dependencies have not been copied inside `app.jar`.

Keep the same packaging command and add one option before `-C`: `--manifest app-manifest.mf`. The output path and input selection stay unchanged:

```bash
jar --create --file app.jar \
  --manifest app-manifest.mf \
  -C app-classes .
```

This recreates `app.jar` with the supplied information in `META-INF/MANIFEST.MF`. We can now run:

```bash
java -jar app.jar
```

Here, the argument to `-jar` really is a file path. The manifest now supplies the entry class and dependency locations. Keep a terminating newline in the manifest input, and separate `Class-Path` locations with spaces, not the colons used in our `-cp` commands. These dependency paths are resolved relative to **the directory containing `app.jar`**, not the shell's working directory.

We can therefore deliver `app.jar` and the whole `lib` directory together. As long as their relative layout is preserved, the manifest still points to the dependencies.

**With `java -jar`, the command-line `-cp` setting is ignored.** Adding `-cp "lib/greeting.jar:lib/punctuation.jar"` before `-jar app.jar` would not supply missing dependencies. This example uses the manifest's `Class-Path` instead.

![Creating the manifest, repackaging, and successfully launching first from work and then from its parent with java -jar work/app.jar](https://raw.githubusercontent.com/ailuruschen-bit/java-deep-dive-labs/main/chapters/01-plain-java-project/article/assets/experiment-11-manifest-launch.png)

## Maven revisited: dependency paths and directory conventions

Think of a standard Maven project. Dependencies are declared in the root `pom.xml`, and application source lives under `src/main/java`. After `mvn compile`, the bytecode appears in `target/classes`. For an ordinary JAR project, `mvn package` also produces a JAR under `target`.

With our manual compilation, launch, and packaging steps in mind, can we infer **how Maven finds dependencies, compiles the source, and packages the result?**

We can divide the work into two parts: **locating external dependencies, and organizing the project's own source, resources, and build output.** We supplied these locations in our commands; Maven gives them shared configuration and conventions.

### 1. External dependencies: where are the JARs?

We placed our dependencies in `lib001` and `lib002`, or in JARs under `lib`, and entered their locations in `-cp`. With Maven, we declare dependency identifiers and versions in `pom.xml`. Maven uses those declarations to assemble the complete list of dependencies the project needs. For the ordinary Java libraries discussed here, these are usually JARs.

We do not have to copy each JAR into each project. Maven stores dependencies in a **local repository**, shared across projects. Its default location is `.m2/repository` under the user's home directory, with files organized by dependency identity and version. Missing JARs are normally downloaded from a remote repository and stored there.

From the dependency list and their storage locations, Maven can find the JARs and assemble their actual paths into the classpath for the current stage. **This is the work we did by locating files and entering their paths in `-cp`.** Project configuration now supplies that information instead of our handwritten command.

Once Maven can assemble a classpath, it can assemble different ones for different purposes. Compiling application code, compiling test code, and running the application need not use identical dependency lists.

A dependency's `scope` in `pom.xml` indicates **which contexts should include it in the classpath**. For example, we typically use JUnit only in tests and declare it with `<scope>test</scope>`. Compare the two compilations: JUnit is available when compiling test source, but not when compiling the main application source.

### 2. Project files: where do source and output belong?

Here is an ordinary Maven JAR project using the default layout, with its source directories and typical build output shown together:

```text
project/
├── pom.xml
├── src/
│   ├── main/
│   │   ├── java/             ← application source, organized by package
│   │   └── resources/        ← application resources, such as configuration
│   └── test/
│       ├── java/             ← test source, also organized by package
│       └── resources/        ← test resources
└── target/                   ← build output, not just bytecode
    ├── classes/              ← application classes and resources
    ├── test-classes/         ← test classes and resources
    └── example-1.0.0.jar     ← packaged output; its name is configurable
```

Read the layout in two layers: `main` versus `test` distinguishes purpose; `java` versus `resources` distinguishes source code from resources. During a build, source is compiled, while resources are normally copied with their relative paths preserved. Application classes and resources go to `target/classes`; test classes and resources go to `target/test-classes`.

This is the same arrangement we made with `javac -d app-classes`. We chose `app-classes` ourselves; Maven's default convention puts build output under `target`, with application compilation output in `target/classes` and test compilation output in `target/test-classes`.

Nor is `src/main/java` part of a package name. The source for `dev.deepdive.app.Main` is at `src/main/java/dev/deepdive/app/Main.java`, and its compiled class is at `target/classes/dev/deepdive/app/Main.class`. For launch, the search location for application classes is `target/classes`. We do not add `src`, `main`, or `java` to the class name.

### Read the build in terms of familiar operations

Once the dependencies and directory conventions are in place, the build operations should look familiar:

| Build operation | What it needs or produces |
| --- | --- |
| Compile application source | Source files, a compilation dependency classpath, and `target/classes` as the output directory |
| Compile test source | Test source, a classpath containing application output and test dependencies, and `target/test-classes` as the output directory |
| Package an ordinary JAR | Application classes and resources from `target/classes`; by default, neither test classes nor the external dependency JARs |

Both compilations correspond to the familiar `javac -cp … -d …`, with different sources, dependency lists, and destinations. Packaging can be understood in terms of `jar --create --file … -C target/classes .`. This describes the information each operation needs; it does not mean Maven must launch these exact shell commands.

Now the usual build commands have concrete outputs: `mvn compile` generates application class files; `mvn test-compile` goes on to compile test source. In a normally configured JAR project, a successful `mvn package` produces the archive under `target`. Maven determines the sources, dependencies, and destinations from configuration and conventions.

How do we normally launch such a project? Maven has no single standard application-launch command that works for every project. During development, we commonly select an entry class in the IDE and click Run. The IDE can use the Maven project configuration to assemble a classpath containing compiled application output and runtime dependency JARs, then launch our chosen entry class.

If we run `java -cp` ourselves, we must still supply the classpath, just as in the earlier examples. Two dependencies are easy to type; dozens or hundreds are tedious and easy to get wrong, so tools usually generate those paths. **One-click launch removes the work of assembling a command, not the need for a classpath.**

Maven has not changed the relationship between class names and physical files. Our manually chosen search locations, compilation output, and archive contents have become reusable project conventions and build configuration.

### Does a packaged JAR also make a deployable application?

Can we copy the JAR produced by `mvn package` to a server and launch it with `java -jar`, as we did earlier?

Recall that we did more than archive class files: we also supplied an entry point and dependency locations in the manifest. **An ordinary Maven JAR build does not fill in `Main-Class` and a dependency `Class-Path` by default.** For that style of launch, those still need to be configured.

There is also the question of the files themselves. Dependencies in our development machine's local repository do not travel with the application JAR. The manifest must refer to files that will actually exist on the server, not assume that the server shares our development directory layout.

We can use the same delivery structure as before:

```text
release/
├── app.jar
└── lib/
    ├── greeting-1.0.0.jar
    ├── punctuation-1.0.0.jar
    └── … other runtime dependencies
```

The manifest's `Class-Path` uses relative paths such as `lib/greeting-1.0.0.jar`. Deploy the entire `release` directory, and the relationship between the application JAR and its dependencies stays intact. There is no need to reproduce the development machine's local repository.

This directory and manifest need not be assembled by hand. **Maven provides ways to collect runtime dependencies, generate the manifest, and assemble a distribution automatically.** With the build configured, it produces the agreed layout. Another option is to merge application and dependency classes and resources into one JAR and configure its entry point.

The references cover configuration options; detailed setup can wait for a dedicated article. The principle here is enough: the locations used at startup must match the layout of the files we deliver.

## Spring Boot revisited: one JAR for application and dependencies

A typical Spring Boot deployment consists of one executable JAR, launched with `java -jar`. There is no separate `lib` directory to copy and no dependency path list to enter by hand. We can understand it through the same two questions: how are the files organized, and where does execution begin?

### 1. File layout: application and dependencies in one archive

With Spring Boot executable-JAR packaging configured, the build places application classes and dependencies in one archive. Dependencies remain individual JARs rather than being unpacked and merged. Using our class names, the relevant layout looks like this:

```text
app.jar
├── META-INF/
│   └── MANIFEST.MF
├── org/springframework/boot/loader/
│   └── … launcher class files
└── BOOT-INF/
    ├── classes/
    │   └── dev/deepdive/app/
    │       ├── Main.class
    │       └── MessageService.class
    └── lib/
        ├── greeting-1.0.0.jar
        ├── punctuation-1.0.0.jar
        └── … Spring Boot and other dependency JARs
```

Application classes go under `BOOT-INF/classes`; dependency JARs go under `BOOT-INF/lib`. The application and dependencies that previously travelled together as a directory now fit inside one file.

### 2. Startup: the launcher comes before the application

The application classes now have a `BOOT-INF/classes` prefix, and dependency JARs are nested inside another JAR. How does startup find them? Consider these manifest entries for Spring Boot 3.5's default executable-JAR layout:

```text
Main-Class: org.springframework.boot.loader.launch.JarLauncher
Start-Class: dev.deepdive.app.Main
```

`java -jar` still reads `Main-Class`, but the first code it runs is Spring Boot's `JarLauncher`. That class sits at `org/springframework/boot/loader/launch/` relative to the archive's top level, so it can be found using the rule we already know.

`JarLauncher` creates a class loader that understands Boot's layout: application classes under `BOOT-INF/classes` and nested dependency JARs under `BOOT-INF/lib`. It then reads `Start-Class` and invokes our entry class's `main` method. This is more than constructing an ordinary `-cp` argument: ordinary JAR lookup does not automatically search JARs nested inside another JAR. **Set up class loading first, then call the application entry point:** that is the extra step.

```text
java -jar app.jar
        │
        ▼
Main-Class → Spring Boot launcher
        │
        ├── Application classes: BOOT-INF/classes
        ├── Dependency classes: JARs inside BOOT-INF/lib
        │
        ▼
Start-Class → main method of dev.deepdive.app.Main
```

## Different packaging, the same lookup problem

From manual `javac` and `java` commands to Maven builds and Spring Boot executable JARs, the essential task is the same: **compile source into class files, then make the entry class and the classes it uses available at runtime.** Tools organize dependencies, output directories, and startup information for us. The connection between class names and physical files remains.

Open a project you know and inspect its compilation output, packaged artifact, and actual launch command. Which class is the entry point? Where are the classes it needs? Which configuration or startup code connects those locations? Use those questions to trace the project from source to execution.

## References

- [Oracle JDK 21: javac, grouped source compilation, and type lookup](https://docs.oracle.com/en/java/javase/21/docs/specs/man/javac.html)
- [Oracle JDK 21: java and the classpath](https://docs.oracle.com/en/java/javase/21/docs/specs/man/java.html)
- [Oracle Java SE 21: ClassLoader API](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/ClassLoader.html)
- [Java Language Specification 21: Binary Names](https://docs.oracle.com/javase/specs/jls/se21/html/jls-13.html#jls-13.1)
- [Java Virtual Machine Specification 21: The class File Format](https://docs.oracle.com/javase/specs/jvms/se21/html/jvms-4.html)
- [Java Virtual Machine Specification 21: Creating Classes with User-defined Class Loaders](https://docs.oracle.com/javase/specs/jvms/se21/html/jvms-5.html#jvms-5.3.2)
- [Oracle JDK 21: jar](https://docs.oracle.com/en/java/javase/21/docs/specs/man/jar.html)
- [Oracle JDK 21: JAR File Specification](https://docs.oracle.com/en/java/javase/21/docs/specs/jar/jar.html)
- [Maven Source Plugin: creating a companion sources JAR](https://maven.apache.org/plugins/maven-source-plugin/usage.html)
- [Maven: Standard Directory Layout](https://maven.apache.org/guides/introduction/introduction-to-the-standard-directory-layout.html)
- [Maven: Dependency Mechanism](https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html)
- [Maven: Build Lifecycle](https://maven.apache.org/guides/introduction/introduction-to-the-lifecycle.html)
- [IntelliJ IDEA: Project dependencies and compilation/runtime classpaths](https://www.jetbrains.com/help/idea/working-with-module-dependencies.html)
- [Maven JAR Plugin: inputs to an ordinary JAR](https://maven.apache.org/plugins/maven-jar-plugin/jar-mojo.html)
- [Maven Archiver: manifest entry point and dependency paths](https://maven.apache.org/shared/maven-archiver/examples/classpath.html)
- [Maven Dependency: collecting dependency files](https://maven.apache.org/plugins/maven-dependency-plugin/copy-dependencies-mojo.html)
- [Maven Assembly: assembling a distribution](https://maven.apache.org/plugins/maven-assembly-plugin/)
- [Maven Shade: merging application and dependency contents](https://maven.apache.org/plugins/maven-shade-plugin/)
- [Spring Boot 3.5: Nested JARs](https://docs.spring.io/spring-boot/3.5/specification/executable-jar/nested-jars.html)
- [Spring Boot 3.5: Launching Executable JARs](https://docs.spring.io/spring-boot/3.5/specification/executable-jar/launching.html)
- [Spring Boot 3.5: executable-JAR packaging configuration](https://docs.spring.io/spring-boot/3.5/maven-plugin/packaging.html)

## Example code

[GitHub · Java Deep Dive Labs](https://github.com/ailuruschen-bit/java-deep-dive-labs/tree/main/chapters/01-plain-java-project/lab)
