#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────
# install.sh — Instala skills deste acervo público no seu projeto
#
# Uso:
#   ./install.sh /caminho/para/seu/projeto
#   (Se omitir o caminho, instala no diretório atual)
# ─────────────────────────────────────────────────────────────────

TARGET_DIR="$(cd "${1:-.}" && pwd)"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📦 Instalando skills públicas em: $TARGET_DIR"

mkdir -p "$TARGET_DIR/.agents/skills" "$TARGET_DIR/.claude/skills"

# Bugpool
echo "  -> Instalando bugpool..."
rm -rf "$TARGET_DIR/.agents/skills/bugpool"
cp -r "$SOURCE_DIR/skills/bugpool" "$TARGET_DIR/.agents/skills/"
CLAUDE_LINK="$TARGET_DIR/.claude/skills/bugpool"
if [ -d "$CLAUDE_LINK" ] && [ ! -L "$CLAUDE_LINK" ]; then
  rm -rf "$CLAUDE_LINK"   # cópia real antiga: substitui pelo symlink
fi
ln -sfn "../../.agents/skills/bugpool" "$CLAUDE_LINK"

# Remove o slash command legado da 1.x (o skill já expõe /bugpool)
LEGACY_COMMAND="$TARGET_DIR/.claude/commands/bugpool.md"
if [ -f "$LEGACY_COMMAND" ]; then
  echo "  -> Removendo command legado da 1.x: .claude/commands/bugpool.md"
  rm -f "$LEGACY_COMMAND"
fi

echo "✅ Instalação concluída com sucesso!"
echo "   Disponível via slash command: /bugpool"
