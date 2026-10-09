# Qualidade da User Story — 3 C's + INVEST

Guia de apoio para escrever stories bem-formadas. **O template oficial e obrigatório vive na wiki ENGSOFT** (`/EVEO/Padrões/Criação Story`) — este arquivo só resume os critérios universais de qualidade que a story deve satisfazer, adaptados ao contexto EVEO. Em conflito, a wiki vence.

## Os 3 C's

Uma story é uma conversa, não um documento fechado:

| C | O que é | Onde entra no ADO |
|---|---|---|
| **Card** | Título curto no formato "Como {papel}, quero {ação}, para {benefício}". Cabe em uma linha. | `System.Title` |
| **Conversation** | O detalhamento da intenção — contexto, regras de negócio, links de design. Não é especificação exaustiva; é o suficiente para alinhar. | `System.Description` |
| **Confirmation** | Critérios de aceite testáveis e observáveis. Definem "pronto". | `Microsoft.VSTS.Common.AcceptanceCriteria` (Gherkin) |

## INVEST

Antes de criar, valide a story contra:

- **I**ndependent — pode ser desenvolvida sem depender de outra story em andamento. Se há acoplamento forte, reordene ou junte.
- **N**egotiable — descreve o *quê* e o *porquê*, não prende o *como*. O refinamento técnico decide a implementação.
- **V**aluable — entrega valor observável a um papel de usuário. Se ninguém percebe a diferença, não é story.
- **E**stimable — o time consegue dimensionar. Se não dá pra estimar, falta contexto ou é grande demais.
- **S**mall — cabe em um ciclo de trabalho. Grande demais → quebre em stories menores.
- **T**estable — dá pra escrever critério de aceite verificável. Se não é testável, não é confirmável.

> Se a story falha em **Small** ou **Testable**, **quebre-a antes de criar**. Uma story que precisa de "e" no título quase sempre são duas.

## Acceptance Criteria (Gherkin) verificável

Cada critério deve ser concreto e observável. No contexto EVEO, isso significa **citar a stack real** — não escreva critério genérico.

Estrutura Gherkin:

```gherkin
Cenário: <resultado esperado em uma frase>
  Dado <estado/pré-condição — cite tabela, seed, usuário, feature flag>
  Quando <ação — cite endpoint, método, evento, fila>
  Então <resultado observável — cite status HTTP, registro no banco, mensagem publicada>
```

Cobertura mínima (confirme o piso na wiki):

- **Caminho feliz** — o fluxo principal funciona.
- **Validação** — entrada inválida é rejeitada com o erro correto.
- **Erro/borda** — dependência indisponível, recurso inexistente, concorrência.

## Checklist antes de criar

- [ ] Título no formato "Como {papel}, quero {ação}, para {benefício}".
- [ ] Description explica intenção + regras de negócio; links de design quando houver.
- [ ] Acceptance Criteria em Gherkin, testáveis, citando stack/endpoints/tabelas reais.
- [ ] Cobre feliz + validação + erro.
- [ ] Passa no INVEST (especialmente Small e Testable).
- [ ] Vinculada à Feature pai; `AreaPath` herdado; `IterationPath = ENGSOFT - Engenharia de Software`.
- [ ] Alinhada ao "Checklist antes de salvar" da wiki (fonte da verdade).
