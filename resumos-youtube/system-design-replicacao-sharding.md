# Resumo — "System Design: Replicação e Sharding" (pt-BR, ~7:21)

Fonte: https://www.youtube.com/watch?v=czMY_ATOej0
Data: 30/08/2026 | Transcrição: /tmp/tr_sd5.json

## Tese central

> A aplicação escala fácil (stateless + load balancer), mas o **banco de dados é stateful por natureza — ele é o estado**. Toda requisição ainda bate no mesmo banco. Para escalar dados, você precisa de **replicação** (escala leitura) e **sharding** (escala escrita).

## O problema: leitura vs escrita

A maioria dos sistemas tem muito mais leitura do que escrita: para cada post criado, milhares leem; para cada pedido, o usuário consulta o status várias vezes. Proporções de 10:1, 50:1, até 100:1.

Se o banco não aguenta a leitura → queries lentas → fila → usuários esperando → experiência ruim.

## Replicação: escala leitura

Fazer cópias do banco: um **primário** (escreve) + várias **réplicas** (leem).

- Toda **escrita → primário**; toda **leitura → qualquer réplica**.
- 10.000 leituras/s ÷ 3 réplicas ≈ 3.300 cada (se balanceadas).
- Precisa de mais leitura? **Adicione mais réplicas.**
- Vantagens: escala horizontal para leitura, **redundância** (se o primário cair...), réplicas em **outras regiões** (latência menor).

### Síncrona vs assíncrona

- **Síncrona**: o primário só confirma a escrita depois que **todas as réplicas gravaram**. Consistente, mas **lento** — cada escrita espera a réplica mais lenta.
- **Assíncrona**: confirma na hora e manda para as réplicas em background. **Rápido**, mas gera **replication lag** (dados podem demorar ms ou segundos para chegar).

A maioria dos sistemas usa **assíncrona** e aceita o tradeoff: consistência perfeita na leitura raramente importa mais que escrita rápida.

### Read-your-writes

Problema: usuário escreve e lê logo em seguida — pode pegar dado desatualizado na réplica. Solução: por alguns segundos após a escrita, **as leituras daquele usuário vão para o primário**. O usuário sempre vê os próprios dados atualizados; os outros podem ter pequeno delay.

⚠️ **Replicação resolve leitura, não escrita.** Toda escrita ainda vai para o mesmo primário. Se a escrita é o gargalo, réplicas não adiantam.

## Sharding: escala escrita

**Sharding** = dividir os dados em pedaços menores chamados **shards**. Cada shard é um **banco independente** com uma parte dos dados.

- Em vez de 1 banco com todos os usuários → 4 bancos com 25% cada.
- **As escritas são distribuídas**: usuária Maria → shard 0, usuário Bruno → shard 3.
- Com 4 shards, cada um recebe ~25% das escritas (se distribuídas uniformemente).
- Precisa de mais capacidade? **Adicione mais shards.**

### Como decidir onde cada dado vai?

1. **Range**: divide por intervalos (IDs 1–1M → shard 0, 1M–2M → shard 1). Simples, mas **perigoso**: se os dados mais acessados caem no mesmo range, um shard sobrecarrega e outros ficam ociosos.
2. **Hash**: aplica função hash no ID e distribui pelo resultado (`hash(id) % N`). Distribuição **uniforme**, evita sobrecarga de um shard. **A mais comum.**
3. **Directory**: tabela de lookup (qual shard guarda qual dado). Flexível, mas a tabela é um **ponto único de falha** — se cair, ninguém sabe onde estão os dados.

### Os problemas do sharding

1. **Joins entre shards**: posts num shard, usuários em outro → join? **Você não faz, ou faz na aplicação** (lento). Dados consultados juntos devem ficar **no mesmo shard**.
2. **Rebalanceamento**: quando um shard enche ou você adiciona mais shards → redistribuir dados. **Caro, lento, pode causar downtime.**
3. **Queries globais**: contar todos os usuários = consultar **todos os shards** e somar; ordenar por data = buscar de todos e ordenar na aplicação.
4. **A complexidade vaza para a aplicação**: você precisa saber qual shard consultar em todo lugar.

> **Sharding é o último recurso, nunca a primeira opção.** Muita empresa escalou a milhões de usuários com um banco bem configurado, índices certos e cache agressivo.

## Combinação na prática

As duas estratégias são complementares: **cada shard tem seu primário e suas próprias réplicas** — sharding distribui a escrita, replicação distribui a leitura dentro de cada shard. Uber, Instagram e Notion usam essa combinação.

Evolução comum: começa com 1 banco → adiciona réplicas quando a leitura pesa → adiciona shards quando a escrita não aguenta. **Cada passo adiciona complexidade — só mude quando precisar.**

## Alternativas modernas

- **PlanetScale, Vitess** — sharding transparente para MySQL (abstraem a complexidade).
- **CockroachDB** e similares — bancos distribuídos que escalam horizontalmente de forma automática.
- Você ainda paga o custo de consistência e latência, mas **não implementa a lógica na mão**. Serviço gerenciado antes de shard próprio.

## Resumo

| Estratégia | Escala | Quando usar |
|---|---|---|
| Réplicas | Leitura | Leitura é o gargalo; simples; adiciona redundância |
| Sharding | Escrita | Já otimizou leitura (cache + réplicas), escrita é o gargalo comprovado |

> **A melhor requisição para o banco é a que você não faz.** Antes de replicar ou shardear, otimize queries e use cache o máximo possível.

## Exemplo de código — hash sharding (Python 3.14)

```python
# Python 3.14 — sharding por hash: qual shard guarda o usuario?
N_SHARDS = 4

def shard_de(user_id):
    return hash(user_id) % N_SHARDS   # resto da divisao = shard

usuarios = ["maria", "bruno", "ana", "carlos", "duda", "elias", "fabio", "gabi"]
shards = {i: [] for i in range(N_SHARDS)}
for u in usuarios:
    shards[shard_de(u)].append(u)

for s, lista in sorted(shards.items()):
    print(f"shard {s}: {lista}")
# ex.: cada shard recebe ~2 usuarios (distribuicao uniforme)
```

A **distribuição uniforme** é o ponto: com `hash(id) % N`, usuários adjacentes caem em shards diferentes, então nenhum shard sobrecarrega. No mundo real, os dados quentes ficam espalhados — e cada shard tem seu próprio primário + réplicas.