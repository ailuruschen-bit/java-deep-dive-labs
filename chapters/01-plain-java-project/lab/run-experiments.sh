#!/usr/bin/env bash

set -euo pipefail

lab_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_root="$lab_root/build"

"$lab_root/compile.sh"

echo
echo "1. Run a source file with the Java 21 source-file mode:"
java "$lab_root/src/basic/dev/deepdive/basic/Hello.java"

echo
echo "2. Inspect the compiled bytecode instructions:"
javap -cp "$build_root/basic" -c dev.deepdive.basic.Hello

echo
echo "3. Run a class from the default class path:"
(cd "$build_root/basic" && java dev.deepdive.basic.Hello)

echo
echo "4. Run classes distributed across three class path roots:"
java \
  -cp "$build_root/app:$build_root/greeting:$build_root/punctuation" \
  dev.deepdive.app.Main

echo
echo "5. Omit the main class root and observe the expected failure:"
set +e
java \
  -cp "$build_root/greeting:$build_root/punctuation" \
  dev.deepdive.app.Main
missing_main_exit_code=$?
set -e
echo "exit code: $missing_main_exit_code"

echo
echo "6. Omit a dependency root and observe the expected failure:"
set +e
java \
  -cp "$build_root/app:$build_root/greeting" \
  dev.deepdive.app.Main
missing_dependency_exit_code=$?
set -e
echo "exit code: $missing_dependency_exit_code"

if [[ $missing_main_exit_code -eq 0 || $missing_dependency_exit_code -eq 0 ]]; then
  echo "An expected class path failure did not occur." >&2
  exit 1
fi

echo
echo "7. Load the same distributed classes with a small custom class loader:"
java \
  -cp "$build_root/loader" \
  dev.deepdive.loader.LoaderDemo \
  dev.deepdive.app.Main \
  "$build_root/app" \
  "$build_root/greeting" \
  "$build_root/punctuation"
