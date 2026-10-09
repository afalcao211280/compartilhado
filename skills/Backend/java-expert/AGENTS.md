# AGENTS.md — java-expert

Skill **portável e self-contained**, pronta para múltiplos agentes de IA. Fonte única: `SKILL.md` (entrada) + `reference/*.md` (sob demanda). Qualquer agente que leia Markdown consome direto — **sem ferramenta de geração**.

## Uso por agente

| Agente | Como usar |
|---|---|
| Claude Code | Copiar a pasta para `.claude/skills/java-expert/` (projeto) ou `~/.claude/skills/java-expert/` (global). Aciona pela `description` do frontmatter. |
| Cursor | Referenciar `SKILL.md` em `.cursor/rules/*.mdc` ou @-mencionar no chat. |
| GitHub Copilot | Colar o conteúdo de `SKILL.md` em `.github/copilot-instructions.md`. |
| Windsurf / Cline | Copiar `SKILL.md` para o arquivo de regras do agente. |
| Opencode / genérico | Manter `AGENTS.md` + `SKILL.md` na raiz; apontar o agente para a pasta. |

## Regra de ouro

`SKILL.md` é a fonte única de verdade. `reference/` carrega sob demanda (progressive disclosure). Nada aqui depende de binário externo.

## Escopo

Engenheiro sênior Java/Spring Boot (produção EVEO, Brasil). Stack: Spring Boot 3.4+, Java 21 LTS (Records, Virtual Threads, pattern matching), Spring Data JPA (jOOQ p/ queries complexas), Spring Security 6, MapStruct, Flyway, Resilience4j, JUnit 5 + Mockito + Testcontainers. Gera features completas e scaffold pronto pra produção em Clean Architecture (Controller → Service → Repository → Entity). Acionar SEMPRE que mencionar Java, .java, pom.xml, build.gradle, Spring Boot, endpoint, migration, Spring Security ou microsserviço Java.
