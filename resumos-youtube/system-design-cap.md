# Resumo — "System Design: Teorema CAP" (pt-BR, ~8:02)

Fonte: https://www.youtube.com/watch?v=g9DfXmDfE_Q
Data: 30/08/2026 | Transcrição: /tmp/tr_sd1.json

## Tese central

> Não existe banco de dados que nunca cai, responde instantaneamente e nunca perde dados. O **teorema CAP** explica por quê.

O CAP foi proposto por **Eric Brewer (2000)** e provado matematicamente em **2002**. Quando a rede entre servidores falha (partição), você é **forçado** a escolher entre consistência e disponibilidade.

## Partição não é uma escolha

- **C — Consistency (consistência forte)**: todo mundo vê o mesmo dado ao mesmo tempo. Se uma escrita terminou, toda leitura seguinte retorna o valor novo — em qualquer servidor.
- **A — Availability (disponibilidade)**: toda requisição recebe resposta, sem timeout infinito. O servidor pode responder dado **desatualizado** — disponibilidade não é "dado mais recente".
- **P — Partition tolerance**: o sistema continua operando mesmo com falhas de rede.

**O P não é uma escolha**: cabos quebram, switches falham, data centers são isolados, timeouts estouram. Partição **vai acontecer**. A escolha real é: quando a partição ocorrer, você sacrifica C ou A.

### Split brain (cérebro dividido)

O cenário clássico: data center A acha que o B morreu, o B acha que o A morreu, e os dois seguem operando. Cliente em A atualiza o preço para R$ 100; cliente em B atualiza para R$ 150. Qual é o preço? **Depende de qual servidor você pergunta.** Quando a rede volta, há um conflito — e conflito precisa de resolução.

## CP vs AP na prática

### Sistema CP (consistência forte durante a partição)
- Serve para casos onde **dado errado é catástrofe** (saldo bancário, estoque, ingressos).
- Técnicas: **quórum** (a escrita precisa da maioria — 3 de 5, 2 de 3) e **eleição de líder** (só o lado com o líder aceita escritas; o outro retorna 503).
- Exemplo: **MongoDB** com réplica sets — sem maioria, os servidores viram somente leitura. **etcd/ZooKeeper** — coordenação, configuração, eleição de líder (dois líderes = problema). **Google Spanner** — consistência forte global com relógios atômicos/GPS, com custo alto.

### Sistema AP (disponibilidade durante a partição)
- Serve para casos onde **atraso de dado é aceitável** (feed de Twitter atrasado 2 segundos).
- Problema: conflitos acumulam nos dois lados; quando a rede volta, precisa de **reconciliação**.
- Estratégia comum: **last-write-wins** (timestamp mais recente ganha) — simples, mas pode perder dados.
- Exemplo: **Cassandra** — consistência configurável (você escolhe quantos nós confirmam). **DynamoDB** — opção explícita: leitura fortemente consistente (lê do líder, pode falhar) vs eventualmente consistente (sempre disponível). **CouchDB** — guarda versões como um git: mantém os dois lados e a aplicação decide.

## PACELC: o CAP é só metade da história

O CAP só fala do cenário de **partição** — mas 99% do tempo a rede funciona. O **PACELC** estende:

- **P**artição → escolha entre **A** e **C**
- **E**lse → escolha entre **L**atência e **C**onsistência

Mesmo sem partição há tradeoff: consistência forte exige coordenação, coordenação adiciona latência. DynamoDB = disponível, baixa latência. Spanner = consistente, aceita latência extra. Cassandra = depende da configuração.

## Decisão prática

1. **Custo de dado errado vs custo de sistema fora do ar**: saldo bancário errado = catástrofe → CP. Feed atrasado = ninguém nota → AP.
2. **Não precisa escolher para o sistema todo**: o mesmo banco pode ter transações financeiras com consistência forte e analytics com consistência eventual.
3. **Entenda as garantias reais** do seu banco: "consistência forte" significa coisas diferentes em bancos diferentes.
4. **Documente a decisão** e teste o comportamento do sistema **durante a partição** (caos engineering).

## Conclusão

CAP não é limitação de engenharia — é **limitação física**: informação não viaja instantaneamente. Sistemas distribuídos são feitos de tradeoffs; a escolha consciente é o que define um bom arquiteto.

## Exemplo de código — simulação de quórum (Python 3.14)

```python
# Python 3.14 — quorum: so o lado com a maioria aceita escrita (CP)
class Cluster:
    def __init__(self, nos):
        self.nos = {n: {"valor": 0, "ativo": True} for n in nos}
        self.lider = nos[0]

    def particao(self, grupo_a, grupo_b):
        # simula split brain: cada grupo ve so os no do proprio lado
        for n in grupo_a:
            self.nos[n]["ativo"] = False  # invisivel para o outro lado
        return

    def quorum(self, grupo):
        # maioria = mais da metade de TODOS os nos (nao so do grupo)
        return len(grupo) > len(self.nos) / 2

    def escrever(self, no, valor):
        grupo = [n for n in self.nos if n == no or self.lider == n]
        if not self.quorum(grupo):
            return f"ERRO: no {no} sem quorum (minoritario) -> 503"
        self.nos[no]["valor"] = valor
        return f"ok: {no} = {valor}"

    def ler(self, no):
        return self.nos[no]["valor"]

c = Cluster([1, 2, 3])
c.particao([1], [2, 3])
print(c.escrever(1, 100))      # no 1 sozinho = minoritario -> 503
print(c.escrever(2, 200))      # lado 2+3 = maioria -> ok
print("valor no 2:", c.ler(2))
# ERRO: no 1 sem quorum (minoritario) -> 503
# ok: no 2 = 200
# valor no 2: 200
```

O ponto central: durante a partição, o **lado minoritário é bloqueado** (retorna 503) — é assim que um sistema CP evita o split brain aceitar escritas concorrentes.