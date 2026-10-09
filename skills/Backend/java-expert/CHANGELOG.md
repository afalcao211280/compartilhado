# Changelog — java-expert

## [2.1.0] - 2026-06-30

### Changed
- Consolidação em `skills-optimizadas` (cruzamento skills/ ⨯ skills-compare/java-spring-boot ⨯ ADR-002-java).
- SKILL.md densificado (409 → ~213 linhas): código inline movido para `reference/core.md`; adicionadas seções de referência (progressive disclosure), workflow e checklist enxutos.
- Path do security baseline corrigido para `reference/security-baseline.md`.
- Frontmatter: `description` reduzida (keyword-stuffing movido para `keywords[]`); `keywords` ampliadas para 8 termos reais (java, spring-boot, jpa, maven, gradle, spring-security, flyway, testcontainers).
- Alvo de versão explicitado: Java 21 LTS / Spring Boot 3.x (última estável).

### Added
- Seção **Error Response: RFC 7807 (ProblemDetail)** no SKILL.md (origem: compare `java-spring-boot` — `ProblemDetail`, `SessionCreationPolicy.STATELESS`, `open-in-view: false`, actuator probes, `include-stacktrace: never`). Registrada como preferência p/ APIs novas, sem quebrar `ErrorResponse` custom legado.
- Índice (TOC) em `reference/core.md` (>300 linhas).

### Removed
- `reference/patterns.md` (byte-a-byte idêntico a `reference/core.md`; ponteiros consolidados em `core.md`).

### Decisões de divergência ADR-002 (caso a caso)
- **Sem contradição dura.** ADR-002 usa a skill como fonte (`Referências: skills/Backend/java-expert/SKILL.md`).
- **JPA vs jOOQ**: diferença de ESCOLHA DE FERRAMENTA — ambas documentadas sem default, "perguntar ao usuário" (alinhado skill + ADR).
- ADR só mais rico em pontos já cobertos (naming, camadas, anti-padrões) — mantido alinhamento.

### Descartes do compare (motivo)
- `references/GUIDE.md` e `references/PATTERNS.md` do compare: boilerplate de template genérico (exemplos em Python, placeholders "General"/"Task 1") — zero valor Java. Descartados.

## [2.0.0] - 2024-06-15
### Changed
- SKILL.md reduzido de 393 para ~95 linhas (caveman style)
- Conteudo granularizado em arquivos de referencia
- Seguranca movida para _shared/security/baseline.md
- Adicionado versionamento semantico

## [1.0.0] - 2024-01-10
### Added
- Versao inicial com Spring Boot 3
- Java 21+, Records, Virtual Threads
- Spring Data JPA, Spring Security
