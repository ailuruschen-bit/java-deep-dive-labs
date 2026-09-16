# How Java Compiles: What the Compiler Checks

In the first article, we used `javac` to produce class files and `java` to run them. The compiler needed a classpath to find dependencies, but finding a file was only the beginning. A class may be available and a call to it still be invalid. Some problems are caught before we run anything; others appear only during execution. Where is that boundary?

This time, we will read the diagnostics from `javac`. Without adding a build tool, we will make small changes to the source, observe what the compiler accepts or rejects, and use those results to understand what it checks.

The examples use JDK 21 and macOS/Linux shell commands. Each is a separate `Main.java`, with the code and results shown below. Spaces for actual demonstration screenshots are left for the author to fill after recording the experiments.

## A compilation error is not an exception from main

Start with a familiar program, deliberately missing one semicolon:

```java
public class Main {
    public static void main(String[] args) {
        String message = "Hello, compiler!"
        System.out.println(message);
    }
}
```

From `lab/01-syntax/broken`, run:

```bash
javac -d out Main.java
```

Compilation fails with this diagnostic:

```text
Main.java:3: error: ';' expected
        String message = "Hello, compiler!"
                                           ^
1 error
```

We have not run `java`, so our `main` method has not executed. **The compiler rejected the source; the application did not reach that line and throw an exception.** Adding `try/catch` to the application cannot catch this compilation error.

Restore the semicolon, then compile and launch the corrected version in `lab/01-syntax/fixed`:

```bash
javac -d out Main.java
java -cp out Main
```

Only now do we get the program's output:

```text
Hello, compiler!
```

Throughout this chapter, `-d out` keeps compiled output separate from the source. Each independent example has its own `out`, so we do not confuse its results with a previous example's class files.

> Screenshot to add: compilation fails without the semicolon; after the fix, compilation produces `out/Main.class`, and launching the program prints the message.

When reading a `javac` diagnostic, start with the source filename, line number, and text after `error:`. The source excerpt and `^` marker show where the compiler detected the problem. Fix the missing semicolon and compile again before treating every later diagnostic as a separate issue: a structural error can make the following code harder to interpret too.

## Valid syntax still needs declarations

Recognizing a statement is not enough. The compiler also needs to determine which declarations its names refer to.

In `lab/02-name/broken`, the program is:

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

The relevant diagnostic is:

```text
error: cannot find symbol
  symbol:   variable message
  location: class Main
```

Here, *symbol* refers to a name in the source that needs to resolve to a declaration. The compiler can recognize the method-call statement, but it cannot find a variable declaration for `message`. It therefore cannot establish its type or whether it can be used here.

This is related to the missing-classpath-entry problem in the first article, but the fix is different. There, the missing declaration belonged to an external class, and we supplied a search location for it. Here, the missing declaration is a variable in our own code. Changing the classpath will not help.

Add this line before `println`, and the compiler can associate `message` with a local variable of type `String`:

```java
String message = "Hello, compiler!";
```

The complete corrected version is in `lab/02-name/fixed`. Compile and run it with the same commands:

```bash
javac -d out Main.java
java -cp out Main
```

So `cannot find symbol` is not an automatic instruction to check dependencies. First read what follows `symbol`: is it a variable, a method, or a class? Then check the declaration's spelling and whether it is available at the point of use.

> Screenshot to add: the diagnostic for the undeclared `message`, followed by successful compilation after restoring its declaration.

## A declaration does not make every use valid

Now that `message` has a declaration, change its initial value to an integer:

```java
public class Main {
    public static void main(String[] args) {
        String message = 42;
        System.out.println(message);
    }
}
```

Compile from `lab/03-type/broken`:

```bash
javac -d out Main.java
```

```text
error: incompatible types: int cannot be converted to String
```

No name or semicolon is missing. The declaration on the left requires a `String`; the literal `42` on the right has type `int`. Java does not allow an implicit integer-to-string conversion in this assignment, so the compiler rejects it.

We want text in this example, so use `"42"`. The corrected version is in `lab/03-type/fixed`:

```java
String message = "42";
```

```bash
javac -d out Main.java
java -cp out Main
```

It prints `42`. The characters we see may be the same, but the integer literal and the string literal have different types, with different permitted operations.

Method calls need similar checks. Think back to `Greeting.forName(name)` in the previous article. Finding `Greeting.class` is not sufficient: the compiler must determine whether the named method is accessible and accepts the argument. It can then use the declared return type to check the surrounding expression. **The classpath answers where the declarations are; type checking answers whether this use of them is valid.**

There is no need to run `forName` to find that out. Its parameter and return types are in its declaration, which the compiler can read even when a dependency is available only as a class file.

> Screenshot to add: assigning an integer to `String` fails compilation; changing it to a string literal allows compilation and execution.

## The right type is not enough: a value must be assigned

Next, take the message from a command-line argument. Use the first argument if one is present; otherwise, do nothing for now:

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

Compile from `lab/04-flow/broken`:

```bash
javac -d out Main.java
```

```text
error: variable message might not have been initialized
```

The name exists and the types fit. The problem is that execution can reach `println` by more than one path:

```text
args.length > 0 ?
├── yes → message = args[0] ──┐
└── no  → no assignment ──────┤
                            ▼
                   println(message)
```

`message` is a local variable. Unlike an object's fields, it does not receive an automatic default value. Before we read it, Java requires that it has been assigned according to the language's analysis rules. This check is called **definite assignment**.

Promising to supply an argument every time does not change what the compiler checks. The source still has a branch that reaches the read without assigning the variable.

The corrected version in `lab/04-flow/fixed` supplies the missing branch:

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

The two runs print `Alice` and `Hello, compiler!`, respectively. Compilation succeeds not because the compiler tried both runs in advance, but because both branches explicitly assign a value.

> Screenshot to add: the definite-assignment error without `else`, followed by successful runs through both branches of the corrected program.

## An IOException diagnostic does not mean the compiler read the file

Change the message source again, this time to a file. The program in `lab/05-checked/broken` is:

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

The key diagnostic is now:

```text
error: unreported exception IOException; must be caught or declared to be thrown
```

It is easy to read this as evidence that the compiler tried to open the file and something went wrong. That is not what happened. It inspected the declaration of `Files.readString`, which declares that it may throw `IOException`. Our call must satisfy Java's exception-checking rules.

`IOException` is a **checked exception**. At this call site, we must either handle it with `try/catch` or declare it in the enclosing method's `throws` clause so that it may propagate to the caller. Not every exception has this requirement; the array-bounds exception in the next example does not.

Choose the second option so that a file-read failure remains visible. The full corrected program in `lab/05-checked/fixed` is:

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

This version compiles. Adding `throws IOException` has not repaired a file, read a file, or guaranteed that the read will succeed. It declares that the method can let the exception propagate rather than handling it locally.

The file is needed when we run the program. The lab's `with-file` directory contains a `message.txt` with the text `Hello, file!`; the `fixed` directory does not contain that file. After compiling in `fixed`, switch to `with-file` and run:

```bash
cd ../with-file
java -cp ../fixed/out Main
```

This prints `Hello, file!`. Now return to the directory without the message file and run again, without recompiling:

```bash
cd ../fixed
java -cp out Main
```

The same `Main.class` now reports `java.nio.file.NoSuchFileException: message.txt`. `NoSuchFileException` is a subtype of `IOException`, so it is one of the failures covered by the declaration.

The relative path `message.txt` is resolved against the process's working directory, not the classpath. `-cp` tells the JVM where to find classes; it does not change the starting point for relative file paths passed to `Files.readString`.

> Screenshot to add: compilation fails without an exception declaration and succeeds with `throws`; the same class then runs with and without the message file, producing different results.

**The compiler checks that the code catches or declares the checked exception. The actual file access happens at runtime.** Calling a checked exception an “exception thrown at compile time” confuses those two stages.

## What successful compilation does—and does not—prove

After seeing definite-assignment checks, we might expect the compiler to catch every dangerous operation. Consider this version, which directly uses the first command-line argument. It is in `lab/06-runtime/valid`:

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

Compilation succeeds, and the program prints `Alice`. Run it again without an argument:

```bash
java -cp out Main
```

This time it reports:

```text
java.lang.ArrayIndexOutOfBoundsException: Index 0 out of bounds for length 0
```

The compiler can establish that `args` is a `String[]`, that index `0` is an integer, and that the element's value can be assigned to a `String`. Whether the array in this particular execution actually has a first element is checked at runtime.

This does not contradict definite assignment. Java requires compile-time checks for assignment before a local variable is read. Array bounds are checked when an array access executes. **Successful compilation means the code passed the required compilation checks; it is not proof of correctness for every input and environment.**

We already have a fix in the definite-assignment example: check `args.length` before choosing between the first argument and a default message. An unnecessary cast or a different classpath would not address the missing argument.

> Screenshot to add: the same compiled program succeeds with an argument and fails with an array-bounds exception without one.

## Read a diagnostic as a question the compiler is asking

We can organize these examples into a model for reading compiler diagnostics. This is a way to understand the checks and their relationships, not a description of the compiler's internal pipeline or a promise that diagnostics appear in this order:

```text
Source
 │
 ├── Is the structure valid?                Missing semicolon
 ├── Do names resolve to declarations?      Undeclared message
 ├── Are these types compatible here?      int assigned to String
 ├── Is the local definitely assigned?     A branch leaves it unassigned
 └── Is the checked exception accounted for? IOException not caught or declared
 │
 ▼
Class file → java launches it → execution with actual arguments and environment
```

The next time the IDE underlines a line of code, ask two questions: **is this a compile-time rule being violated, or a failure after execution has begun? Does the diagnostic concern syntax, a name, a type, control flow, or an exception declaration?**

The first article explained where classes come from. This one explains why the compiler accepts—or rejects—our use of them. Together, they set up the next question: which declarations and operations are retained in the generated class file?

## References

- [JDK 21: javac and declaration lookup](https://docs.oracle.com/en/java/javase/21/docs/specs/man/javac.html)
- [JLS 21 §14.4: Local Variable Declarations](https://docs.oracle.com/javase/specs/jls/se21/html/jls-14.html#jls-14.4)
- [JLS 21 §6.5.6.1: Simple Expression Names](https://docs.oracle.com/javase/specs/jls/se21/html/jls-6.html#jls-6.5.6.1)
- [JLS 21 §5.2: Assignment Contexts](https://docs.oracle.com/javase/specs/jls/se21/html/jls-5.html#jls-5.2)
- [JLS 21 §15.12.2: Determining a Method Signature at Compile Time](https://docs.oracle.com/javase/specs/jls/se21/html/jls-15.html#jls-15.12.2)
- [JLS 21 Chapter 16: Definite Assignment](https://docs.oracle.com/javase/specs/jls/se21/html/jls-16.html)
- [JLS 21 §11.2: Compile-Time Checking of Exceptions](https://docs.oracle.com/javase/specs/jls/se21/html/jls-11.html#jls-11.2)
- [JDK 21: Files.readString](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/file/Files.html#readString(java.nio.file.Path))
- [JLS 21 §15.10.4: Run-Time Evaluation of Array Access](https://docs.oracle.com/javase/specs/jls/se21/html/jls-15.html#jls-15.10.4)
