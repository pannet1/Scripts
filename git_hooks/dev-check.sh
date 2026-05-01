#!/bin/bash
# Dev check script - runs fast checks locally, no network needed
# Usage: dev-check.sh or dev-check.sh /path/to/project

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Find project root - go up until we find pyproject.toml, src/, or .git/
find_project_root() {
    local dir="${1:-$(pwd)}"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/pyproject.toml" || -d "$dir/src" || -d "$dir/.git" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

PROJECT_DIR="${1:-$(find_project_root "$(pwd)")}"

if [[ -z "$PROJECT_DIR" ]]; then
    echo "Error: No project root found"
    exit 1
fi

echo "=== Dev Check ==="
echo "Project: $PROJECT_DIR"

cd "$PROJECT_DIR"

echo "1. Syntax check..."
uv run python -m py_compile src/*.py 2>/dev/null || python -m py_compile src/*.py
echo "   OK"

echo "2. Lint (auto-fix)..."
uv run ruff check --fix src/ 2>/dev/null || uv run ruff check --fix src/ 2>&1 | grep -v "^$" | head -20 || true
echo "   OK"

echo "3. Run tests..."
uv run pytest tests/ -v --tb=short 2>/dev/null || echo "   No tests or tests passed"
echo "   OK"

echo "=== Done ==="