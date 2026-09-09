#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for chapter_dir in "$repo_root"/chapters/[0-9][0-9]-*; do
  [[ -d "$chapter_dir" ]] || continue
  chapter_name="$(basename "$chapter_dir")"
  echo "==> Verifying $chapter_name"
  (cd "$chapter_dir" && ./mvnw --batch-mode test)
done

echo "All chapter labs passed."
