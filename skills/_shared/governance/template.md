---
name: <nome-da-skill>
description: >
  <O QUE faz> Stack: <libs principais>. Gera <o que gera>.
  Acionar SEMPRE que mencionar: <keywords/gatilhos>.
  <!-- Pushy: descreva o que faz E quando usar. Evite undertriggering. 50–600 chars. -->
version: "1.0.0"
category: <Backend|Frontend|Cloud|Database|Infra|Security|DevSecOps|Service-NoSQL|Crosscutting|Outras>
keywords: [kw1, kw2, kw3, kw4, kw5]
requires: [skill-1, skill-2]
---

# <Nome> Expert

<!-- 1 linha: quem é + promessa. "Engenheiro sênior X. Código pronto pra produção." -->

## Princípios (3–7 regras)
<!-- Cada regra com o PORQUÊ embutido. Imperativo. Sem MUST rígido sem motivo. -->
1. ...

## Stack Canônica (tabela)
| Categoria | Lib | Uso |
|---|---|---|
| ... | ... | ... |

> <!-- Marque o que é FIXO e o que se PERGUNTA ao usuário. -->

## Layout (ASCII)
```
...
```

## Workflow Agentic
<!-- Passos de geração, de dentro pra fora. -->
1. ...

## Anti-padrões Críticos
- ❌ ...

## Checklist
- [ ] ...

## Quando Perguntar
<!-- Decisões que NÃO se assume — perguntar antes de codar. -->

## Referências (sob demanda — progressive disclosure)
<!-- SKILL.md ≤ 500 linhas. Detalhe vai pra reference/. reference >300 linhas → incluir índice. -->
- `reference/core.md` — Sempre antes de codar
- `reference/stack.md` — Ao criar projeto novo
- `reference/<lib>.md` — Ao usar lib específica

## Cross-references
- `security-expert` — auth, secrets, TLS
- `...`

## Segurança (Baseline Compartilhado)
Regras universais em `reference/security-baseline.md` (cópia inline; fonte em `_shared/security/baseline.md`, propagada por `_tools/sync_baseline.py`). Aqui só ameaças específicas do domínio.

> **Atenção**: <restrições específicas — o que esta skill NÃO usa/faz>
