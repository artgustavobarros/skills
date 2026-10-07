# 🌟 Public Agent Skills (Acervo Público de Skills)

Repositório público com habilidades especializadas para agentes de codificação de IA (**Claude Code**, **Antigravity**, **Cursor**, etc.), construídas com rigor metodológico e **zero ruído corporativo**.

---

## 📦 Skills Disponíveis

### 1. [`bugpool`](./skills/bugpool/SKILL.md) — Multi-Perspective PR Swarm & Autonomous Triage
> **Comando:** `/bugpool` | **Versão:** `1.1.0`

Orquestrador autônomo de revisão de Pull Requests e triagem contínua. Combina o melhor de dois mundos: a esteira de execução ágil do Paul D'Ambra com a disciplina analítica de código da Yooh Digital.

* **Two-Pass Review:** Pass 1 Crítico (Segurança, Confiabilidade, LLM Boundaries) + Pass 2 Informativo (Qualidade, Performance, Testes).
* **Escada de Modelos Econômica:**
  * Router: `haiku` (ou `flash`)
  * Lentes de Especialistas: `sonnet` (ou `pro`)
  * Escalada para Impasses: `opus` (ou `pro` c/ reasoning alto)
* **Regras de Complexidade SIZE-1..6:** Auditoria de tamanho de funções, parâmetros, aninhamento e arquivos gigantes.
* **Filtro de Fricção Construtiva:** Apontamentos cirúrgicos com `arquivo:linha`, sem bikeshedding.
* **Detecção de Scope Drift:** Compara as mudanças reais com o objetivo declarado no PR.
* **Imunidade Humana:** NUNCA comenta, comita ou fecha threads que tenham participação de humanos.
* **Safety Gate Local:** Testa o código com `typecheck` antes de comitar. Se quebrar, faz rollback imediato e transfere para decisão humana.
* **Sumário Sticky Único:** Um único comentário no PR com **Quality Score (0–100)** e histórico colapsado.

---

## 🚀 Como Instalar em Qualquer Projeto

### Opção 1: Via script instalador
A partir da raiz deste repositório:
```bash
./install.sh /caminho/para/seu/projeto
```
*(Ou execute `./install.sh` diretamente na pasta do seu projeto).*

### Opção 2: Cópia Manual
Copie a pasta da skill para a raiz do seu projeto:
```bash
# Para Antigravity / Claude Code:
cp -r skills/bugpool /caminho/para/projeto/.agents/skills/
cp commands/bugpool.md /caminho/para/projeto/.claude/commands/ 2>/dev/null || true
```

---

## 🛠️ Filosofia deste Acervo
1. **Sem Amarras de Ferramentas:** Nada de acoplamentos com MCPs específicos (Plane, context-mode, Jira, etc.). Tudo usa ferramentas padrão (`git`, `gh`).
2. **Respeito ao Humano:** A IA auxilia e limpa o trabalho repetitivo, mas decisões de arquitetura e conversas com humanos são sempre preservadas.
3. **Custo Consciente:** Os modelos mais caros só são chamados quando estritamente necessários.
