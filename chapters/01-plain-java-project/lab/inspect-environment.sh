#!/usr/bin/env bash

set -u

echo "JAVA_HOME=${JAVA_HOME-<unset>}"

echo
echo "java command:"
command -v java || echo "java was not found"

echo
echo "java version:"
java -version 2>&1 || true

echo
echo "javac command:"
if command -v javac >/dev/null 2>&1; then
  command -v javac
else
  echo "javac was not found"
fi

echo
echo "javac version:"
if command -v javac >/dev/null 2>&1; then
  javac -version 2>&1
else
  echo "javac was not found"
fi

echo
echo "java.home property:"
java -XshowSettings:properties -version 2>&1 \
  | awk -F ' = ' '/^[[:space:]]*java\.home = / { print $2 }'
