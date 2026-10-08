## Why

O `bugpool` 1.1.0 combina qa-swarm, review-triage (ambos de pauldambra/dotfiles) e a metodologia de review da Yooh, mas a junção deixou o fluxo sem fechar: achados novos não chegam ao GitHub e o "loop" não existe. Além disso, por ser um skill que commita e dá push sozinho, ele herdou e criou riscos operacionais: a imunidade humana pode ser burlada, o rollback pode apagar trabalho local, e passar o número de um PR faz a revisão rodar na branch errada. Precisa ser corrigido antes de alguém usar o skill público em um repositório real.

## What Changes

- **Identidade "auto-revisão antes do humano"**: achados acionáveis são corrigidos localmente; só os ambíguos viram comentários inline (uma única review); nits entram apenas no resumo. **BREAKING** (comportamento observável no PR muda).
- **Loop real**: rodadas com limite, re-revisão do diff das correções, condição de parada, estado idempotente no comentário sticky e detecção de "nada a fazer".
- **Revisão em duas passadas sem travar a execução autônoma**: todas as lentes selecionadas rodam; a passada 1 (crítica) tem prioridade no auto-fix; a passada 2 só é auto-corrigida quando não resta bloqueador.
- **Escada de modelos**: o router passa de `haiku` para `sonnet` e o dispatch via Agent com `model` passa a ser explícito. Gatilhos objetivos de delegação valem independentemente da nota do router; some a faixa sem regra entre 100 e 200 linhas. **BREAKING**.
- **Escala única de severidade** (CRITICAL/HIGH/MEDIUM/LOW/NIT) mapeada para MUST FIX/SHOULD FIX/NIT da Yooh; quality score por dimensão, reproduzível.
- **SIZE-1..6 com a numeração e os limites originais da Yooh**, com WARN/BLOCK/INFO mapeados para severidade; achados de complexidade nunca são auto-corrigidos.
- **Imunidade humana endurecida**: o cabeçalho de bot só é confiável quando o autor é o usuário do `gh`; `__typename == Bot` volta a contar; em caso de dúvida, a thread é tratada como humana.
- **Critério de ACTIONABLE** com as 4 condições do review-triage, mais uma escada de autonomia leve (substitui o gate do paul-pair) e destino definido para MEDIUM e LOW.
- **Pré-condições de segurança**: checkout do PR, árvore limpa, HEAD igual ao do PR, auto-fix só em PRs do próprio usuário (ou com flag explícita), modo `--review-only`.
- **Gate local real**: detecta o gerenciador de pacotes pelo lockfile, roda typecheck + lint + testes quando existirem, e desliga o auto-fix quando não houver gate.
- **Rollback seguro** (baseado em SHA, com árvore limpa garantida) e **um único push** por rodada; responder e resolver só depois que o push der certo.
- **Correções na API do GitHub**: corpo sempre via arquivo (sem `\n` literal), `-f` para strings, fetch de threads filtrado e truncado, refetch antes de agir, falha na resposta mantém a thread aberta.
- **Contexto do projeto para as lentes**: AGENTS.md/CLAUDE.md e versões instaladas dos frameworks (checagem de APIs alucinadas); a lente de stack detecta a stack em vez de assumir React/Next.
- **Empacotamento**: remove `commands/bugpool.md` (o skill já é invocável como `/bugpool`); frontmatter com `disable-model-invocation`, `argument-hint`, `license` e `metadata.version`; SKILL.md 100% em inglês e sem nomes pessoais; referências movidas para `references/`; `install.sh` corrigido; README com afirmações precisas e créditos às fontes. **BREAKING** (some o arquivo de command).

## Capabilities

### New Capabilities
- `review-panel`: como o bugpool revisa o diff (router, escada de modelos, lentes, duas passadas, escala de severidade, SIZE-1..6, contexto do projeto, formato dos achados).
- `thread-triage`: como threads existentes e achados novos são classificados e tratados (imunidade humana, critério de ACTIONABLE, escada de autonomia, responder antes de resolver, publicação dos ambíguos).
- `autofix-safety`: pré-condições, checkout, gate local, rollback e push das correções automáticas.
- `review-loop-reporting`: rodadas, idempotência, resumo sticky, quality score e saída no terminal.
- `skill-packaging`: frontmatter, layout de arquivos, instalador, README e atribuição.

### Modified Capabilities
<!-- Nenhuma: o repositório ainda não tem specs. -->

## Impact

- `skills/bugpool/SKILL.md`: reescrito.
- `skills/bugpool/references/*.md`: novos (rubrica de tamanho, quality score, receitas da API do GitHub).
- `commands/bugpool.md`: removido.
- `install.sh`, `README.md`: atualizados.
- Usuários do 1.1.0: `/bugpool` continua funcionando como slash command do skill. Revisões passam a postar só os achados ambíguos e o auto-fix passa a exigir árvore limpa e um PR do próprio usuário. Versão sobe para 2.0.0.
- Cópias instaladas em projetos (ex.: `book-manager/.agents/skills/bugpool`) precisam ser reinstaladas.
