# Resumo — "System Design: SQL vs NoSQL" (pt-BR, ~7:43)

Fonte: https://www.youtube.com/watch?v=ILt31254Up4
Data: 30/08/2026 | Transcrição: /tmp/tr_sd4.json

## Tese central

> Relacional ou não relacional? A resposta é sempre **"depende"** — depende do formato dos seus dados, das consultas que você faz e das garantias que você precisa.

## SQL: linguagem dos bancos relacionais

- Dados em **tabelas** com **colunas definidas** (esquema fixo): cada linha = registro, cada coluna = atributo, tudo **estruturado e tipado**.
- **Relacional** vem dos relacionamentos entre tabelas: `pedidos` referencia `usuarios` por um ID.
- **JOIN**: com uma query você combina várias tabelas. Ex.: trazer o nome do usuário junto com os pedidos dele.
- Para isso, o banco precisa **conhecer o esquema** antes — você define colunas e tipos. Inserir texto onde era número → **erro**.
- MySQL, PostgreSQL, SQL Server, Oracle.

## NoSQL: tudo que não é relacional

Família de bancos, cada tipo resolvendo um problema:

| Tipo | Exemplo | Uso |
|---|---|---|
| Documento | MongoDB, CouchDB | dados em JSON, sem formatos fixos |
| Chave-valor | Redis, DynamoDB | hashmap gigante, velocidade |
| Colunar | Cassandra, Redshift | leitura otimizada de colunas específicas |
| Grafo | Neo4j | relacionamentos complexos |

- **Desnormaliza**: em vez de separar `usuarios` e `pedidos`, guarda os pedidos **dentro** do documento do usuário → tudo em **uma leitura**.
- **Esquema flexível ou inexistente**: cada documento pode ter campos diferentes; não precisa migrar tabela para adicionar campo.
- Acelera desenvolvimento, **mas exige disciplina** (dados duplicados precisam de cuidado).

## Garantias: ACID vs BASE

### ACID (relacionais)
- **Atomicidade**: transação executa completa ou não executa nada. Transferir = debitar E creditar, ou nenhum dos dois.
- **Consistência**: o banco respeita as regras — não existe pedido sem usuário.
- **Isolamento**: transações paralelas não interferem entre si.
- **Durabilidade**: se confirmou, está salvo (mesmo se a luz cair).
- Lugar certo: **consistência crítica** — banco, estoque, dinheiro, recursos limitados.

### BASE (muitos NoSQL)
- **Basically Available**: sempre responde, mesmo com dado desatualizado.
- **Soft state**: o estado pode mudar sem input.
- **Eventually consistent**: todos os nós concordam, mas **não imediatamente**.
- Exemplo do vídeo: você posta uma foto, um servidor confirma; o amigo em outro servidor não vê na hora, mas alguns segundos depois aparece. **Rede social: aceitável. Banco: talvez não.**

## Como cada um escala

- **SQL**: tradicionalmente **vertical** para escrita (réplicas só para leitura; escrita vai para um servidor só) → **gargalo** conforme a carga sobe.
- **NoSQL** (muitos): desenhado para **horizontal** — dados particionados entre nós, escrita e leitura distribuídas. Mas **abre mão do ACID** em troca de escalabilidade. É um **tradeoff**.

## Consultas: flexibilidade vs previsibilidade

- **SQL**: flexível — joins, filtros complexos, agregações, ordenação. "Você pode perguntar qualquer coisa para seus dados."
- **NoSQL**: otimizado para **buscar por chave** — `SELECT * FROM usuarios WHERE id = 123` é instantâneo. Mas "todos que compraram X no mês passado" pode ser **lento ou impossível** (join entre coleções geralmente não existe — faz na aplicação).
- **Modelagem**: no relacional você modela os dados e depois faz as queries; no NOSQL você **precisa saber as queries antes de modelar**. Se o padrão de acesso mudar, talvez precise reestruturar tudo.

## Quando usar cada um

### Relacional
- Dados bem definidos e **relacionados** (usuários, pedidos, produtos, pagamentos).
- **Transações ACID** — fintech, e-commerce, dinheiro.
- Consultas **complexas e variadas** — relatórios, analytics, dashboards.
- Integridade dos dados importa mais que performance — sistemas financeiros, ERPs, CRMs.

### NoSQL
- Esquema **muda o tempo todo** — startups iterando rápido, dados semiestruturados.
- **Escala horizontal massiva** — milhões de operações por segundo.
- Dados desnormalizados fazem sentido — perfis, catálogos, logs.
- Padrão de acesso **previsível** — sempre busca por ID, sempre grava no mesmo formato.
- Casos: feeds de redes sociais, cache/sessões (chave-valor puro), IoT/telemetria, jogos/rankings/inventários.

## Poliglota persistence: o mundo real

Sistemas grandes usam **vários tipos de banco**, cada um para seu problema: PostgreSQL para transações, Redis para cache/sessões, Elasticsearch para busca textual. **Ferramenta certa para o caso certo** — mas com custo de operação.

⚠️ **Não comece assim**. Comece com **um banco só** e adicione outros quando a necessidade for real. Complexidade prematura é tão ruim quanto escala prematura.

## Regra de ouro

> Em dúvida? **Comece com relacional.** É mais flexível para consultar e mais seguro para dados críticos. Migre para NoSQL quando tiver um problema real que o relacional não resolve.

## Exemplo de código — transação ACID com rollback (Python 3.14)

```python
# Python 3.14 — atomicidade: debitar + creditar, ou nada (rollback)
class Conta:
    def __init__(self, saldo): self.saldo = saldo

def transferir(origem, destino, valor):
    backup = (origem.saldo, destino.saldo)   # salva estado
    origem.saldo -= valor
    if origem.saldo < 0:                     # violou regra -> desfaz
        print("REJEITADO (sem saldo) -> rollback")
        origem.saldo, destino.saldo = backup
        return False
    destino.saldo += valor
    return True

a, b = Conta(100), Conta(50)
ok = transferir(a, b, 70)
print("transferiu 70:", ok, "| a:", a.saldo, "b:", b.saldo)
ok = transferir(a, b, 999)   # a tem 30 -> rejeita e desfaz
print("transferiu 999:", ok, "| a:", a.saldo, "b:", b.saldo)
# transferiu 70: True | a: 30 b: 120
# REJEITADO (sem saldo) -> rollback
# transferiu 999: False | a: 30 b: 120
```

É assim que o **A** de ACID funciona na prática: a transação é um bloco único — se qualquer passo falhar (aqui, saldo insuficiente), **nada** é aplicado. Um banco relacional garante isso com `BEGIN`/`COMMIT`/`ROLLBACK` (e isolamento entre transações concorrentes).