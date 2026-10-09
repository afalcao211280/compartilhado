# Claude Code

O Claude Code carrega automaticamente o arquivo `CLAUDE.md` do diretório do usuário e do projeto, de forma incremental.

## Arquivos desta pasta

| Arquivo | O que é |
|---|---|
| [`CLAUDE.md`](CLAUDE.md) | Instruções globais do time (idioma pt-BR, plugins, Karpathy Guidelines). |
| [`statusline.sh`](statusline.sh) / [`statusline-command.sh`](statusline-command.sh) | Statusline customizada para o Claude Code (registrar em `settings.json`, chave `statusLine`). |

## Instalação

```bash
# Instruções globais do usuário
cp ai-hardness/agents/claude-code/CLAUDE.md ~/.claude/CLAUDE.md

# Statusline (opcional)
cp ai-hardness/agents/claude-code/statusline*.sh ~/.claude/
chmod +x ~/.claude/statusline*.sh
```

> Nos projetos, ao abrir o Claude Code pela primeira vez rode `/init` — cria o `CLAUDE.md` do projeto com o resumo sempre disponível. Para gerar um `CLAUDE.md` alinhado ao hardness do time, use [`../../rules/geradores/agents-generator.md`](../../rules/geradores/agents-generator.md).

O Claude Code lê esses arquivos automaticamente e segue as regras durante geração de código, revisão e análise.

## Documentação

Consulte https://docs.anthropic.com/en/docs/claude-code/overview
