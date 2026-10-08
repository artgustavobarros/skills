# 🌟 Public Agent Skills (Acervo Público de Skills)

Repositório público com habilidades especializadas para agentes de codificação de IA (**Claude Code**, **Antigravity**, **Cursor**, etc.), construídas com rigor metodológico e **zero ruído corporativo**.

Compatível nativamente com o padrão aberto do **[skills.sh](https://skills.sh/)** e o CLI `npx skills`.

---

## 🚀 Como Instalar com `npx skills` (Padrão Oficial)

Você pode instalar qualquer skill diretamente em qualquer projeto com um único comando:

### Instalar no projeto atual:
```bash
npx skills add artgustavobarros/skills --skill bugpool
```
*(Ou pelo link completo: `npx skills add https://github.com/artgustavobarros/skills --skill bugpool`)*

### Instalar globalmente na sua máquina (disponível em todos os projetos):
```bash
npx skills add artgustavobarros/skills --skill bugpool -g
```

### Listar todas as skills disponíveis neste repositório:
```bash
npx skills add artgustavobarros/skills --list
```

---

## 📦 Skills Disponíveis

### 1. [`bugpool`](./skills/bugpool/SKILL.md) — Revisão de PR multi-lente com triagem segura
> **Comando:** `/bugpool [pr-number|pr-url] [--local] [--base <ref>] [--dry-run] [--push]` | **Versão:** `3.0.0`

Revisa um Pull Request (ou a sua branch antes de abrir o PR), valida cada achado antes de reportar, tria threads de bots sem nunca tocar em conversas humanas e, opcionalmente, corrige o que é claro num worktree isolado.

* **Pré-passe determinístico:** lint (só check, nunca `--fix`), typecheck e testes relacionados aos arquivos alterados, em segundos. O resultado vira evidência para as lentes.
* **Lentes core sempre ligadas:** `correctness-stack` e `security` rodam em todo review (`sonnet`). O router (`haiku`) só **adiciona** `qa` e `architecture`, nunca remove uma lente core. Achado CRITICAL não interrompe as outras lentes.
* **Validação que tenta refutar:** achados MEDIUM+ são deduplicados e checados por um validador (`sonnet`; `opus` para segurança CRITICAL/HIGH). O que não tem prova em `arquivo:linha` é descartado.
* **Modos:** PR, `--local` (sem PR, revisa branch + working tree) e `--dry-run` (sem escrita no GitHub, sem commit, sem editar arquivos).
* **Auto-fix seguro:** recusa working tree sujo, corrige num git worktree isolado, gate = typecheck + lint check + testes relacionados, um commit único e push só com `--push`. Nunca roda `git checkout --`/`reset` na sua árvore.
* **Imunidade humana:** thread com qualquer comentário humano nunca é corrigida, respondida nem resolvida. O cabeçalho do bot só conta se estiver no início do comentário.
* **Resumo sticky único** com veredito e score (`100 − Σ deduções`), postado por script (quebras de linha reais).
* **Loop limitado:** até 2 rodadas extras após fixes, parando quando não surge achado novo MEDIUM+.
* **Avaliação embutida:** `evals/` traz o harness (bugs semeados + Claude headless) usado para medir o skill.

| Cenário (seeds) | Revisor único (baseline) | bugpool 3.0.0 |
| :--- | :--- | :--- |
| dev (5) | 3/5 · US$0,19 | 5/5 · US$1,12 |
| held-out (5) | 4/5 · US$0,17 | 5/5 · US$1,69 |
| limpo (falsos positivos) | 0 | 0 |

#### ⚠️ Breaking changes na 3.0.0
- `commands/bugpool.md` foi removido: o próprio skill expõe `/bugpool` (o `install.sh` apaga o arquivo antigo; com `npx skills`, apague `.claude/commands/bugpool.md`).
- Auto-fix não roda mais com working tree sujo e não dá push sem `--push`.
- Achados novos aparecem no resumo sticky e no terminal; só threads existentes recebem respostas.

---

## 🛠️ Métodos Alternativos de Instalação

### Via script instalador local:
```bash
./install.sh /caminho/para/seu/projeto
```

### Cópia manual:
```bash
cp -r skills/bugpool /caminho/para/projeto/.agents/skills/
ln -s ../../.agents/skills/bugpool /caminho/para/projeto/.claude/skills/bugpool
```

---

## 🙏 Créditos

O `bugpool` é derivado e adaptado de:
- [`qa-swarm`](https://github.com/pauldambra/dotfiles/tree/main/ai/skills/qa-swarm) e [`review-triage`](https://github.com/pauldambra/dotfiles/tree/main/ai/skills/review-triage), de Paul D'Ambra: router com lentes, achados estruturados, resumo sticky, imunidade humana.
- [`yooh-digital/ai-workflow`](https://github.com/yooh-digital/ai-workflow): revisão em duas passadas, fricção construtiva, scope drift, rubrica SIZE.

---

## 🛡️ Filosofia deste Acervo
1. **Sem Amarras de Ferramentas:** Nada de acoplamentos com MCPs específicos (Plane, context-mode, Jira, etc.). Tudo usa ferramentas padrão (`git`, `gh`).
2. **Respeito ao Humano:** A IA auxilia e limpa o trabalho repetitivo, mas decisões de arquitetura e conversas com humanos são sempre preservadas.
3. **Custo Consciente:** Os modelos mais caros só são chamados quando estritamente necessários.
