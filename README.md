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

### 1. [`bugpool`](./skills/bugpool/SKILL.md) — Auto-revisão de PR antes do humano
> **Comando:** `/bugpool [pr-number|pr-url] [--review-only] [--allow-foreign]` | **Versão:** `2.0.0`

Revisa o **seu próprio** Pull Request antes de um revisor humano gastar tempo nele: corrige o que é claramente corrigível, mantém nits fora do PR e posta apenas o que exige decisão do autor.

* **Painel de revisores:** um router faz a passada crítica completa e delega lentes especialistas (`architecture`, `qa`, `stack`, `security`) quando necessário. Diffs com mais de 150 linhas ou que tocam áreas sensíveis (auth, migrations, concorrência, pagamentos, deploy) sempre recebem pelo menos uma lente, independentemente da nota do router.
* **Escada de modelos:** router e lentes em `sonnet`, escalada em `opus` só para divergências CRITICAL/HIGH. O router nunca roda em `haiku`.
* **Duas passadas:** a Passada 1 (segurança, confiabilidade, corretude, APIs alucinadas) tem prioridade. A Passada 2 (qualidade, testes, performance, complexidade SIZE-1..6) só é auto-corrigida quando não resta bloqueador.
* **Contexto do projeto:** os revisores leem `AGENTS.md`/`CLAUDE.md` e checam APIs contra a versão instalada dos frameworks.
* **Política de postagem:**
  | Item | Destino |
  | --- | --- |
  | Acionável (claro e localizado) | corrigido localmente, commitado, push único por rodada |
  | Nit | só no comentário-resumo |
  | Ambíguo | comentário inline, numa única review |
  | Thread de bot existente | corrigida e resolvida, ou respondida e resolvida, ou mantida aberta |
  | Thread com qualquer humano | **nunca** tocada |
* **Imunidade humana endurecida:** o cabeçalho `🤖 Automated comment by` só é confiável quando o comentário vem da sua própria conta. Na dúvida, o comentário conta como humano.
* **Safety gate local:** detecta o gerenciador pelo lockfile e roda **typecheck, lint e testes, quando disponíveis** (testes relacionados quando o runner suporta). Sem gate, sem auto-fix. Em falha, rollback por SHA e o item vira ambíguo.
* **Pré-condições:** o auto-fix só roda com árvore limpa, na branch do PR, com o HEAD igual ao do PR e em PRs seus (ou com `--allow-foreign`). Se alguma falhar, o run vira `--review-only`.
* **Loop idempotente:** até 3 rodadas (a partir da segunda, revisa só os próprios fixes), com estado guardado no comentário-resumo. Rodar de novo no mesmo HEAD não posta nada.
* **Resumo sticky único:** veredito, **Quality Score (0–100)** por dimensão, scope drift e histórico colapsado. A review sempre usa o evento `COMMENT`: o bugpool nunca aprova nem bloqueia o PR no GitHub.

#### ⚠️ Breaking changes na 2.0.0
- `commands/bugpool.md` foi removido: o próprio skill expõe `/bugpool`. Reinstale para limpar o arquivo antigo (`install.sh` remove sozinho; com `npx skills`, apague `.claude/commands/bugpool.md`).
- O skill não é mais carregado automaticamente (`disable-model-invocation: true`): use `/bugpool` explicitamente.
- O router passou de `haiku` para `sonnet`.
- Achados novos não viram mais um comentário cada: só os ambíguos são postados.
- O auto-fix exige as pré-condições acima. PRs de terceiros são review-only por padrão.

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
- [`qa-swarm`](https://github.com/pauldambra/dotfiles/tree/main/ai/skills/qa-swarm) e [`review-triage`](https://github.com/pauldambra/dotfiles/tree/main/ai/skills/review-triage), de Paul D'Ambra: router com lentes, achados estruturados, resumo sticky, imunidade humana, responder antes de resolver.
- [`yooh-digital/ai-workflow`](https://github.com/yooh-digital/ai-workflow): revisão em duas passadas, SIZE-1..6, fricção construtiva, scope drift, quality score.

---

## 🛡️ Filosofia deste Acervo
1. **Sem Amarras de Ferramentas:** Nada de acoplamentos com MCPs específicos (Plane, context-mode, Jira, etc.). Tudo usa ferramentas padrão (`git`, `gh`).
2. **Respeito ao Humano:** A IA auxilia e limpa o trabalho repetitivo, mas decisões de arquitetura e conversas com humanos são sempre preservadas.
3. **Custo Consciente:** Os modelos mais caros só são chamados quando estritamente necessários.
