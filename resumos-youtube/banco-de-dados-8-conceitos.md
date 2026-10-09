# Resumo — "8 conceitos que fazem um Banco de Dados funcionar" (pt-BR, ~11:40)

Fonte: https://www.youtube.com/watch?v=wNM8wETFss4
Data: 30/08/2026 | Transcrição: /tmp/tr_bdados.json

## Tese central

Você confirma um Pix. Em poucos milissegundos o banco muda bytes na memória, grava um log no disco e **promete que o dado não vai sumir**. Este vídeo abre a caixa preta do banco relacional: como uma mensagem do back end vira dado persistido.

## Pontos-chave

- **Banco roda como processo/serviço** que recebe comandos por uma conexão (sessão com usuário, permissões, transação aberta).
- **SELECT lê; INSERT/UPDATE/DELETE muda estado.** Por baixo, o banco combina 3 coisas: achar os dados, controlar quem vê/muda cada linha e garantir sobrevivência a falhas.
- **Páginas.** O banco não busca linha solta; organiza o armazenamento em páginas (blocos com várias linhas). 1.000 linhas espalhadas = lento; 1.000 próximas = barato. Modelagem e índices definem esse caminho.
- **Buffer pool.** Cache interno de páginas na memória. Buffer hit = página já está lá; miss = buscar do disco. Query fica mais rápida depois da 1ª execução. Memória limitada → quando enche, escolhe páginas para despejar; página modificada vira *dirty page* (cópia na memória mudou, disco ainda não).
- **WAL (write-ahead log).** Antes de gravar a página final, o banco grava a mudança **no log** (disco seguro). Só depois responde **commit OK**. A página pode ser gravada depois — por isso commit é rápido.
- **Durabilidade.** Se o processo cair após o commit, na inicialização o banco lê o log, **reaplica** o confirmado e **descarta/desfaz** o não confirmado. Commit OK significa: tenho informação suficiente para reconstruir o estado confirmado.
- **Transações e atomicidade.** Mudanças que só fazem sentido juntas (debita R$100 de A, credita R$100 em B). BEGIN agrupa, COMMIT confirma o grupo, ROLLBACK cancela tudo. Tudo junto ou nada.
- **Concorrência.** Dois Pix debitando a mesma conta ao mesmo tempo → perda de atualização. Locks travam dados; MVCC (multi-version concurrency control) mantém versão antiga por um tempo: leitura que começou antes continua vendo a antiga, escrita cria a nova. Extrato não trava por causa de um Pix.
- **Isolamento.** "Qual versão dos dados essa transação enxerga?" Read Committed: cada comando vê o que já foi confirmado (duas leituras na mesma transação podem ver saldos diferentes). Repeatable Read: visão estável, mesma leitura 2x. Mais isolamento = menos surpresa, mais espera/lock/retry. A aplicação escolhe o nível conforme o risco (debita = rígido; extrato antigo = frouxo).
- **Índices (B-tree).** Estrutura auxiliar que acha linha sem testar página por página. Índice por (account_id, created) acelera extrato. Mas índice também é dado: ocupa espaço, entra no log, precisa de manutenção a cada escrita. Índice demais pesa — a pergunta vem do produto (qual tela precisa responder rápido?).
- **Manutenção de bastidor.** Com o tempo: páginas sujas, versões antigas, índices maiores, estatísticas desatualizadas. Vacuum/compaction/purge/analyze limpam versões que ninguém enxerga mais e atualizam estatísticas. Performance piora com o tempo mesmo com a query igual.
- **Checkpoint e recovery.** De vez em quando o banco grava páginas sujas e registra até onde foi no log (checkpoint). Após queda, lê o log **desde o checkpoint**: refaz confirmadas, descarta incompletas. Checkpoint recente = recovery rápido.
- **Banco ≠ arquivo.** Um arquivo guarda bytes; um banco põe regras em volta: páginas em memória, índices, log antes do commit, transações, locks/snapshots, validação (chave única, FK) e recuperação. `db.save()` é muito mais que jogar linha num arquivo — é o acordo entre memória, disco, log e concorrência.

## Exemplos de código — os 3 pilares

Validação real: 3 exemplos rodam (Python 3.14, Java 26, Go 1.26) sem dependências; comentários explicam o papel de WAL/MVCC.

### 1. WAL: o log antes do commit

```python
# Python 3.14 — write-ahead log simulado
import json, os

LOG = '/tmp/wal.log'

def write_wal(tx_id, entries):
    """Grava ANTES de mudar o 'disco' (arquivo de dados)."""
    with open(LOG, 'a') as f:
        f.write(json.dumps({'tx': tx_id,
                            'entries': entries}) + '\n')

def apply(entries):
    """Aplica no arquivo de dados (pode ser depois)."""
    data = {}
    if os.path.exists('/tmp/data.json'):
        data = json.load(open('/tmp/data.json'))
    for k, v in entries.items():
        data[k] = data.get(k, 0) + v
    json.dump(data, open('/tmp/data.json', 'w'))

def commit(tx_id, entries):
    write_wal(tx_id, entries)  # 1. log primeiro
    apply(entries)             # 2. disco depois
    return 'commit OK'

# Simula queda entre o log e o apply:
write_wal('tx-1', {'a': -100, 'b': 100})
print('caiu antes do apply — log tem o registro')
# Replay na subida:
print(open(LOG).read().strip())
```

```java
// Java 26 — WAL: log antes do commit
import java.nio.file.*;
import java.util.*;

public class WalDemo {
  static void wal(String tx, String entries)
      throws Exception {
    // grava ANTES de mudar o arquivo de dados
    Files.writeString(Path.of("/tmp/wal.log"),
        tx + " " + entries + "\n",
        StandardOpenOption.CREATE, StandardOpenOption.APPEND);
  }
  public static void main(String[] a)
      throws Exception {
    wal("tx-1", "{\"a\":-100,\"b\":100}");
    wal("tx-2", "{\"a\":50,\"b\":-50}");
    System.out.println(
        "log (replay na subida):");
    System.out.println(Files.readString(
        Path.of("/tmp/wal.log")));
  }
}
```

```go
// Go 1.26 — WAL: log antes do commit
package main

import (
	"fmt"
	"os"
)

func wal(tx, entry string) {
	f, _ := os.OpenFile("/tmp/wal.log",
		os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	defer f.Close()
	fmt.Fprintf(f, "%s %s\n", tx, entry)
}

func main() {
	wal("tx-1", `{"a":-100,"b":100}`)
	wal("tx-2", `{"a":50,"b":-50}`)
	fmt.Println("log (replay na subida):")
	b, _ := os.ReadFile("/tmp/wal.log")
	fmt.Print(string(b))
}
```

### 2. Transação: tudo ou nada

```python
# Python 3.14 — transação com rollback
class Transacao:
    def __init__(self, saldos):
        self.saldos = saldos
        self._backup = None
    def begin(self):
        self._backup = dict(self.saldos)  # snapshot
    def debitar(self, c, v):
        if self.saldos[c] < v:
            raise ValueError('saldo insuficiente')
        self.saldos[c] -= v
    def creditar(self, c, v):
        self.saldos[c] += v
    def commit(self):
        self._backup = None  # confirma
    def rollback(self):
        self.saldos = dict(self._backup)  # desfaz

t = Transacao({'a': 100, 'b': 0})
t.begin()
t.debitar('a', 100); t.creditar('b', 100)
t.commit()
print(t.saldos)  # {'a': 0, 'b': 100}

t.begin()
try:
    t.debitar('a', 999)  # estoura
except ValueError:
    t.rollback()
print(t.saldos)  # volta ao estado anterior
```

```java
// Java 26 — transação com rollback
import java.util.*;

public class TxDemo {
  static class Tx {
    HashMap<String, Integer> saldos;
    HashMap<String, Integer> backup = null;
    Tx(HashMap<String, Integer> s) { saldos = s; }

    void begin() { backup = new HashMap<>(saldos); }
    void debitar(String c, int v) {
      if (saldos.get(c) < v)
        throw new IllegalArgumentException();
      saldos.put(c, saldos.get(c) - v);
    }
    void creditar(String c, int v) {
      saldos.put(c, saldos.get(c) + v);
    }
    void commit() { backup = null; }
    void rollback() {
      saldos.clear(); saldos.putAll(backup);
    }
  }
  public static void main(String[] a) {
    var t = new Tx(new HashMap<>(Map.of("a", 100, "b", 0)));
    t.begin(); t.debitar("a", 100); t.creditar("b", 100); t.commit();
    System.out.println(t.saldos); // {a=0, b=100}
    t.begin();
    try { t.debitar("a", 999); }
    catch (IllegalArgumentException e) { t.rollback(); }
    System.out.println(t.saldos); // {a=0, b=100} (voltou)
  }
}
```

```go
// Go 1.26 — transação com rollback
package main

import (
	"fmt"
	"log"
)

type Tx struct {
	saldos map[string]int
	backup map[string]int
}

func (t *Tx) begin() { t.backup = mapsClone(t.saldos) }

func (t *Tx) debitar(c string, v int) {
	if t.saldos[c] < v {
		log.Fatal("saldo insuficiente") // p/ simplicidade
	}
	t.saldos[c] -= v
}

func (t *Tx) creditar(c string, v int) { t.saldos[c] += v }

func (t *Tx) commit()   { t.backup = nil }
func (t *Tx) rollback() { t.saldos = mapsClone(t.backup) }

func mapsClone(m map[string]int) map[string]int {
	out := make(map[string]int, len(m))
	for k, v := range m {
		out[k] = v
	}
	return out
}

func main() {
	t := &Tx{saldos: map[string]int{"a": 100, "b": 0}}
	t.begin()
	t.debitar("a", 100)
	t.creditar("b", 100)
	t.commit()
	fmt.Println(t.saldos) // map[a:0 b:100]
	if t.saldos["a"] < 999 {
		t.begin()
		t.rollback()
	}
	fmt.Println(t.saldos) // map[a:0 b:100]
}
```

### 3. MVCC: leitura não bloqueia escrita

```python
# Python 3.14 — MVCC simulado (versões por linha)
# Leitura que começou antes continua vendo a versão antiga,
# mesmo que outra transação escreva no meio.

class MVCC:
    def __init__(self):
        self.versions = {}  # chave -> [(versao, tx_id)]
    def write(self, key, value, tx_id):
        self.versions.setdefault(key, []).append(
            (value, tx_id))
    def read(self, key, tx_id):
        # vê a última versão visível p/ tx (tx_id de escrita
        # deve ser menor que a da leitura — simplificado)
        for value, wtx in reversed(self.versions[key]):
            if wtx <= tx_id:
                return value
        return None

db = MVCC()
db.write('saldo', 100, 1)   # tx1 escreve 100
db.write('saldo', 90, 2)    # tx2 escreve 90  (pix)
print(db.read('saldo', 1))  # tx1 vê 100 (snapshot antigo)
print(db.read('saldo', 2))  # tx2 vê 90  (nova)
```

```java
// Java 26 — MVCC simulado
import java.util.*;

public class MvccDemo {
  record Ver(int value, int tx) {}
  static Map<String, List<Ver>> versions = new HashMap<>();

  static void write(String k, int v, int tx) {
    versions.computeIfAbsent(k, x -> new ArrayList<>())
        .add(new Ver(v, tx));
  }
  static Integer read(String k, int tx) {
    var list = versions.get(k);
    if (list == null) return null;
    for (int i = list.size() - 1; i >= 0; i--)
      if (list.get(i).tx() <= tx) return list.get(i).value();
    return null;
  }
  public static void main(String[] a) {
    write("saldo", 100, 1);
    write("saldo", 90, 2);  // pix
    System.out.println(read("saldo", 1)); // 100
    System.out.println(read("saldo", 2)); // 90
  }
}
```

```go
// Go 1.26 — MVCC simulado
package main

import "fmt"

type Ver struct {
	value int
	tx    int
}

var versions = map[string][]Ver{}

func write(k string, v, tx int) {
	versions[k] = append(versions[k], Ver{v, tx})
}

func read(k string, tx int) (int, bool) {
	list := versions[k]
	for i := len(list) - 1; i >= 0; i-- {
		if list[i].tx <= tx {
			return list[i].value, true
		}
	}
	return 0, false
}

func main() {
	write("saldo", 100, 1)
	write("saldo", 90, 2) // pix
	fmt.Println(read("saldo", 1)) // 100
	fmt.Println(read("saldo", 2)) // 90
}
```

## Mapa mental — os 8 em uma linha

1. Páginas (blocos de linhas) · 2. Buffer pool (cache de páginas) · 3. WAL (log antes do commit) · 4. Durabilidade (replay na subida) · 5. Transações (tudo ou nada) · 6. Locks + MVCC (leitura não bloqueia escrita) · 7. Isolamento (qual versão você vê) · 8. Índices + vacuums + checkpoints (manutenção).

## Aviso final do vídeo

"É isso. Se curtiu, se inscreve e deixa um like, que ajuda bastante o canal. Valeu."