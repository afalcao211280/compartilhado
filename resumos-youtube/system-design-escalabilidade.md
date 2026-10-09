# Resumo — "System Design: Escalabilidade" (pt-BR, ~11:37)

Fonte: https://www.youtube.com/watch?v=Xiod8w7QtQ4
Data: 30/08/2026 | Transcrição: /tmp/tr_sd2.json

## Tese central

> Escalabilidade é a arte de fazer seu sistema crescer de forma sustentável — mais usuários, mais dados, mais requisições — **sem o usuário final perceber**.

O cenário ideal é escala **linear** (carga dobra → recursos dobram → performance mantida). O mundo real tem gargalos, contenção, limites físicos e de orçamento.

## Duas estratégias fundamentais

### Escalabilidade vertical (escalar para cima)
Tornar o servidor mais potente: mais CPU, RAM, disco, rede.

- **Vantagens**: simples — não muda código nem arquitetura; um servidor só, sem complexidade de distribuição.
- **Problemas**:
  1. **Custo não linear**: 2× a capacidade pode custar 3–4×; 4× pode custar 10×.
  2. **Teto físico**: o maior servidor do mundo ainda é uma máquina; não existe CPU com 1000 cores nem RAM infinita.
  3. **Ponto único de falha**: se cair, tudo cai até reiniciar.

### Escalabilidade horizontal (escalar para o lado)
Usar vários servidores normais e dividir a carga. 10.000 req/s → 10 servidores de 1.000 req/s.

- **Vantagens**: sem limite teórico (adiciona servidores quase infinitamente); custo linear e previsível; tolerância a falhas (se um cai, os outros continuam).
- **Desvantagens**: complexidade — precisa de **load balancer**, garantir que qualquer servidor atenda qualquer requisição, e sincronizar dados (aí cai no **teorema CAP**).

**Regra geral**: vertical é simples mas limitado; horizontal é quase ilimitado mas complexo. A maioria dos grandes sistemas usa horizontal conforme a carga cresce.

## Load Balancer: o maestro

O LB decide qual servidor recebe cada requisição. Algoritmos:

- **Round robin**: alterna 1 → 2 → 3 → 1...
- **Least connections**: manda para o servidor com menos conexões ativas.
- **IP hash**: mesmo IP sempre vai para o mesmo servidor.

### Health checks
O LB fica pingando os servidores; se um não responde, é **removido** da lista; quando volta, é **re-adicionado**.

### L4 vs L7 (camadas do OSI)
- **L4** (transporte): enxerga só IP e porta. Não sabe se é HTTP ou websocket. **Rápido** (não abre o pacote).
- **L7** (aplicação): entende HTTP — roteia por URL, header, cookie (API → servidor A, estático → servidor B). **Mais lento, mais flexível**.

Ferramentas: Nginx, HAProxy, AWS ALB/ELB, Cloudflare.

## Stateless: a regra de ouro

Um servidor **stateful** guarda a sessão em memória → a próxima requisição do mesmo usuário precisa ir para o mesmo servidor. Se o LB manda para outro, é como se o usuário não tivesse logado; se o servidor cai, as sessões somem.

- **Sticky sessions** (afinidade de sessão): o LB sempre manda o mesmo usuário para o mesmo servidor. Funciona, mas perde a distribuição de carga — um servidor pode ficar sobrecarregado enquanto outros ociosos.
- **A solução de verdade é stateless**: o servidor não guarda nada em memória. Sessão → Redis. Arquivos → S3. Dados → banco. O servidor vira **descartável** — pode cair e reviver sem perder nada.

> **Se você quer escalar horizontalmente, seu servidor precisa ser stateless.**

## As três camadas de um sistema web

1. **Camada web** (estáticos: HTML, CSS, JS, imagens) → escala fácil com **CDN** (cópia global do conteúdo; usuário serve do servidor mais próximo fisicamente). CDN é um "cache global".
2. **Camada de aplicação** (lógica, APIs) → escala horizontal com **load balancer** + **stateless** + **auto scaling** (sobe instâncias quando a carga aumenta — ex.: Black Friday — e derruba as ociosas quando diminui).
3. **Camada de dados** → a mais complexa: banco é **stateful por natureza** (é o próprio estado). Estratégias: **replicação** (cópias para leitura) e **sharding** (divisão em vários bancos) — assunto de outro vídeo.

> Na maioria dos sistemas, **o banco é o gargalo**. A aplicação escala fácil; o banco não. Por isso **cache é tão importante**: quanto menos você bater no banco, melhor.

## Quando escalar?

Métricas para acompanhar:
- Latência subindo (100 ms → 500 ms).
- CPU constantemente > 70% sem folga para picos.
- Memória no limite, swap sendo usado.
- Fila de requisições crescendo.

Abordagens:
- **Reativa**: esperar quase quebrar para consertar — mais barato, mais arriscado.
- **Preventiva**: monitorar e escalar antes do problema — mais caro, mais seguro.
- **Ideal**: automatizar com **auto scaling** — ex.: CPU > 70% por 5 min → adiciona servidor; CPU < 30% por 10 min → remove.

⚠️ **Identifique o gargalo antes de escalar**: não adianta adicionar servidores de aplicação se o banco trava; não adianta otimizar código se o problema é rede.

## Decisões práticas

1. **Comece vertical** — simples, funciona, barato no início. Só vá para horizontal quando vertical não der mais conta ou custar demais.
2. **Faça a aplicação stateless desde o começo** — migrar depois é muito pior.
3. **Cache é seu melhor amigo** — antes de escalar, veja se não dá para cachear.
4. **Banco é o gargalo** — planeje cedo como escalar os dados.
5. **Não escale prematuramente** — esteja pronto quando precisar. Arquitetura boa é a que permite escalar sem reescrever tudo.

## Exemplo de código — load balancer round robin (Python 3.14)

```python
# Python 3.14 — round robin + least connections + health check
class LoadBalancer:
    def __init__(self, servidores):
        self.servidores = {s: {"conexoes": 0, "saudavel": True} for s in servidores}
        self.i = 0

    def health_check(self):
        # simulacao: server B caiu
        self.servidores["B"]["saudavel"] = False

    def round_robin(self):
        ativos = [s for s, v in self.servidores.items() if v["saudavel"]]
        if not ativos:
            return None
        s = ativos[self.i % len(ativos)]
        self.i += 1
        return s

    def least_connections(self):
        ativos = [s for s, v in self.servidores.items() if v["saudavel"]]
        if not ativos:
            return None
        return min(ativos, key=lambda s: self.servidores[s]["conexoes"])

lb = LoadBalancer(["A", "B", "C"])
lb.health_check()                 # B sai do pool
print("round robin:", [lb.round_robin() for _ in range(5)])
# round robin: ['A', 'C', 'A', 'C', 'A']  (B removido pelo health check)
```

O health check é o que mantém o pool saudável: quando o B deixa de responder, o LB para de mandar tráfego para ele — e quando volta, o LB o re-adiciona automaticamente.