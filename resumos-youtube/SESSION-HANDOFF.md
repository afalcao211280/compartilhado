# SESSAO HERMES — HANDOFF / RETOMADA
# Canal YouTube @arthur.takeda — 29/29 videos resumidos (ago/2026)
# Sessao original (Hermes): 20260830_171430_001703  (30/08/2026)
# Link: @session:default/20260830_171430_001703

Este arquivo foi gerado a partir da sessao do Hermes que criou estes
resumos, para que, ao abrir o Hermes NESTA pasta, seja possivel entender
o estado do trabalho e continuar de onde parou (ou refazer qualquer coisa).

----------------------------------------------------------------------
## 1. ESTADO ATUAL — TUDO CONCLUIDO E VALIDADO (29/29 videos)
----------------------------------------------------------------------

Cada video tem UM par .md (fonte da verdade) + .html (gerado pelo
script gerar_html.py a partir do MD validado). Total: 29 pares + 1
script (gerar_html.py) + este handoff.

VIDEOS TECNICOS (23 novos nesta rodada):
  Lote 1 (4):  big-o, banco-de-dados-8-conceitos, docker-8-minutos,
               rag-tecnica-cursor
  Lote 2 (4):  rust-tudo, linguagem-de-programacao, browser-pipeline,
               so-por-baixo-dos-panos
  Lote 3 (4):  ia-moderna-llm, compilador-6-etapas,
               js-conceitos-fundamentais, useeffect-melhor-deletar
  Lote 4 (5):  system-design-cap, system-design-escalabilidade,
               system-design-cache, system-design-sql-nosql,
               system-design-replicacao-sharding
  Lote 5 (4):  agente-voz-tempo-real, latencia-live-youtube-cazetv,
               idempotencia-pagamentos, 10-conceitos-computacao
  Lote 6 (2):  ia-faz-trabalhar-mais-jevons (opinativo),
               chatgpt-anuncios-intimidade (opinativo)

VIDEOS ANTERIORES (6, ja existiam):
  aws-15-servicos, design-patterns, autenticacao-moderna,
  backend-10-conceitos, frontend-10-conceitos,
  frameworks-por-baixo-dos-panos

NOTA DE CLASSIFICACAO: o video g9DfXmDfE_Q era "CAP" em System Design
e chegou a aparecer na lista de "opinativos"; NAO e duplicado — foi
processado uma unica vez como system-design-cap.

----------------------------------------------------------------------
## 2. VALIDACAO (NADA INVENTADO — TUDO EXECUTADO DE VERDADE)
----------------------------------------------------------------------

128 blocos de codigo executaveis EXTRAIDOS DOS ARQUIVOS FINAIS (.md e
.html) e compilados/executados:
  - Python 3.14      : 46/46 OK
  - JavaScript/Node  : 22/22 OK (Node v24.19.0)
  - Java             : 29/29 compilam e rodam
  - Go               : 26/26 OK (Go 1.26.6)
  - Rust             : 5/5 (4 rodam + 2 contra-exemplos DIDATICOS que
                       falham como esperado: E0502 do borrow checker e
                       propagacao de erro `?` -> NotFound)
29/29 HTMLs balanceados (HTMLParser), sem tags desbalanceadas.

CORRECOES REAIS aplicadas durante a validacao desta rodada:
  - 10-conceitos: arvore desbalanceada dava RecursionError -> inserida
    em ordem balanceada (8 passos); race do saldo precisava de
    time.sleep para demonstrar (50 em vez de 0); sha256 real no
    comentario.
  - agente-voz: jitter buffer reescrito 2x ate demonstrar a suavizacao
    de rajadas (p0 p1 p2 p3 p4 p5 _ _).
  - compilador: bloco de otimizacao precisou de classe Num propria
    (autossuficiente); loop do gerador de assembly reescrito.
  - useEffect: simulacao de render (3 vs 1) corrigida; closure stale
    e fetch com cleanup/race (Ana/Bruno) reescritos; JSX inline do
    texto nao entram no HTML (so os 3 exemplos executaveis).

----------------------------------------------------------------------
## 3. PROCESSO PADRAO (para reprodutor/continuar)
----------------------------------------------------------------------

1. TRANSCREVER:
   export PATH="$HOME/.hermes/bin:$PATH"
   uv run --with youtube-transcript-api python \
     /home/alysson/.hermes/skills/media/youtube-content/scripts/fetch_transcript.py \
     "URL" --language pt,pt-BR,en,es > /tmp/tr_NOME.json
   (rodar em background com & + wait para lotes; sem & retorna exit -1)

2. ESCREVER .md (fonte da verdade dos blocos de codigo):
   - linguagens por video: Java/Go/Python (backend/SO),
     JS/Node (Browsers/frontend), Python puro (IA/LLM),
     Rust (video de Rust), Dockerfile/Compose/YAML (nao executam),
     opinativos = so resumo, sem codigo.
   - blocos AUTOSSUFICIENTES (cada um define seus proprios tipos).

3. VALIDAR o .md ANTES de gerar o HTML:
   extrair os blocos do MD e compilar/executar de verdade.
   Comentarios de saida esperada = saida REAL validada.

4. GERAR O HTML (sempre assim, nunca a mao):
   python3 gerar_html.py ARQUIVO.md "TITULO" "URL" "~DURACAO" ARQUIVO.html

5. VALIDAR a EXTRACAO do HTML gerado (com html.unescape) — os blocos
   do HTML devem rodar identicos aos do MD.

----------------------------------------------------------------------
## 4. COMANDOS / AMBIENTE / VERSOES (registrado na sessao)
----------------------------------------------------------------------

Pasta: /home/alysson/Projetos/AM-Falcao-Solutions/Git/resumos-youtube/
Gerador: ./gerar_html.py (MD -> HTML escuro 3 colunas, lexer linha a
         linha; suporta python|java|go|rust|js|bash|yaml|dockerfile)
Skill: youtube-content (workaround uv aplicado)

VerSoes:
  - Go      1.26.6   (/usr/local/go/bin)
  - Python  3.14.7   (python3 do sistema)
  - Node    v24.19.0 (~/.nvm/versions/node/v24.19.0/bin)
  - Rust    1.98.0   (~/.cargo/bin)
  - Java    SDKMAN current = 25.0.4-tem
            >>> ATENCAO <<< : os resumos rotulam "Java 26", mas o
            current do SDKMAN mudou para 25.0.4. Os exemplos usam
            stdlib pura (compilam em 25 e 26). Se for REGERAR
            exemplos Java, validar contra a versao que estiver no
            sdkman (verificar: ls ~/.sdkman/candidates/java/current).
  - uv      ~/.hermes/bin/uv

ConvenCao de nome: NOMES SEM prefixo "resumo-" (ex.: aws-15-servicos).
Nao recriar com prefixo.

HTML: tema escuro, .wrap max-width:100% (largura total, padding
2rem 2.5rem), grid code2col 3 colunas (1fr 1fr 1fr), fallback 2 col
<1100px e 1 col <900px, highlight proprio (spans .k/.t/.s/.c),
blocos <pre class="src">.

Contra-exemplos didaticos (ex.: Rust E0502) entram no MD como codigo
que NAO compila, com o erro esperado documentado.

Validar Java: renomear arquivo extraido para o nome da classe publica.

----------------------------------------------------------------------
## 5. SE FOR RETOMAR / CONTINUAR
----------------------------------------------------------------------

Nao ha trabalho pendente: os 29 videos do canal @arthur.takeda estao
cobertos e validados. Exemplos de acoes futuras possiveis:
  - adicionar exemplo em OUTRA linguagem a um resumo existente;
  - regerar o HTML de algum resumo apos editar o MD;
  - corrigir o rotulo "Java 26" -> versao real do sdkman (se quiser);
  - processar outro canal com o mesmo processo.
