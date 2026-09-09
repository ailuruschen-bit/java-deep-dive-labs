#!/usr/bin/env bash

set -euo pipefail

lab_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_root="$lab_root/build"

rm -rf "$build_root"
mkdir -p \
  "$build_root/basic" \
  "$build_root/punctuation" \
  "$build_root/greeting" \
  "$build_root/app" \
  "$build_root/loader"

javac \
  -d "$build_root/basic" \
  "$lab_root/src/basic/dev/deepdive/basic/Hello.java"

javac \
  -d "$build_root/punctuation" \
  "$lab_root/src/punctuation/dev/deepdive/punctuation/Punctuation.java"

javac \
  -cp "$build_root/punctuation" \
  -d "$build_root/greeting" \
  "$lab_root/src/greeting/dev/deepdive/greeting/Greeting.java"

javac \
  -cp "$build_root/greeting:$build_root/punctuation" \
  -d "$build_root/app" \
  "$lab_root/src/app/dev/deepdive/app/Main.java"

javac \
  -d "$build_root/loader" \
  "$lab_root/src/loader/dev/deepdive/loader/DirectoryClassLoader.java" \
  "$lab_root/src/loader/dev/deepdive/loader/LoaderDemo.java"

echo "Compiled class files:"
find "$build_root" -name '*.class' -print
