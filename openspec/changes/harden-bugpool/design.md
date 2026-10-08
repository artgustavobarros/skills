## Context

O `bugpool` 1.1.0 é um único `SKILL.md` (381 linhas) que junta três fontes:

- **qa-swarm** (pauldambra/dotfiles): router, lentes, `STRUCTURED_FINDINGS`, resumo sticky.
- **review-triage** (pauldambra/dotfiles): imunidade humana, NIT/ACTIONABLE/AMBIGUOUS, responder antes de resolver.
- **Yooh ai-workflow**: revisão em duas passadas, SIZE-1..6, fricção construtiva, scope drift, quality score.

Ao juntar as três, várias proteções do review-triage se perderam. O skill também acrescentou comportamento perigoso (commit e push automáticos) sem as pré-condições necessárias. Nas fontes, cada skill tem um papel isolado (o qa-swarm só posta, o review-triage só tria). O bugpool faz os dois papéis, mais o auto-fix.

O que restringe o desenho:
- **Só `git` e `gh`**, sem MCP.
- **Portável entre harnesses:** no Claude Code o Agent aceita `model`; outros harnesses mapeiam os papéis por tier.
- **Instruções em markdown:** não há código executável. Cada "implementação" é uma instrução que o modelo segue, então as regras precisam ser verificáveis e sem ambiguidade.

## Goals / Non-Goals

**Goals:**
- Fluxo fechado e idempotente: todo achado e toda thread terminam em exatamente um destino.
- Nenhuma ação destrutiva sem pré-condição verificada, e nenhuma interação com threads humanas.
- Regras numéricas reproduzíveis (severidade, SIZE, score), alinhadas às fontes.
- Skill público neutro: sem nomes pessoais e sem assumir uma stack.

**Non-Goals:**
- Gerenciar CI, atualizar branch ou fazer merge (papel do ci-shepherd/pr-shepherd nas fontes).
- Separar o skill em vários (opção C da exploração). Fica para depois, se o tamanho exigir.
- Suítes de eval automatizadas. Haverá uma validação manual em PRs reais.
- Suporte a GitLab/Bitbucket.

## Decisions

### D1. Identidade: auto-revisão antes do humano
Acionáveis são corrigidos localmente e não postados; NITs ficam só no resumo; somente AMBIGUOUS vira comentário inline, em uma única review.
- *Por quê:* o PR recebe o mínimo de ruído, e o humano só vê o que exige decisão. Isso também fecha o buraco do 1.1.0 (achados novos sem thread).
- *Alternativa:* postar tudo como o qa-swarm e depois triar as próprias threads. Descartada porque gera comentários para resolver logo em seguida e duplica chamadas de API.

### D2. Um skill e um orquestrador, sem spawn aninhado
Só o orquestrador (a sessão) cria agents: o router, as lentes e a escalada. As lentes são proibidas de criar sub-agents.
- *Por quê:* evita o problema que o Paul resolveu separando qa-swarm e review-triage, mantendo um skill só.

### D3. Escada de modelos: sonnet → sonnet → opus
O router sai do `haiku` e vai para `sonnet`, com `model` explícito no Agent.
- *Por quê:* a fonte documenta que runners em haiku pulavam passos e que os reruns custavam mais do que a economia. E o router faz a passada crítica.
- *Alternativa:* haiku para triagem mecânica de threads. Descartada nesta versão por simplicidade, já que a classificação de threads também exige julgamento.
- **Gatilhos objetivos:** >150 linhas ou caminho sensível obrigam pelo menos uma lente, independentemente da nota de perigo. Esse limite único fecha a faixa de 100 a 200 linhas que ficava sem regra.

### D4. Duas passadas como prioridade, não como trava
Todas as lentes rodam na rodada. Os achados ganham a tag `pass`. O auto-fix processa a passada 1 primeiro, e a passada 2 só é auto-corrigida se não sobrar bloqueador.
- *Alternativa:* parar na passada 1 (como a Yooh faz). Descartada porque, sem humano para dar o "acknowledge", a lente de segurança nunca rodaria.

### D5. Escala única de severidade e score por dimensão
- A escala é CRITICAL/HIGH/MEDIUM/LOW/NIT, com mapeamento documentado para MUST FIX, SHOULD FIX e NIT.
- O score usa as 8 dimensões e os pesos da Yooh, com deduções −35/−25/−15/−5/−1. Conta apenas os achados ainda abertos no HEAD revisado; os corrigidos aparecem à parte.
- *Por quê:* reprodutível e comparável com o `/review` da Yooh. As 4 dimensões com deduções globais do 1.1.0 não definiam como os pesos se aplicavam.
- O veredito nunca vira APPROVE ou REQUEST_CHANGES na API do GitHub: o evento é sempre `COMMENT`, porque a conta é a do próprio autor.

### D6. SIZE-1..6 fiel à Yooh e nunca auto-corrigido
A numeração e os limites originais são restaurados, e BLOCK/WARN/INFO são mapeados para HIGH/MEDIUM/LOW.
- Achados SIZE nunca são ACTIONABLE, porque um refactor exige decisão de design.
- Arquivos legados tocados de leve recebem no máximo LOW.

### D7. Proveniência: o cabeçalho só vale vindo do usuário do `gh`
Um comentário é automatizado se tiver `__typename == Bot`, ou login com `[bot]`/na lista de bots, ou cabeçalho **e** autor igual a `gh api user`. A dúvida conta como humano.
- *Por quê:* o 1.1.0 aceitava o cabeçalho vindo de qualquer pessoa, e o bugpool dá push com base nessa classificação.

### D8. Critério de ACTIONABLE com escada leve no lugar do paul-pair
Usa as 4 condições do review-triage. O que não é ACTIONABLE passa por NIT / PROMOTED / AMBIGUOUS:
- **PROMOTED** é o "just do it" do paul-pair (uma única correção óbvia e reversível).
- O "recommend and ask" do paul-pair foi descartado: ele resolve threads com uma escolha feita pelo bot, o que é decisão demais para um skill público.

### D9. Pré-condições e modos de execução
- `--review-only`, e queda automática para esse modo quando falha qualquer pré-condição: árvore suja, branch errada, HEAD diferente do do PR, ou PR de outra pessoa sem `--allow-foreign`.
- `gh pr checkout` quando o PR passado não é a branch atual.
- O diff é sempre contra `origin/<base>`.
- *Por quê:* o padrão seguro é ainda produzir a revisão, só que sem tocar no código.

### D10. Gate detectado, não fixo
- O gerenciador vem do lockfile, e o gate usa os scripts typecheck/lint/test que existirem. O teste roda nos arquivos relacionados quando o runner suporta.
- Sem `package.json`, usa o comando de check documentado em AGENTS.md/CLAUDE.md.
- Sem gate, o auto-fix fica desligado.
- *Alternativa:* `pnpm typecheck || npm run typecheck`. Descartada porque confunde "o script não existe" com "o check falhou" e não roda testes.

### D11. Commit local por fix, rollback por SHA, um push por rodada
- O rollback é `git reset --hard <pre-fix-sha> && git clean -fd`. Isso só é seguro porque D9 garante árvore limpa, e `clean` sem `-x` preserva os arquivos ignorados (`.env`, `node_modules`).
- Responder e resolver as threads só acontece depois que o push dá certo.
- *Alternativa:* `git checkout -- <files>`. Descartada porque não remove arquivos novos criados pelo fix.

### D12. Loop limitado e estado no sticky
- No máximo 3 rodadas. A partir da rodada 2, revisa só o diff dos próprios fixes.
- O estado fica num comentário HTML oculto dentro do sticky (`<!-- bugpool-state {...} -->`): rodada, SHA revisado e fingerprints dos achados já postados.
- *Por quê:* o GitHub é a fonte de verdade, então o skill pode ser reiniciado sem perder o estado e sem arquivo local.

### D13. Receitas da API do GitHub em `references/github-api.md`
- Corpos sempre via arquivo temporário (`-F body=@file`); a review vai num único `--input review.json`; strings usam `-f`.
- A query de threads leva o filtro e o truncamento do review-triage.
- Arquivos temporários ficam em `mktemp -d`, não em `/tmp/<nome fixo>`.

### D14. Divulgação progressiva
`SKILL.md` (<500 linhas) guarda o fluxo e as regras de decisão. Rubrica SIZE, score e receitas da API vão para `references/`, e o SKILL.md diz quando ler cada uma.
- *Por quê:* o 1.1.0 já tinha 381 linhas e as regras novas vão aumentá-lo.

### D15. Empacotamento
- Sai `commands/bugpool.md`.
- Frontmatter: `disable-model-invocation: true`, porque um skill que dá push não deve disparar sozinho. Também `argument-hint`, `license` e `metadata.version: "2.0.0"` (campos do padrão Agent Skills; o `version` no nível de cima não é reconhecido).
- O `install.sh` passa a remover o command antigo e perde a condição sempre verdadeira.

## Risks / Trade-offs

- **[Risco] O modelo ignora regras longas e pula passos.** → Mitigação: cada passo tem uma linha de narração obrigatória, o relatório final precisa fechar a contagem das threads, e as regras numéricas ficam em tabelas.
- **[Risco] `git reset --hard` apaga algo se a pré-condição for pulada.** → Mitigação: o passo de auto-fix começa revalidando `git status --porcelain` imediatamente antes de cada fix, não só no início do run.
- **[Risco] O custo sobe com sonnet no router.** → Mitigação: o diff pequeno e de baixo risco continua sendo fechado só pelo router. A troca é intencional (qualidade da passada crítica).
- **[Risco] O fingerprint de achados é instável entre modelos e gera duplicatas.** → Mitigação: o fingerprint usa arquivo + regra/categoria + linha normalizada em janela de ±5. Na pior hipótese duplica um comentário, o que não é perigoso.
- **[Risco] O teste "related" não existe no runner.** → Mitigação: cai para o script `test` completo e registra o tempo no relatório.
- **[Trade-off] PRs de terceiros ficam só em review-only por padrão.** Quem quiser auto-fix passa `--allow-foreign` explicitamente.
- **[Trade-off] Sem "recommend and ask".** Mais itens ficam como AMBIGUOUS para o humano.

## Migration Plan

1. Implementar no repo `skills` e subir `metadata.version` para 2.0.0, com a seção de breaking changes no README.
2. Validar com `--review-only` em PRs já mergeados do book-manager (#1–#4) e depois num PR de teste com auto-fix.
3. Reinstalar no book-manager (`npx skills add ... --skill bugpool` ou `install.sh`), que remove o command 1.x.
4. Rollback: os usuários fixam a instalação no commit da 1.1.0 (`f1343dd`).

## Open Questions

- **Licença do repositório e atribuição:** as três fontes não têm LICENSE. Adicionar MIT ao repo `skills` e pedir permissão aos autores, ou só dar crédito? É decisão do dono do repo. A task deixa o campo `license` como placeholder até a decisão.
- **Lista de bots conhecidos:** manter a lista do review-triage ou permitir extensão via AGENTS.md?
- **Valor do teto de rodadas:** 3 é palpite. Ajustar depois da validação.
