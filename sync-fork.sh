#!/bin/bash
# Sincroniza tu fork con el repo oficial de goose y re-aplica tus cambios
# Uso: ./sync-fork.sh

set -e

cd "$(dirname "$0")"
source bin/activate-hermit

echo "📥 Fetching upstream..."
git fetch upstream

echo "🔄 Updating main from upstream..."
git checkout main
git merge upstream/main
git push origin main

echo "🔧 Rebasing feat/at-autocomplete onto main..."
git checkout feat/at-autocomplete
git rebase main

echo "🏗️  Building..."
cargo build --release -p goose-cli

echo "✅ Tests..."
cargo test -p goose-cli --lib -- expand completion 2>&1 | tail -5

echo "🚀 Pushing..."
git push origin feat/at-autocomplete --force-with-lease

echo ""
echo "✅ Todo listo! Tu fork está actualizado y recompilado."
echo "   El binario está en: $(pwd)/target/release/goose"
