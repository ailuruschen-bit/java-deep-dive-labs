#!/usr/bin/env bash
set -euo pipefail

# 只在临时目录编译和运行，不改变作者用于截图的实验现场。
lab_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
verification_dir="$(mktemp -d "${TMPDIR:-/tmp}/java-compiler-verify.XXXXXX")"

# 避免当前终端注入的类路径或 JVM 参数影响实验。
unset CLASSPATH JAVA_TOOL_OPTIONS _JAVA_OPTIONS JDK_JAVA_OPTIONS JDK_JAVAC_OPTIONS

if [[ -n "${JAVA_HOME:-}" ]]; then
    compiler_java="$JAVA_HOME/bin/java"
    compiler_javac="$JAVA_HOME/bin/javac"
else
    compiler_java="$(command -v java)"
    compiler_javac="$(command -v javac)"
fi

java_version="$("$compiler_java" -version 2>&1)"
javac_version="$("$compiler_javac" -version 2>&1)"
if ! [[ "$java_version" =~ version\ \"21[.\"] ]] || ! [[ "$javac_version" =~ ^javac\ 21([.]|$) ]]; then
    printf '需要 JDK 21，当前环境为：\n%s\n%s\n' "$java_version" "$javac_version" >&2
    printf '请切换 JAVA_HOME 后重试；未改动实验源码或截图目录。\n' >&2
    exit 1
fi

passed=0

fail() {
    printf 'FAIL: %s\n验证文件保留在：%s\n' "$1" "$verification_dir" >&2
    exit 1
}

pass() {
    passed=$((passed + 1))
    printf 'PASS: %s\n' "$1"
}

expect_compile_failure() {
    local case_name="$1"
    local diagnostic="$2"
    local case_dir="$verification_dir/$case_name-broken"
    local result=0
    mkdir -p "$case_dir/out"
    "$compiler_javac" -J-Duser.language=en -J-Duser.country=US -encoding UTF-8 \
        -d "$case_dir/out" "$lab_dir/$case_name/broken/Main.java" \
        > "$case_dir/diagnostic.txt" 2>&1 || result=$?
    [[ "$result" -ne 0 ]] || fail "$case_name 应当编译失败"
    # 使用系统自带的 grep，使验证脚本不依赖额外安装的搜索工具。
    grep -Fq -- "$diagnostic" "$case_dir/diagnostic.txt" || fail "$case_name 诊断不符合预期"
    [[ ! -e "$case_dir/out/Main.class" ]] || fail "$case_name 不应生成 Main.class"
    pass "${case_name}：编译失败且诊断匹配"
}

compile_success() {
    local case_name="$1"
    local source_variant="$2"
    local case_dir="$verification_dir/$case_name-$source_variant"
    mkdir -p "$case_dir/out"
    "$compiler_javac" -J-Duser.language=en -J-Duser.country=US -encoding UTF-8 \
        -d "$case_dir/out" "$lab_dir/$case_name/$source_variant/Main.java" \
        > "$case_dir/compile.txt" 2>&1 || fail "$case_name/$source_variant 应当编译成功"
    [[ -f "$case_dir/out/Main.class" ]] || fail "$case_name/$source_variant 缺少编译产物"
    pass "${case_name}/${source_variant}：编译成功"
}

expect_output() {
    local label="$1"
    local class_dir="$2"
    local working_dir="$3"
    local expected="$4"
    shift 4
    local output
    output="$(cd "$working_dir" && "$compiler_java" -Duser.language=en -Duser.country=US \
        -cp "$class_dir" Main "$@")" || fail "$label 应当正常退出"
    [[ "$output" == "$expected" ]] || fail "$label 输出不符合预期"
    pass "$label"
}

expect_runtime_failure() {
    local label="$1"
    local class_dir="$2"
    local working_dir="$3"
    local diagnostic="$4"
    local result=0
    local log_file="$working_dir/runtime-error.txt"
    (cd "$working_dir" && "$compiler_java" -Duser.language=en -Duser.country=US \
        -cp "$class_dir" Main) > "$log_file" 2>&1 || result=$?
    [[ "$result" -ne 0 ]] || fail "$label 应当运行失败"
    grep -Fq -- "$diagnostic" "$log_file" || fail "$label 异常不符合预期"
    pass "$label"
}

expect_compile_failure 01-syntax "';' expected"
expect_compile_failure 02-name 'cannot find symbol'
expect_compile_failure 03-type 'incompatible types: int cannot be converted to String'
expect_compile_failure 04-flow 'variable message might not have been initialized'
expect_compile_failure 05-checked 'unreported exception IOException; must be caught or declared to be thrown'

for case_name in 01-syntax 02-name 03-type 04-flow 05-checked; do
    compile_success "$case_name" fixed
done
compile_success 06-runtime valid

for case_name in 01-syntax 02-name; do
    expect_output "$case_name 修复后正常运行" "$verification_dir/$case_name-fixed/out" \
        "$verification_dir/$case_name-fixed" 'Hello, compiler!'
done
expect_output '03-type 修复后输出字符串' "$verification_dir/03-type-fixed/out" \
    "$verification_dir/03-type-fixed" '42'
expect_output '04-flow 无参数时使用默认值' "$verification_dir/04-flow-fixed/out" \
    "$verification_dir/04-flow-fixed" 'Hello, compiler!'
expect_output '04-flow 有参数时使用参数' "$verification_dir/04-flow-fixed/out" \
    "$verification_dir/04-flow-fixed" 'Alice' 'Alice'

mkdir -p "$verification_dir/05-checked-with-file" "$verification_dir/05-checked-without-file"
cp "$lab_dir/05-checked/with-file/message.txt" "$verification_dir/05-checked-with-file/message.txt"
expect_output '05-checked 当前目录有文件时成功' "$verification_dir/05-checked-fixed/out" \
    "$verification_dir/05-checked-with-file" 'Hello, file!'
expect_runtime_failure '05-checked 当前目录无文件时出现 NoSuchFileException' \
    "$verification_dir/05-checked-fixed/out" "$verification_dir/05-checked-without-file" \
    'java.nio.file.NoSuchFileException: message.txt'

expect_output '06-runtime 有参数时成功' "$verification_dir/06-runtime-valid/out" \
    "$verification_dir/06-runtime-valid" 'Alice' 'Alice'
expect_runtime_failure '06-runtime 无参数时出现 ArrayIndexOutOfBoundsException' \
    "$verification_dir/06-runtime-valid/out" "$verification_dir/06-runtime-valid" \
    'java.lang.ArrayIndexOutOfBoundsException'

printf '\nSUMMARY: %s 项检查全部通过（JDK 21）。\n' "$passed"
printf '验证源码来自：%s\n' "$lab_dir"
printf '独立输出及诊断保留在：%s\n' "$verification_dir"
printf '未在实验源码旁生成 class 文件，未清理或覆盖作者的实操目录。\n'
