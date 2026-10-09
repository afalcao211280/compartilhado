# Resumo — "10 Conceitos que São a Base de Tudo na Computação" (pt-BR, ~10:46)

Fonte: https://www.youtube.com/watch?v=zLV586SXHsU
Data: 30/08/2026 | Transcrição: /tmp/tr_comp10.json

## Tese central

> Tudo na computação — de IA a um simples `print` — se resume a **10 ideias fundamentais** que existem há décadas e não mudaram. Linguagens e frameworks mudam; esses conceitos, não. Quem entende a essência de cada um enxerga padrões em qualquer tecnologia nova.

## 10. Binário e lógica booleana

Tudo que o computador processa — texto, imagem, som — no fundo é uma sequência de **zeros e uns**. A letra `A` é bits; uma foto são milhões de números representando a cor de cada pixel.

Para manipular bits, três operações: **AND, OR, NOT** (lógica booleana). Combinando essas três, dá para construir **qualquer coisa**: calculadoras, memória, processadores inteiros. Cada circuito do computador é uma combinação de portas lógicas.

## 9. Estruturas de dados

Ter dados em binário é só o começo — o que importa é **como você organiza**. 1.000 nomes, achar um específico:

- **Lista**: olha um por um → 1.000 comparações no pior caso.
- **Árvore binária de busca**: divide pela metade a cada passo → ~10 comparações.
- **Hash table**: uma comparação direto no endereço certo.

Cada estrutura tem tradeoffs: array é rápido por índice; lista encadeada insere rápido no meio; árvore busca rápido quando ordenada. **A escolha da estrutura muda tudo no desempenho.**

## 8. Complexidade de algoritmos (Big O)

Conforme os dados crescem, o que acontece com o tempo?

| Notação | Comportamento | Exemplo |
|---|---|---|
| O(1) | constante — 10 ou 10M de elementos, mesmo tempo | acesso por índice |
| O(n) | linear — dobrou dados, dobrou tempo | busca linear |
| O(n²) | quadrático — dobrou dados, quadruplicou tempo; 100.000 elementos = 10 bilhões de operações | loops aninhados |
| O(n!) | fatorial — 20 elementos = mais de 2 quintilhões (impossível) | caixeiro viajante |

**Busca binária é poderosa**: 1 bilhão de elementos → só 30 comparações. Saber Big O é prever se o código funciona em produção ou trava com dados reais.

## 7. Recursão

Função que **chama a si mesma** para resolver um problema menor:

- **Caso base** (1ª linha): faz a recursão parar. Sem ele → loop infinito.
- **Caso recursivo**: divide o problema em algo menor.
- Cada chamada entra na **pilha de execução**; quando chega ao caso base, devolve os resultados de baixo para cima.

`fatorial(5) → fatorial(4) → ... → fatorial(1) = 1 → 2 → 6 → 24 → 120`

Recursão aparece em árvores, ordenação, fractais — até o sistema de arquivos é uma estrutura recursiva.

## 6. Concorrência e paralelismo

- **Concorrência**: gerenciar várias tarefas ao mesmo tempo (um cozinheiro: põe o arroz, corta a cebola enquanto espera — mas nunca faz as duas no mesmo instante).
- **Paralelismo**: executar várias tarefas ao mesmo tempo (dois cozinheiros).

**Race condition**: duas threads leem o saldo R$ 100 ao mesmo tempo, ambas subtraem 50, ambas gravam 50 → o saldo deveria ser 0, mas ficou 50. **Dinheiro aparece do nada.** Locks, semáforos e deadlocks existem para lidar com isso.

## 5. Compiladores e interpretadores

`let x = 10` — como o computador entende? O compilador:
1. **Análise léxica**: quebra em tokens (`let` = reservada, `x` = identificador, `10` = número).
2. **Análise sintática**: monta a **AST** (árvore sintática abstrata).
3. **Otimizador**: analisa a árvore e gera código de máquina mais eficiente que o escrito.

- **Compilador**: traduz tudo de uma vez, gera executável → mais rápido.
- **Interpretador**: traduz e executa linha por linha → mais flexível.
- **Java/C#** ficam no meio: compilam para código intermediário que roda numa **máquina virtual**.
- (Vídeo dedicado: `compilador-6-etapas`.)

## 4. Redes e protocolos

Para falar com outro computador, mensagens atravessam cabos, roteadores e satélites — sem virar caos graças aos **protocolos**, organizados em **camadas**:

- **HTTP** (topo): diz o que pedir — "me dê a página inicial".
- **TCP**: garante entrega inteira; se um pedaço se perde, reenvia.
- **IP**: decide para onde mandar — endereço e rota.
- **Camada física** (base): transmite bits por cabo, Wi-Fi, fibra.

Cada camada **empacota** a mensagem e manda para baixo (envelopes dentro de envelopes); do outro lado, cada camada desempacota e passa para cima.

## 3. Banco de dados

Variáveis **morrem** quando o programa fecha; o banco é onde a informação **sobrevive**. Por baixo de uma query simples, o banco decide: percorrer tudo ou usar índice? Sem índice lê todas as linhas; com índice pula direto aos dados — **1 segundo vs 1 ms**.

Bancos relacionais garantem **ACID**: atomicidade (ou tudo ou nada — transferir R$ 100 sai de uma conta e entra na outra, ou nenhuma das duas), consistência, isolamento, durabilidade. Sem essas garantias, dinheiro some e sistemas quebram. (Vídeo dedicado: `banco-de-dados-8-conceitos`.)

## 2. Criptografia

Protege login, mensagens e pagamentos:

- **Hashing**: transforma dados em uma "impressão digital" **irreversível** (senha → hash; sites guardam o hash, nunca a senha).
- **Simétrica**: mesma chave para encriptar/decifrar — rápida, mas como compartilhar a chave com segurança?
- **Assimétrica**: **chave pública** encripta (qualquer um pode ter) + **chave privada** decifra (só você). É como o **HTTPS** funciona: o navegador usa a chave pública do servidor; só o servidor decifra com a privada.

## 1. Abstração — o conceito mais importante

Abstração é **esconder a complexidade atrás de uma interface simples** — e aparece em todos os outros nove:

- Dirigir: o volante é uma abstração (não precisa saber de direção, fluido hidráulico, rodas).
- `fetch()`: você não precisa saber como o TCP garante entrega, como o IP roteia, como bits viram sinais.
- Estruturas de dados abstraem como a memória organiza bits; compiladores abstraem a tradução; bancos abstraem a persistência.

**Toda evolução da computação é uma nova camada de abstração**: assembly abstraiu o binário; C abstraiu assembly; Python abstraiu C. Sem abstração, cada programa lidaria com tudo — do transistor ao pixel. Com ela, `print("hello world")` funciona.

## Conclusão

> Não precisa decorar tudo hoje — mas entendendo a **essência de cada conceito**, você reconhece padrões em qualquer tecnologia nova que aparecer.

## Exemplo de código — os conceitos em 4 blocos (Python 3.14)

### 1. Binário, lógica booleana e hash

```python
# Python 3.14 — binario + portas logicas + hash irreversivel
a, b = 0b1010, 0b1100
print('and:', bin(a & b))    # 1000
print('or :', bin(a | b))    # 1110
print('not:', bin(~a & 0b1111))  # 0101

import hashlib
print('sha256:', hashlib.sha256(b'senha123').hexdigest()[:16])
# and: 0b1000
# or : 0b1110
# not: 0b101
# sha256: 55a5e9e78207b4df
```

### 2. Estruturas de dados: lista vs árvore (busca)

```python
# Python 3.14 — busca linear vs arvore binaria (recursiva)
def busca_linear(lista, alvo):
    for i, v in enumerate(lista):
        if v == alvo: return i
    return -1

class No:
    def __init__(self, v):
        self.v, self.esq, self.dir = v, None, None

def inserir(raiz, v):
    if raiz is None: return No(v)
    if v < raiz.v: raiz.esq = inserir(raiz.esq, v)
    else:          raiz.dir = inserir(raiz.dir, v)
    return raiz

def busca_arvore(no, alvo, passos=0):
    if no is None: return -1
    if alvo == no.v: return passos
    return busca_arvore(no.esq if alvo < no.v else no.dir, alvo, passos + 1)

dados = list(range(1, 1001))
raiz = None
# insere em ordem balanceada (nao sequencial!) para a arvore ficar equilibrada
def inserir_balanceado(inicio, fim):
    if inicio > fim: return
    meio = (inicio + fim) // 2
    global raiz
    raiz = inserir(raiz, meio)
    inserir_balanceado(inicio, meio - 1)
    inserir_balanceado(meio + 1, fim)

inserir_balanceado(1, 1000)
print('linear :', busca_linear(dados, 999), 'passos')
print('arvore :', busca_arvore(raiz, 999), 'passos')
# linear : 998 passos
# arvore : 8 passos
```

### 3. Recursão + Big O: fatorial e Fibonacci

```python
# Python 3.14 — recursao: fatorial (linear) e fib (exponencial)
def fatorial(n):
    if n <= 1: return 1            # caso base
    return n * fatorial(n - 1)     # caso recursivo

def fib(n):
    if n < 2: return n
    return fib(n - 1) + fib(n - 2) # O(2^n) — sobe a pilha e desce

print('fatorial(5):', fatorial(5))   # 120
print('fib(20)    :', fib(20))       # 6765 (O(2^n): 20 ja demora)
# fatorial(5): 120
# fib(20)    : 6765
```

### 4. Race condition (concorrência)

```python
# Python 3.14 — race: duas "threads" leem e gravam o mesmo saldo
import threading, time
saldo = {'v': 100}

def sacar_50():
    leitura = saldo['v']        # as duas leem 100
    time.sleep(0.001)           # forca troca de thread aqui (race!)
    saldo['v'] = leitura - 50   # as duas gravam 50

t1 = threading.Thread(target=sacar_50)
t2 = threading.Thread(target=sacar_50)
t1.start(); t2.start(); t1.join(); t2.join()
print('saldo final:', saldo['v'])   # 50, deveria ser 0!
# saldo final: 50
```

O exemplo mostra o problema central da concorrência: mesmo em Python (GIL), a **leitura + escrita não é atômica** — duas threads podem ler o mesmo valor e gravar o mesmo resultado, perdendo uma atualização. (Detalhes e solução com lock no vídeo/SO: `so-por-baixo-dos-panos`.)