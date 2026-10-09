# Resumo — "System Design: Cache" (pt-BR, ~7:48)

Fonte: https://www.youtube.com/watch?v=i3Y2NmCGfuA
Data: 30/08/2026 | Transcrição: /tmp/tr_sd3.json

## Tese central

> Cache é guardar uma cópia de algo para não precisar buscar de novo. É tipo comida na geladeira: cozinhar do zero toda vez é caro; esquentar comida pronta é rápido e barato a partir da segunda vez.

Funciona por causa da **localidade temporal**: dados acessados recentemente tendem a ser acessados de novo. O post que viralizou hoje será requisitado milhares de vezes nas próximas horas.

## Hit, miss e hit rate

- **Cache hit**: achou no cache → devolve direto.
- **Cache miss**: não achou → busca no banco, guarda no cache, devolve.
- **Hit rate**: % das requisições respondidas pelo cache.

Cada ponto percentual importa em grande escala: com 1M de requisições, 90% de hit rate = 100.000 batendo no banco; 99% = só 10.000. Banco demora dezenas/centenas de ms; cache em memória < 1 ms. (Contexto: a Uber processa **40+ milhões de req/s** — nenhum banco aguentaria sem cache.)

## Onde cachear (as camadas)

1. **Browser** — guarda estáticos localmente (CSS, JS, imagens). É por isso que um site recarregado carrega instantâneo.
2. **CDN** — servidores espalhados pelo mundo com cópias do conteúdo (usuário pega do mais próximo).
3. **Aplicação** — resultados de queries, respostas de APIs externas, cálculos pesados. **Redis, Memcached**.
4. **Banco de dados** — cache interno (query cache, buffer pool), sem controle granular.

**A camada que você controla é a da aplicação.**

## Estratégias de leitura

- **Cache Aside (Lazy Loading)**: aplicação olha no cache; se achar, devolve; se não, busca no banco, guarda, devolve. Só guarda o que é usado. **A mais comum** — flexível e fácil.
- **Read-Through**: o cache é o responsável por buscar no banco; a aplicação nunca fala direto com o banco. Mais organizado, mas precisa de um cache que suporte.

## Estratégias de escrita e a invalidação

O grande problema: usuário atualiza dado → salvo no banco, mas o cache continua servindo o dado antigo.

- **Write-Through**: toda escrita vai para cache E banco ao mesmo tempo. Consistente, mas escrita mais lenta (2 operações).
- **Write-Behind**: escreve no cache primeiro; o cache sincroniza com o banco depois. Rápido, mas se o cache cair antes de sincronizar, **perde dados**.
- **Invalidação** (a mais comum): quando o dado muda, apaga do cache → a próxima leitura busca o dado novo.

> "Só existem duas coisas difíceis em computação: invalidação de cache e dar nome às coisas." — Phil Karlton

**TTL (Time to Live)**: o dado expira sozinho depois de um tempo. TTL de 5 min = no pior caso, usuário vê dado desatualizado por 5 min. TTL curto = mais consistência, mais miss, mais carga no banco. TTL longo = menos consistência, mais hit, menos carga. O valor certo depende do caso.

## Eviction (remoção de dados)

Cache tem tamanho limitado; quando enche, precisa remover algo:

- **LRU** (Least Recently Used): remove o usado há mais tempo. "Se ninguém pediu faz tempo, provavelmente não vão pedir tão cedo." Simples, funciona na maioria dos casos.
- **LFU** (Least Frequently Used): remove o usado menos vezes. Melhor para dados quentes acessados o tempo todo. O Redis suporta os dois.

## Cache local vs distribuído

- **Local** (em memória, por servidor): mais rápido, mas **não é compartilhado** — o servidor 2 não acessa o cache do servidor 1.
- **Distribuído** (servidor separado — Redis/Memcached): um pouco mais lento (rede), mas **compartilhado** entre todas as instâncias. **Praticamente obrigatório** para quem escala horizontalmente.

## Problemas clássicos

1. **Cache stampede**: o cache expira e 1000 requisições chegam juntas → todas vão ao banco. Solução: **lock** — só uma busca no banco, as outras esperam.
2. **Cold start**: sistema reinicia com cache vazio → tudo vai ao banco até esquentar. Solução: **cache warming** — pré-carrega os dados mais acessados antes de receber tráfego.
3. **Inconsistência**: cache e banco com dados diferentes. Solução: TTLs razoáveis + invalidação explícita; aceitar que consistência perfeita com cache é difícil.

## Quando usar (e quando não)

👍 Cache funciona bem quando:
- O dado é **lido muito mais do que escrito**;
- O custo de buscar é alto (queries lentas, APIs externas);
- **Consistência eventual é aceitável**.

👎 Não cacheie quando:
- O dado **muda o tempo todo**;
- Consistência imediata é crítica (**saldo bancário, estoque**);
- O dado é único por usuário e raramente reutilizado.

## Conclusão

Cache é um tradeoff: ganha velocidade, paga complexidade (invalidação, consistência, eviction). O segredo é saber quando vale a pena — e sua arquitetura tem que ser desenhada pensando nisso desde o início.

## Exemplo de código — cache aside com TTL (Python 3.14)

```python
# Python 3.14 — cache aside + TTL + lock anti-stampede
import time

class Cache:
    def __init__(self):
        self.dados = {}
        self.expira = {}

    def get(self, chave):
        agora = time.time()
        if chave in self.dados and self.expira[chave] > agora:
            return self.dados[chave], "HIT"
        return None, "MISS"

    def set(self, chave, valor, ttl):
        self.dados[chave] = valor
        self.expira[chave] = time.time() + ttl

class Banco:
    def __init__(self):
        self.dados = {"perfil:1": "Ana"}
        self.consultas = 0

    def buscar(self, chave):
        self.consultas += 1
        time.sleep(0.01)            # query "lenta"
        return self.dados[chave]

cache, banco = Cache(), Banco()
lock  = {"preso": False}

def ler(chave):
    valor, status = cache.get(chave)
    if status == "HIT":
        return valor, "hit (banco nao consultado)"
    if lock["preso"]:               # stampede: 2a requisicao espera
        while lock["preso"]: time.sleep(0.001)
        return cache.dados[chave], "hit apos esperar lock"
    lock["preso"] = True
    try:
        valor = banco.buscar(chave)
        cache.set(chave, valor, ttl=2)
    finally:
        lock["preso"] = False
    return valor, "miss -> banco (1x)"

print(ler("perfil:1"))     # 1a: miss -> banco
print(ler("perfil:1"))     # 2a: hit
print("consultas ao banco:", banco.consultas)
# ('Ana', 'miss -> banco (1x)')
# ('Ana', 'hit (banco nao consultado)')
# consultas ao banco: 1
```

O essencial: a **primeira** leitura consome a query; as seguintes são servidas do cache até o TTL expirar. E o lock garante que, durante um stampede (cache expirado + muitas requisições), só **uma** requisição bata no banco.