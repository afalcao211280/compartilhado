# Resumo — "Como uma LLM funciona por dentro" (pt-BR, ~16:39)

Fonte: https://www.youtube.com/watch?v=Rc7pw0v0L2o
Data: 30/08/2026 | Transcrição: /tmp/tr_ia.json

## Tese central

Uma LLM é **álgebra linear aplicada em escala**: bilhões de operações matemáticas por resposta. Todo comportamento (escrever código, traduzir, "raciocinar") vem de **parâmetros** — números decimais ajustados no treinamento — funcionando juntos.

## Etapas por dentro

### 1. Tokenização
- Transformar texto em números: quebrar em pedaços, cada um com um **ID numérico**.
- Nem sempre um token é uma palavra inteira: "programar" pode virar `program` + `ar` (o tokenizador aprende padrões comuns).
- Vocabulário: **30 mil a 100 mil tokens**.

### 2. Embeddings (geometria do significado)
- Cada token vira um **vetor** (centenas/milhares de dimensões) — coordenadas de significado.
- Palavras parecidas ficam **perto** (rei/rainha, gato/cachorro; JavaScript/Python em outro grupo).
- Relações viram **direções**: `rei − homem + mulher ≈ rainha`. O modelo aprende isso sozinho, lendo texto.

### 3. Transformer (arquitetura, 2017 — "Attention Is All You Need")
- Antes: RNNs processavam palavra por palavra — lentas e esqueciam o começo.
- Transformer: processa **todas as palavras em paralelo**; cada palavra "olha" todas as outras, não importa a distância.
- **Self-attention**: cada palavra faz 3 perguntas:
  - **Query** — "o que estou procurando aqui?"
  - **Key** — "o que tenho a oferecer?"
  - **Value** — "qual informação passo adiante?"
  - `score = produto escalar(query, key)`; passam por **softmax** (probabilidades que somam 1) → média ponderada dos Values.
  - Em "o gato que mora na casa do vizinho **dormiu** no sofá", `dormiu` dá score alto para `gato` (7 palavras antes).
- **Multi-head**: várias cabeças em paralelo, cada uma focando aspectos diferentes (gramática, semântica...).
- **Feed-forward** depois da atenção: cada "pessoa volta pra mesa e processa o que ouviu".
- **GPT-3: 96 camadas** empilhadas (camadas iniciais = gramática; meio = conceitos abstratos; finais = ideias complexas).

### 4. Treinamento: pré-treinamento, fine-tuning, RLHF
- **Pré-treinamento**: prever a próxima palavra em bilhões de textos da internet. Erro volta por todas as camadas (**backpropagation**) ajustando cada parâmetro — por isso custa milhões de dólares.
- Resultado do pré-treinamento: um "autocomplete gourmetizado" (responde "qual a capital da França?" com "qual a capital da Alemanha?").
- **Fine-tuning**: re-treinar com dataset pequeno e específico de pares instrução→resposta.
- **RLHF**: humanos rankeiam respostas → treina-se um **reward model** → a LLM ajusta parámetros para maximizar a nota ("professor particular").

### 5. Inferência
- Input → tokens → embeddings → camadas → **distribuição de probabilidade sobre o vocabulário**.
- **Temperature**: 0 = sempre a palavra mais provável (previsível); alta = probabilidades distribuídas (criativa, imprevisível).
- **Autoregressivo**: uma palavra por vez, realimentando o input.

## Limitações

- **Alucinação**: o modelo não armazena fatos como banco de dados; aprende padrões estatísticos. Brasil/Copa aparecem juntos, mas o ano é aposta probabilística.
- **Janela de contexto**: atenção compara cada token com todos os outros — custo **quadrático** (dobrar contexto = 4× cálculos). Conversa longa → mensagens antigas "caem da mesa".

## O que diferencia um modelo do outro

| Fator | Efeito |
|---|---|
| **Dados de treinamento** | O que o modelo "sabe" (código → bom em programação; artigos → pesquisa) |
| **Tamanho** | Mais parâmetros = mais capacidade, mais custo (celular vs data center) |
| **Alinhamento** | Fine-tuning + RLHF de cada empresa = "personalidade" (Claude responde diferente do GPT) |

## Open source: DeepSeek e MiniMax

- **DeepSeek R1** (jan/2025): superou GPT/Claude em benchmarks de matemática e programação competitiva; **Mixture of Experts** — 671B parâmetros, só **37B ativos por vez**; custo de treinamento muito menor; licença MIT.
- **MiniMax 01**: **Lightning Attention** (alternativa ao transformer tradicional), 456B parâmetros, contexto de **4 milhões de tokens** (20-30× a maioria). M2.5 compete com Claude Opus 4.5 custando 20× menos.
- Com pesos abertos: rodar na própria máquina sem API, ajustar pro seu caso, entender o que acontece por dentro.

> Nenhuma LLM **entende** o que diz — não há consciência nem intenção. É álgebra linear; a linha entre prever padrões e compreender de verdade fica cada vez mais difícil de enxergar.

---

## Exemplos de código — Python 3.14 (stdlib)

### 1. Tokenização + embeddings: a analogia clássica
```python
# Python 3.14 — tokens viram vetores; rei - homem + mulher ~ rainha
import math

VOCAB = ['rei', 'homem', 'mulher', 'rainha', 'gato', 'cachorro']

# embeddings 3d artesanais (apenas para ilustrar a geometria)
E = {
    'rei':     [0.9, 0.1, 0.5],
    'homem':   [0.8, 0.2, 0.4],
    'mulher':  [0.8, 0.2, 0.6],
    'rainha':  [0.9, 0.1, 0.7],
    'gato':    [0.2, 0.9, 0.1],
    'cachorro':[0.2, 0.8, 0.1],
}

def sub(a, b): return [a[i] - b[i] for i in range(3)]
def add(a, b): return [a[i] + b[i] for i in range(3)]

def cosseno(a, b):
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(x * x for x in b))
    return dot / (na * nb)

def mais_proximo(v):
    return max(VOCAB, key=lambda w: cosseno(v, E[w]))

alvo = add(sub(E['rei'], E['homem']), E['mulher'])
print('rei - homem + mulher ->', mais_proximo(alvo))   # rainha
print('gato vs cachorro     ->', round(cosseno(E['gato'], E['cachorro']), 2))
print('gato vs rei          ->', round(cosseno(E['gato'], E['rei']), 2))
# rei - homem + mulher -> rainha
# gato vs cachorro     -> 1.0
# gato vs rei          -> 0.33
```

### 2. Self-attention simplificada (Q/K/V + softmax)
```python
# Python 3.14 — atencao em "o gato dormiu": dormiu olha para gato
import math

def softmax(vals):
    mx = max(vals)
    ex = [math.exp(v - mx) for v in vals]
    s = sum(ex)
    return [e / s for e in ex]

def produto_escalar(a, b):
    return sum(x * y for x, y in zip(a, b))

# embeddings 2d: [caracteristica_animal, caracteristica_acao]
tokens = {
    'o':     [0.1, 0.1],
    'gato':  [0.9, 0.2],
    'dormiu':[0.3, 0.9],
}

K_lin = {'o': [0.1, 0.1], 'gato': [0.9, 0.2], 'dormiu': [0.3, 0.9]}  # keys
Q = {'o': [0.1, 0.1], 'gato': [0.9, 0.2], 'dormiu': [0.3, 0.9]}      # queries
V = {'o': [0.2, 0.1], 'gato': [0.8, 0.3], 'dormiu': [0.2, 0.9]}      # values

palavra = 'dormiu'
scores = {t: produto_escalar(Q[palavra], K_lin[t]) for t in tokens}
probs = softmax(list(scores.values()))
print('scores de "dormiu":', {t: round(s, 3) for t, s in scores.items()})
print('softmax:', [round(p, 3) for p in probs])

# saida de "dormiu" = media ponderada dos Values
saida = [sum(probs[i] * V[t][d] for i, t in enumerate(tokens)) for d in range(2)]
print('saida de "dormiu":', [round(x, 3) for x in saida])
# scores de "dormiu": {'o': 0.12, 'gato': 0.45, 'dormiu': 0.9}
# softmax: [0.219, 0.304, 0.477]
# saida de "dormiu": [0.383, 0.543]
```
> O score alto com `gato` (0.45) mostra que a atenção conecta `dormiu` ao sujeito, mesmo distante. Em LLMs reais isso acontece com vetores de centenas/milhares de dimensões e dezenas de camadas.

### 3. Decodificação autoregressiva com temperature
```python
# Python 3.14 — gerar texto palavra a palavra, com temperature
import math, random

# logits "hipoteticos" do modelo: o modelo da um numero (logit) para cada
# token do vocabulario — aqui dependem da ultima palavra gerada
def logits_para_prox(ultima):
    base = {'o': 0.2, 'gato': 1.5, 'dormiu': 0.8, 'no': 0.3, 'sofa': 0.6}
    # "gato" e mais provavel depois de "o"; "sofa" depois de "no"...
    if ultima == 'o':
        base['gato'] = 1.5
    elif ultima == 'gato':
        base['dormiu'] = 1.4
    elif ultima == 'dormiu':
        base['no'] = 1.2
    elif ultima == 'no':
        base['sofa'] = 1.6
    return base

def amostrar(probs):
    r = random.random()
    acc = 0.0
    for palavra, p in probs:
        acc += p
        if r <= acc:
            return palavra
    return probs[-1][0]

def gerar(inicio, temperature, passos=5):
    palavras = [inicio]
    for _ in range(passos):
        logit = logits_para_prox(palavras[-1])   # dict token -> logit
        if temperature == 0:
            palavras.append(max(logit, key=logit.get))   # sempre a mais provavel
        else:
            exp = [math.exp(logit[w] / temperature) for w in logit]
            s = sum(exp)
            probs = [(w, exp[i] / s) for i, w in enumerate(logit)]
            palavras.append(amostrar(probs))
    return ' '.join(palavras)

print('temp 0 :', gerar('o', 0.0))   # previsivel: o gato gato gato...
random.seed(7)
print('temp 2 :', gerar('o', 2.0))   # mais aleatorio
# temp 0 : o gato gato gato gato gato
# temp 1/2: variam a cada execucao (aleatoriedade controlada)
```
> LLMs reais têm logits sobre 30–100 mil tokens e a amostragem com temperature faz a mesma pergunta render respostas diferentes.

---

## Destaques

- Parâmetros = números ajustados no treinamento; bilhões/trilhões deles = LLM.
- Embeddings transformam significado em **geometria**.
- Transformer: aten��ão (Q/K/V) + feed-forward, empilhados (GPT-3: 96 camadas).
- Atenção é **quadrática** → janela de contexto limitada ("mesa de escritório").
- Pré-treinamento → fine-tuning → RLHF = modelo útil e seguro.
- Temperature controla o balanço precisão/criatividade na geração.
- Diferenças entre modelos: dados, tamanho, alinhamento.
- Open source (DeepSeek MoE, MiniMax Lightning Attention) vs proprietário.