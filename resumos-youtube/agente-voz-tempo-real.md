# Resumo — "Agente de Voz em Tempo Real: WebRTC, STT, LLM, TTS" (pt-BR, ~18:34)

Fonte: https://www.youtube.com/watch?v=BGkqpw_QY-k
Data: 30/08/2026 | Transcrição: /tmp/tr_voz.json

## Tese central

> Uma conversa por voz com IA parece mágica, mas é um **orquestramento de tecnologias** — WebRTC (mídia), STT (sua fala → texto), LLM (texto → resposta), TTS (resposta → voz) e turn detection (saber quando você terminou de falar). O projeto open-source de referência coordena tudo isso, e cada etapa é visível de propósito.

## Arquitetura em 5 partes

1. **App React**: captura o microfone, mostra os estados da sessão, renderiza a transcrição.
2. **Servidor Node**: cria a **credencial temporária (JWT)** que permite entrar numa sala.
3. **LiveKit Cloud**: gerencia a sala e transporta as faixas de áudio com **WebRTC**.
4. **Worker**: entra como participante, escuta o usuário, chama os modelos e "publica" a própria voz.
5. **LiveKit Inference**: acessa os modelos de fala e linguagem configurados no agente.

> O navegador **nunca recebe a chave privada** do projeto — a segurança é isolada no backend.

## O fluxo de entrada (token)

1. A UI faz `GET /api/config` → descobre o nome público do agente.
2. `TokenSource` faz `POST /api/token` → o servidor cria um **nome de sala aleatório** e uma **identidade aleatória de participante** (toda a lógica isolada no backend — o cliente não escolhe sala conhecida nem injeta outro agente).
3. O token gerado permite **só aquela sala** e **só publicar o microfone** (câmera e dados fora do escopo).
4. Validade do token: **10 minutos** apenas para entrar — não afeta a conversa que já começou (evita problemas se a credencial vazar). Durante a sessão, o LiveKit atualiza a credencial internamente.
5. O token carrega o **nome do agente**; quando a sala abre, o LiveKit "entrega o trabalho" ao worker — o **dispatch**.

## WebRTC e o SFU

**WebRTC** é a tecnologia nativa do navegador para mídia em tempo real — conexão direta entre dois peers. Mas o LiveKit usa um **SFU** (Selective Forwarding Unit):

- O SFU recebe o áudio de **cada participante** e encaminha cada faixa **só para quem precisa** — ninguém cria conexões diretas entre si.
- O agente também entra na sala e abre conexão com o SFU → recebe os pacotes **já codificados** (o SFU **não decodifica/mixa/re-codifica** — só encaminha).
- Como a mídia passa pelo SFU, o LiveKit mede **perda de pacotes** e qualidade, e o transporte cresce separado do frontend.
- Antes do primeiro pacote, navegador e LiveKit **negociam a conexão** num **WebSocket** (canal de controle; o áudio em si vai pelo WebRTC). O servidor avisa quando participantes/faixas mudam.
- O SDK esconde os detalhes: a aplicação só trabalha com **salas, participantes e faixas**.

## O pipeline de áudio (em cascata)

1. **Captura do microfone** → WebRTC processa o áudio (com cancelamento de eco, redução de ruído).
2. **Filtro no servidor**: o worker aplica outra limpeza para **isolar a voz do usuário** (evita que a TV de fundo vire "palavras que a pessoa nunca disse" e que o turn detector interrompa à toa).
3. **STT** (speech-to-text): transforma fala em texto — no projeto, **Deepgram Nova 3** configurado para **pt-BR**. Vai devolvendo **trechos** enquanto a pessoa fala (streaming) — a sessão acumula na ordem.
4. **LLM**: recebe fala + histórico + instruções — **Gemma 3 27B** (Google) gera a resposta em texto.
5. **TTS** (text-to-speech): converte a resposta em áudio com a **voz em português** configurada — e o agente **publica essa faixa na sala**; o navegador pede para recebê-la e reproduz.

Todas as três chamadas passam pelo **LiveKit Inference** — centraliza e permite **trocar o STT sem trocar a voz** (cada etapa usa modelo separado, mensurável isoladamente).

### Por que em cascata (e quando não)

- **+**: flexibilidade para trocar modelos, medição isolada, custo controlado.
- **−**: **encadeia latência** (cada etapa soma até o primeiro áudio) e a LLM **não entende entonação** — só texto.
- Alternativa: **modelo speech-to-speech** (áudio → áudio direto, usa mais sinais da voz, pula conversões) — mas com menos controle e **custo bem maior**.

## VAD e turn detection (quando você terminou de falar?)

- **VAD** (voice activity detection): marca quais trechos têm fala e quais são silêncio. O problema: silêncio **no meio** da frase ("Eu preciso remarcar a entrega para… **para**") terminaria o turno com frase incompleta.
- O projeto usa um **inference turn detector** que analisa o áudio: **sentido da fala, entonação, tom, ritmo, silêncio** para calcular se a ideia terminou.
- **Endpointing**: mesmo se o algoritmo achar que terminou, a sessão **espera um pouco**; se a pessoa continuar, as novas palavras entram no **mesmo turno**; se não vier áudio novo, confirma o fim e libera a resposta.
- Valores padrão do SDK servem para demo; **produção precisa calibrar** conforme o uso real.

## Interrupção (barge-in e back-channel)

- O microfone do usuário **continua aberto** durante a resposta.
- **Back-channel** ("beleza", "uhum"): sinal de que está acompanhando → **não** interrompe.
- **Barge-in** ("na verdade, quis dizer outra coisa"): o sistema **interrompe a reprodução, descarta o áudio não tocado e abre novo turno**.
- O SDK usa **modo adaptativo**: se a nova fala não parece intencional, **retoma a resposta** de onde parou.
- Ao interromper, o SDK **corta o histórico até o ponto que a pessoa ouviu** (3 frases → ouviu 1 → histórico só registra 1).

## Medindo a latência (os marcadores)

1. Última sílaba da pessoa → 2. confirmação do fim do turno (**end of utterance delay**) → 3. STT finaliza → 4. LLM devolve o 1º token → 5. TTS produz 1º áudio → 6. áudio atravessa o LiveKit → 7. reprodução no navegador.

- **Jitter**: pacotes chegam a intervalos diferentes (rede varia). O **jitter buffer** guarda pacotes por alguns ms e libera num ritmo constante → menos cortes, um pouco mais de atraso.
- **Streaming**: o TTS roda enquanto a LLM gera o resto (não espera a resposta inteira).
- **Preemptive generation**: aciona a LLM **antes** da confirmação final do turno (quando a transcrição parece ter terminado). Se acertar → adianta; se errar → descarta e recomeça (custou processamento/tokens). No projeto, o TTS espera o turno confirmado.
- **Produção**: cada marcador precisa de **timestamp** para mostrar qual etapa mais atrasa a resposta.

## Do demo ao produto (production hardening)

- **Autenticação/autorização**: antes de publicar, o backend precisa autenticar a pessoa e autorizar a criação da sessão.
- **Rate limiting + concorrência + duração + consumo acumulado**: chamadas anônimas podem escalar custo (cada sessão despacha worker + STT + LLM + TTS). O token não limita quem pede — **CORS** só bloqueia páginas não autorizadas.
- **Estado**: hoje a transcrição vive só na memória do navegador (refresh = perde tudo). O backend não guarda estado — precisa de um **registro de sessão** em banco (sala ↔ usuário) e **chave de idempotência** (uma tentativa repetida devolve a sessão pendente, não cria outra).
- **Privacidade/LGPD**: `record: false` — sem gravação, mas os provedores **processam o áudio**; documentar quem recebe dados e por quanto tempo.
- **Observabilidade**: com tracing ligado, medir qual modelo demorou e o consumo por sessão **sem registrar o conteúdo da conversa**.
- **Estratégia de falha**: definir quais falhas permitem nova tentativa e quando a conversa termina de fato.

## Conclusão

Cada ms conta — a sensação de "conversa com humano" é o resultado de **orquestrar mídia, modelos e turnos** com medição contínua, e de blindar o backend para virar produto (auth, rate limit, sessão, idempotência, privacidade).

## Exemplo de código — jitter buffer (Python 3.14)

```python
# Python 3.14 — rajadas de pacotes; buffer drena 1 por tick (ritmo constante)
from collections import deque

class JitterBuffer:
    def __init__(self):
        self.fila = deque()
        self.saidas = []

    def adicionar(self, pacote):
        self.fila.append(pacote)          # rajada entra de uma vez

    def tick(self):
        # drena no maximo 1 pacote por tick de reproducao
        self.saidas.append(self.fila.popleft() if self.fila else "_")

jb = JitterBuffer()
# a rede entrega em rajadas: 3 pacotes juntos, depois 2, depois 1
for p in ["p0", "p1", "p2"]: jb.adicionar(p)
for _ in range(3): jb.tick()              # sai p0, p1, p2 em ticks separados
for p in ["p3", "p4"]: jb.adicionar(p)
for _ in range(2): jb.tick()              # sai p3, p4
jb.adicionar("p5")
for _ in range(3): jb.tick()              # sai p5, depois gaps
print("reproducao:", " ".join(jb.saidas))
# reproducao: p0 p1 p2 p3 p4 p5 _ _
```

O jitter buffer **suaviza as rajadas**: os pacotes chegam em grupos (a rede oscila), mas a reprodução drena **um por tick a cada 0.1s** — o áudio sai num ritmo constante, sem cortes. O custo é o pequeno atraso adicional (guardar = atrasar).