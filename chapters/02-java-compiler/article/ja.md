# Java のコンパイルをひもとく：コンパイラは何を確かめるのか

[中文](zh-CN.md) · [日本語](ja.md) · [English](en.md)

前回は `javac` で class ファイルを作り、`java` で起動するまでを追いました。コンパイラが依存クラスを見つけるには classpath が必要でしたが、ファイルが見つかれば何でもコンパイルできるわけではありません。クラスはあるのに、なぜメソッドを呼び出せないのか。実行せずに分かる問題と、実行して初めて分かる問題は、どこで分かれるのでしょうか。

今回は `javac` の診断メッセージを手掛かりにします。引き続きビルドツールは使いません。小さなプログラムを少しずつ変え、コンパイラが何を受け入れ、何を拒むかを観察します。

実験は JDK 21 を使い、コマンドは macOS／Linux 向けに記述しています。それぞれ独立した `Main.java` を使い、コードと実行結果を本文に示します。実際の操作画面は、後から追加するための位置だけを示しています。

## コンパイルエラーは、main が投げた例外ではない

見慣れたプログラムから始めましょう。ただし、一か所だけセミコロンを抜いてあります。

```java
public class Main {
    public static void main(String[] args) {
        String message = "Hello, compiler!"
        System.out.println(message);
    }
}
```

`lab/01-syntax/broken` でコンパイルします。

```bash
javac -d out Main.java
```

コンパイルは失敗し、次の診断が出ます。

```text
Main.java:3: error: ';' expected
        String message = "Hello, compiler!"
                                           ^
1 error
```

まだ `java` は実行していません。当然、`main` も動いていません。これは**コンパイラがソースコードを受け付けなかった**のであって、プログラムがその行を実行して例外を投げたのではありません。アプリケーションに `try/catch` を加えても、このコンパイルエラーは捕捉できません。

セミコロンを補った `lab/01-syntax/fixed` で、コンパイルして起動します。

```bash
javac -d out Main.java
java -cp out Main
```

ここで初めて、プログラムから出力されます。

```text
Hello, compiler!
```

本章では `-d out` を使い、ソースと生成物を分けています。各例が別々の `out` を使うので、以前のコンパイル結果と取り違えずに確認できます。

> 操作画面を追加予定：セミコロンがない場合のコンパイルエラーと、修正後に `out/Main.class` を生成して起動するまで。

`javac` の診断を読むときは、まずファイル名、行番号、`error:` に続く内容を見ます。その下のコード抜粋と `^` は、問題を検出した位置です。この例なら、まずセミコロンを直して再コンパイルします。一つの構文の崩れが、後続のコードの解釈にも影響することがあるからです。最初からすべての診断を別々の問題と考える必要はありません。

## 構文が読めても、名前が何を指すかは別の問題

先ほどの構文の誤りを直しても、コンパイラが確かめることは残っています。コード中の名前が、どの宣言を指しているかです。

`lab/02-name/broken` のプログラムは次の形です。

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

今度の診断は次のとおりです。

```text
error: cannot find symbol
  symbol:   variable message
  location: class Main
```

ここでいう `symbol` は、ソースコード中の、宣言に結び付ける必要がある名前です。コンパイラはメソッド呼び出しの構文を読めていますが、`message` に対応する変数の宣言が見つかりません。これでは型も、ここで使ってよいかどうかも判断できません。

前回の classpath 不足も、必要な宣言が見つからない問題でした。ただし、直す場所が違います。前回は外部クラスの宣言を探す場所が足りませんでした。今回はコード内の変数宣言がないので、classpath を変えても解決しません。

`println` の前に、次の一行を戻します。

```java
String message = "Hello, compiler!";
```

これで `message` を、`String` 型のローカル変数の宣言に結び付けられます。完全な修正版は `lab/02-name/fixed` にあります。

```bash
javac -d out Main.java
java -cp out Main
```

`cannot find symbol` を見ても、すぐに依存ライブラリを探し直すとは限りません。まず `symbol` が変数、メソッド、クラスのどれなのかを読み、宣言の名前が正しいか、その場所から参照できるかを確認します。

> 操作画面を追加予定：`message` の宣言がない場合の診断と、宣言を戻した後のコンパイル結果。

## 宣言が見つかったら、型の使い方を確かめる

`message` の宣言を残し、初期値だけを整数に変えてみましょう。

```java
public class Main {
    public static void main(String[] args) {
        String message = 42;
        System.out.println(message);
    }
}
```

`lab/03-type/broken` でコンパイルします。

```bash
javac -d out Main.java
```

```text
error: incompatible types: int cannot be converted to String
```

名前もセミコロンも足りています。問題は、左辺が `String` を受け取る宣言なのに、右辺の `42` は `int` だということです。この代入では整数を文字列へ自動変換する規則がないため、コンパイラは受け付けません。

この例で保持したいのは文字列なので、`"42"` と書きます。修正版は `lab/03-type/fixed` にあります。

```java
String message = "42";
```

```bash
javac -d out Main.java
java -cp out Main
```

出力は `42` です。画面に現れる文字が同じでも、ソースコードの整数と文字列は異なる型であり、許される操作も異なります。

メソッド呼び出しにも同じような確認が必要です。前回の `Greeting.forName(name)` なら、`Greeting.class` があるだけでは十分ではありません。メソッド名、アクセスできるかどうか、引数を渡せるかどうかを確認し、宣言された戻り値の型を使って、呼び出しを含む式も検査します。**classpath は宣言を探す場所を決め、型の検査はその使い方が成立するかを確かめます。**

`forName` を一度実行してみる必要はありません。引数や戻り値の型は宣言から分かります。ソースがなく class ファイルだけの依存ライブラリでも、コンパイラはこの情報を読み取れます。

> 操作画面を追加予定：`String` への整数の代入でコンパイルに失敗し、文字列に直すとコンパイル、出力できること。

## 型が合っていても、値が入っているとは限らない

今度は起動引数からメッセージを受け取ります。引数があれば最初の値を使い、なければ何もしないコードです。

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

`lab/04-flow/broken` でコンパイルします。

```bash
javac -d out Main.java
```

```text
error: variable message might not have been initialized
```

名前は宣言され、型も合っています。それでも、`println` に到達する経路は一つではありません。

```text
args.length > 0 ?
├── true  → message = args[0] ──┐
└── false → message に代入しない ─┤
                               ▼
                       println(message)
```

`message` はローカル変数なので、オブジェクトのフィールドのように自動でデフォルト値が入るわけではありません。Java では、読み取る前に値が代入されていることを、言語で定めた解析の規則に従って確認できる必要があります。これを**確実な代入（definite assignment）**と呼びます。

「起動時には必ず引数を渡す」と決めていても、コンパイラはその約束を前提にできません。ソースコードには、代入せずに読み取りまで進む分岐が残っています。

`lab/04-flow/fixed` では、もう一方の分岐にも代入を加えます。

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

それぞれ `Alice` と `Hello, compiler!` が出力されます。コンパイルできるのは、コンパイラがあらかじめ二回試しに実行したからではありません。どちらの分岐でも明示的に代入しているからです。

> 操作画面を追加予定：`else` がない場合の確実な代入のエラーと、両分岐で代入した後の二通りの実行結果。

## IOException の検査と、ファイルの読み取りは別の段階

次はファイルからメッセージを読みます。`lab/05-checked/broken` のコードです。

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

診断は次のように変わります。

```text
error: unreported exception IOException; must be caught or declared to be thrown
```

ファイルを読もうとして何か問題が起きたようにも見えますが、そうではありません。コンパイラが見ているのは `Files.readString` のメソッド宣言です。このメソッドは `IOException` を投げる可能性を宣言しており、呼び出す側にも、例外に関する言語の規則が適用されます。

`IOException` は**検査例外**です。ここでは `try/catch` で捕捉するか、呼び出し元のメソッドの `throws` に宣言して、さらに呼び出し元へ伝わり得ることを示す必要があります。すべての例外にこの規則があるわけではありません。後ほど見る配列の範囲外アクセスの例外には、この指定は要求されません。

この実験では後者を選び、読み取りに失敗した場合の例外をそのまま外へ伝えます。`lab/05-checked/fixed` のコードです。

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

今度はコンパイルできます。`throws IOException` はファイルを修復したわけでも、読んだわけでもなく、読み取りの成功を保証するものでもありません。このメソッド内では例外を捕捉せず、外へ伝わり得ることを宣言しただけです。

`message.txt` が実際に必要になるのは実行時です。実験用の `with-file` ディレクトリには、`Hello, file!` と書いたファイルを用意してあります。一方、`fixed` にはありません。コンパイル後、`fixed` から `with-file` に移動して起動します。

```bash
cd ../with-file
java -cp ../fixed/out Main
```

出力は `Hello, file!` です。次に、メッセージファイルのないディレクトリに戻ります。再コンパイルはしません。

```bash
cd ../fixed
java -cp out Main
```

同じ `Main.class` でも、今度は `java.nio.file.NoSuchFileException: message.txt` になります。`NoSuchFileException` は `IOException` の一種なので、先ほどの宣言に含まれる失敗です。

なお、この `message.txt` はプロセスのカレントディレクトリを基準に探します。classpath から探すのではありません。`-cp` はクラスの場所を伝える指定であり、`Files.readString` に渡す相対パスの基準を変えるものではありません。

> 操作画面を追加予定：例外を宣言しないとコンパイルに失敗し、`throws` を加えると成功すること。同じ class ファイルでも、メッセージファイルの有無で実行結果が変わること。

**コンパイラが確かめるのは、例外を捕捉するか、外へ伝えるかがコードに示されていることです。実際のファイルアクセスは実行時に起こります。** 検査例外を「コンパイル中に投げられる例外」と捉えると、この二つの段階が混ざってしまいます。

## コンパイル成功の意味：型として正しくても、入力次第で失敗する

分岐まで確認できるなら、危険な操作もすべてコンパイラが見つけてくれそうに思えます。では、最初の起動引数をそのまま使う次のコードはどうでしょうか。`lab/06-runtime/valid` にあります。

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

コンパイルは通り、`Alice` と出力されます。今度は引数を渡さずに起動します。

```bash
java -cp out Main
```

次の例外になります。

```text
java.lang.ArrayIndexOutOfBoundsException: Index 0 out of bounds for length 0
```

コンパイラは、`args` が `String[]` で、添字の `0` が整数であり、要素を読み取った結果を `String` に代入できることを確認できます。しかし、今回の実行で配列に最初の要素があるかどうかは、実行時に確認する条件です。

確実な代入の検査と矛盾するわけではありません。ローカル変数が読み取り前に代入されているかを規則に従って調べるのは、Java が要求するコンパイル時の検査です。一方、配列アクセスの添字が範囲内かどうかは、実行時に検査します。**コンパイル成功は、所定のコンパイル時検査を通ったという意味であり、あらゆる入力や実行環境で正しく動く証明ではありません。**

修正方法は、確実な代入の実験ですでに使っています。`args.length` を確認して、最初の要素を使うか、デフォルトのメッセージを使うかを決めればよいのです。不要なキャストを加えたり、classpath を変更したりしても、起動引数がない問題は解決しません。

> 操作画面を追加予定：同じコンパイル結果を使って、引数があれば成功し、なければ配列の範囲外アクセスになること。

## 診断から、コンパイラが確かめたいことを読み取る

ここまでの検査を、診断を読むためのモデルとしてまとめます。実験を理解するための整理であり、`javac` の内部処理や診断が必ずこの順番になる、という図ではありません。

```text
ソースコード
 │
 ├── 構文を読み取れるか？             セミコロンがない
 ├── 名前を宣言に結び付けられるか？   message が宣言されていない
 ├── この型をこのように使えるか？     int を String に代入している
 ├── 読み取り前に確実に代入されるか？ 代入しない分岐がある
 └── 検査例外を捕捉、または宣言したか？ IOException を扱っていない
 │
 ▼
class ファイル → java で起動 → 実際の引数と環境で実行
```

次に IDE でエラー表示を見たら、まず二つを切り分けてみてください。**コンパイル時に規則違反を指摘されているのか、それとも実行してから失敗したのか。診断が示すのは、構文、名前、型、制御の流れ、例外の宣言のどれか。**

前回はクラスをどこから見つけるか、今回はそのクラスの使い方をコンパイラがどう確かめるかを見ました。次にたどりたいのは、その結果としてできた class ファイルに、どんな宣言や操作が残るのか、という問いです。

## 参考資料

- [JDK 21：javac と宣言の探索](https://docs.oracle.com/en/java/javase/21/docs/specs/man/javac.html)
- [JLS 21 §14.4：ローカル変数の宣言](https://docs.oracle.com/javase/specs/jls/se21/html/jls-14.html#jls-14.4)
- [JLS 21 §6.5.6.1：単純な式の名前](https://docs.oracle.com/javase/specs/jls/se21/html/jls-6.html#jls-6.5.6.1)
- [JLS 21 §5.2：代入コンテキスト](https://docs.oracle.com/javase/specs/jls/se21/html/jls-5.html#jls-5.2)
- [JLS 21 §15.12.2：コンパイル時のメソッドの特定](https://docs.oracle.com/javase/specs/jls/se21/html/jls-15.html#jls-15.12.2)
- [JLS 21 第 16 章：確実な代入](https://docs.oracle.com/javase/specs/jls/se21/html/jls-16.html)
- [JLS 21 §11.2：コンパイル時の例外検査](https://docs.oracle.com/javase/specs/jls/se21/html/jls-11.html#jls-11.2)
- [JDK 21：Files.readString](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/file/Files.html#readString(java.nio.file.Path))
- [JLS 21 §15.10.4：実行時の配列アクセスの評価](https://docs.oracle.com/javase/specs/jls/se21/html/jls-15.html#jls-15.10.4)
