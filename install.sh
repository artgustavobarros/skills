#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────
# install.sh — Instala skills deste acervo público no seu projeto
#
# Uso:
#   ./install.sh /caminho/para/seu/projeto
#   (Se omitir o caminho, instala no diretório atual)
# ─────────────────────────────────────────────────────────────────

TARGET_DIR="${1:-.}"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📦 Instalando skills públicas em: $TARGET_DIR"

# Cria pastas alvo
mkdir -p "$TARGET_DIR/.agents/skills"
mkdir -p "$TARGET_DIR/.claude/commands" 2>/dev/null || true
mkdir -p "$TARGET_DIR/.claude/skills" 2>/dev/null || true

# Instala Bugpool
echo "  -> Instalando bugpool..."
rm -rf "$TARGET_DIR/.agents/skills/bugpool"
cp -r "$SOURCE_DIR/skills/bugpool" "$TARGET_DIR/.agents/skills/"

# Link / cópia para Claude Code
if [ -d "$TARGET_DIR/.claude" ]; then
  cp "$SOURCE_DIR/commands/bugpool.md" "$TARGET_DIR/.claude/commands/" 2>/dev/null || true
  cd "$TARGET_DIR/.claude/skills" && ln -sf "../../.agents/skills/bugpool" bugpool 2>/dev/null || true
fi

echo "✅ Instalação concluída com sucesso!"
echo "   Disponível via slash command: /bugpool"
