## 1. Estrutura e empacotamento

- [x] 1.1 Criar `skills/bugpool/references/` com `size-rubric.md`, `quality-score.md` e `github-api.md` (vazios, com títulos)
- [x] 1.2 Reescrever o frontmatter do `SKILL.md`: `name`, `description` (sem IDs de modelo), `argument-hint: "[pr-number|pr-url] [--review-only] [--allow-foreign]"`, `disable-model-invocation: true`, `license` (placeholder até decidir a Open Question), `metadata.version: "2.0.0"`; remover o `version` do nível de cima
- [x] 1.3 Remover `commands/bugpool.md` e a pasta `commands/` se ficar vazia
- [x] 1.4 Corrigir o `install.sh`: tirar a cópia do command e a condição sempre verdadeira, remover o `.claude/commands/bugpool.md` legado com aviso, manter cópia + symlink

## 2. Referências

- [x] 2.1 `references/size-rubric.md`: SIZE-1..6 com numeração/limites da Yooh, regras de contagem, mapeamento BLOCK→HIGH / WARN→MEDIUM / INFO→LOW, regra "só código alterado" e LOW para arquivo legado
- [x] 2.2 `references/quality-score.md`: 8 dimensões e pesos, deduções −35/−25/−15/−5/−1, fórmula, faixas de nota, regra de veredito, exemplo trabalhado (HIGH em security → 95)
- [x] 2.3 `references/github-api.md`: `gh pr view`/`gh api user`/`gh pr checkout`; query de threads com filtro unresolved/non-outdated e truncamento em 1500 caracteres; refetch de corpo completo; review única via `--input review.json`; reply via `-F body=@file`; `resolveReviewThread`; upsert do sticky (busca, PATCH, criação); formato do marcador de estado; uso de `mktemp -d`

## 3. SKILL.md: preparação e pré-condições

- [x] 3.1 Seção de cabeçalho do bot e regra de narração `[bugpool] <passo> — <o quê>`
- [x] 3.2 Passo 0, parsing dos argumentos: número/URL do PR, `--review-only`, `--allow-foreign`
- [x] 3.3 Passo 1, contexto: `gh pr view` (incluindo author e headRefOid), parar se MERGED/CLOSED, `gh pr checkout` se a branch for diferente, `git fetch origin <base>`, diff contra `origin/<base>`, leitura do AGENTS.md/CLAUDE.md e do manifesto
- [x] 3.4 Passo 1b, idempotência: ler o marcador de estado do sticky; sair com "nada a fazer" se o HEAD for o mesmo e não houver thread nova
- [x] 3.5 Passo 1c, pré-condições do auto-fix (árvore limpa, branch, HEAD == headRefOid, autor == usuário do gh ou `--allow-foreign`), com queda para review-only informando o motivo
- [x] 3.6 Passo 1d, detecção do gate (lockfile → gerenciador; scripts typecheck/lint/test; "related" do vitest; fallback para AGENTS.md; sem gate → auto-fix desligado)
- [x] 3.7 Scope drift no Passo 1 (arquivos e commits vs título/corpo do PR)

## 4. SKILL.md: painel de revisão

- [x] 4.1 Tabela de papéis (router sonnet, lentes sonnet, escalada opus) e instrução explícita de usar o Agent com `model`, mais a regra de mapeamento quando o harness rejeita o alias (nunca haiku no router)
- [x] 4.2 Prompt do router: passada crítica completa + nota de perigo + `DELEGATION_PLAN`; gatilhos objetivos (>150 linhas ou caminho sensível → pelo menos uma lente, independentemente da nota)
- [x] 4.3 Prompts das lentes (architecture, qa, stack, security): "único revisor do escopo", sem sub-agents, contexto do projeto, verificação de API contra a versão instalada; lente stack com checklist derivado da stack detectada (React/Next condicional)
- [x] 4.4 Regra de escalada para opus em conflito CRITICAL/HIGH
- [x] 4.5 Formato `STRUCTURED_FINDINGS` com `pass`, `rule`, `reviewer`; checklist de fricção construtiva; escala única de severidade com mapeamento MUST/SHOULD/NIT; deduplicação e `convergent`

## 5. SKILL.md: triagem

- [x] 5.1 Busca de threads (referência a `github-api.md`) e regra de proveniência: Bot typename, lista de bots, cabeçalho só se o autor for o usuário do gh, dúvida conta como humano
- [x] 5.2 Imunidade humana: thread com qualquer humano → não edita, não responde, não resolve, só relata
- [x] 5.3 Critério de ACTIONABLE (4 condições; SIZE nunca) e escada NIT / PROMOTED / AMBIGUOUS (dúvida → AMBIGUOUS)
- [x] 5.4 Destino dos achados novos (acionável/promovido → fila de fix; NIT → resumo; AMBIGUOUS → review única inline; `line: general` → corpo da review) e das threads de bot existentes (fix → reply com SHA → resolve; NIT → reply → resolve; AMBIGUOUS → aberta); pular review de bot antiga
- [x] 5.5 Regra "responder antes de resolver" com tratamento de falha

## 6. SKILL.md: auto-fix e loop

- [x] 6.1 Ordem da fila: passada 1 primeiro; passada 2 só se não restar bloqueador CRITICAL/HIGH da passada 1
- [x] 6.2 Por fix: revalidar árvore limpa, registrar o SHA pré-fix, edição mínima, gate, commit `fix(bugpool): ...`; em falha, `git reset --hard <sha>` + `git clean -fd` e reclassificar como AMBIGUOUS
- [x] 6.3 Push único por rodada; respostas e resolves só depois do push dar certo; falha no push → relatar os SHAs locais e não tocar nas threads
- [x] 6.4 Loop: nova rodada só sobre o diff dos fixes; parar sem novos acionáveis, no teto de 3 rodadas, em MERGED/CLOSED ou em review-only
- [x] 6.5 Comportamento do `--review-only`: acionáveis postados como "suggested fix" junto dos ambíguos; nenhuma escrita local ou remota além da review e do sticky

## 7. SKILL.md: relatórios

- [x] 7.1 Template do sticky: marcador de estado oculto, veredito, score/nota, tabela só com os revisores que rodaram, scope drift, ações (SHAs), lista de NITs, histórico derivado do sticky anterior; evento sempre `COMMENT`
- [x] 7.2 Passo de score apontando para `references/quality-score.md`
- [x] 7.3 Relatório no terminal no idioma do usuário, com a contagem fechando e itens humanos/ambíguos com `file:line` e motivo
- [x] 7.4 Seção de degradação (sem PR → relatório só no terminal; Agent indisponível → revisão inline sinalizada como degradada; gh sem autenticação → parar)
- [x] 7.5 Revisão final do `SKILL.md`: inglês, sem nomes pessoais, <500 linhas, todas as referências linkadas com "quando ler"

## 8. README e atribuição

- [x] 8.1 Atualizar a seção do bugpool: versão 2.0.0, política de postagem, modos, escada de modelos real, gate "typecheck, lint e testes quando disponíveis"
- [x] 8.2 Seção "Breaking changes 2.0.0" (sem command, router em sonnet, só ambíguos postados, pré-condições) e instrução de reinstalação
- [x] 8.3 Seção de créditos com links para qa-swarm e review-triage (pauldambra/dotfiles) e yooh-digital/ai-workflow
- [x] 8.4 Remover dos "Métodos alternativos" o passo de cópia do command
- [ ] 8.5 Decidir a licença (Open Question) e aplicar: arquivo LICENSE + campo `license` do frontmatter

## 9. Validação

- [x] 9.1 `openspec validate harden-bugpool` e checagem de cada cenário dos specs contra o texto do `SKILL.md`
- [x] 9.2 Rodar `install.sh` num diretório temporário (instalação limpa e upgrade com o command antigo presente)
- [ ] 9.3 Reinstalar no book-manager e rodar `/bugpool <n> --review-only` em um PR mergeado; conferir que não houve escrita local e que a review e o sticky foram postados uma vez só
- [ ] 9.4 Rodar `/bugpool` de novo no mesmo PR e confirmar "nada a fazer" (idempotência)
- [ ] 9.5 Abrir um PR de teste com um bug plantado (ex.: `await` faltando) e um caso ambíguo; confirmar fix + push único + reply/resolve, o ambíguo postado e o comentário com cabeçalho falso de um "colega" tratado como humano
