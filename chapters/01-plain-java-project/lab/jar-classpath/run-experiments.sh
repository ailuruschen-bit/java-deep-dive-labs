#!/usr/bin/env bash
set -euo pipefail

# 设置仅作用于本脚本，不修改用户终端或其他实验。
unset CLASSPATH JAVA_TOOL_OPTIONS JDK_JAVA_OPTIONS JDK_JAVAC_OPTIONS _JAVA_OPTIONS
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mode="${1:---verify}"
if [[ $# -gt 1 || ( "$mode" != --prepare && "$mode" != --verify ) ]]; then
  echo "用法：$0 [--prepare|--verify]" >&2
  exit 2
fi

if [[ -n "${JAVA_HOME:-}" ]]; then
  export PATH="$JAVA_HOME/bin:$PATH"
elif [[ -x /usr/libexec/java_home ]]; then
  export JAVA_HOME="$(/usr/libexec/java_home -v 21)"
  export PATH="$JAVA_HOME/bin:$PATH"
fi
for tool in java javac jar; do
  version="$("$tool" --version 2>&1)"
  if [[ ! "$version" =~ ^(java|openjdk|javac|jar)[[:space:]]21([.]|[[:space:]]|$) ]]; then
    echo "需要同一套 JDK 21 工具，请设置 JAVA_HOME。检测到：$version" >&2
    exit 1
  fi
done

if [[ "$mode" == --prepare ]]; then
  work_dir="$lab_dir/work"
  # 已有录制产物时停止，不覆盖或删除用户的实验状态。
  for output in lib001 lib002 lib app-classes app.jar app-manifest.mf; do
    if [[ -e "$work_dir/$output" || -L "$work_dir/$output" ]]; then
      echo "已有实验目录或文件：$work_dir/$output；未执行准备，也未清理任何内容。" >&2
      exit 1
    fi
  done
else
  verification_dir="$(mktemp -d "${TMPDIR:-/tmp}/java-jar-verify.XXXXXX")"
  work_dir="$verification_dir/work"
  mkdir -p "$work_dir"
  cp -R "$lab_dir/work/src" "$work_dir/src"
  echo "隔离验证目录（保留供检查）：$verification_dir"
fi

mkdir -p "$work_dir/lib001" "$work_dir/lib002" "$work_dir/lib"
javac -d "$work_dir/lib001" "$lab_dir/provider-src/greeting/dev/deepdive/greeting/Greeting.java"
javac -d "$work_dir/lib002" "$lab_dir/provider-src/punctuation/dev/deepdive/punctuation/Punctuation.java"

if [[ "$mode" == --prepare ]]; then
  echo "截图初始环境已准备：$work_dir"
  echo "仅生成两份依赖 class；尚未打包、编译应用或复制清单。"
  exit 0
fi

expect_greeting() {
  local output
  output="$("$@")"
  [[ "$output" == 'Hello, classpath!' ]] || {
    echo "输出与预期不同：$output" >&2
    exit 1
  }
  printf '%s\n' "$output"
}

cd "$work_dir"
jar --create --file lib/greeting.jar -C lib001 .
jar --create --file lib/punctuation.jar -C lib002 .
entries="$(jar --list --file lib/greeting.jar)"
[[ "$entries" == *'dev/deepdive/greeting/Greeting.class'* ]]
[[ "$entries" == *'META-INF/MANIFEST.MF'* ]]
[[ "$entries" != *'lib001/'* ]]
[[ -f lib001/dev/deepdive/greeting/Greeting.class ]]
echo '已核对 JAR 内部路径、自动清单与保留的原 class。'

javac -cp 'lib/greeting.jar:lib/punctuation.jar' -d app-classes \
  src/dev/deepdive/app/Main.java \
  src/dev/deepdive/app/MessageService.java
expect_greeting java -cp 'app-classes:lib/greeting.jar:lib/punctuation.jar' dev.deepdive.app.Main
jar --create --file app.jar -C app-classes .
expect_greeting java -cp 'app.jar:lib/greeting.jar:lib/punctuation.jar' dev.deepdive.app.Main

# 普通应用 JAR 尚无入口属性，不能直接使用 -jar 启动。
if output="$(java -jar app.jar 2>&1)"; then
  echo '未配置入口却启动成功，结果不符合预期。' >&2
  exit 1
fi
[[ "$output" == *'no main manifest attribute'* ]]
echo '已核对未配置入口时的启动失败。'

cp "$lab_dir/app-manifest.mf" app-manifest.mf
jar --create --file app.jar --manifest app-manifest.mf -C app-classes .
expect_greeting java -jar app.jar
mkdir -p "$verification_dir/manifest-check"
(
  cd "$verification_dir/manifest-check"
  jar --extract --file "$work_dir/app.jar" META-INF/MANIFEST.MF
  grep -Fq 'Main-Class: dev.deepdive.app.Main' META-INF/MANIFEST.MF
  grep -Fq 'Class-Path: lib/greeting.jar lib/punctuation.jar' META-INF/MANIFEST.MF
)
cd "$verification_dir"
expect_greeting java -jar work/app.jar
echo '全部验证通过；录制用 work 目录未被执行或修改。'
