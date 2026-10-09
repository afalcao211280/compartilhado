# Resumo — "A Base das Entrevistas de Algoritmo (Big O)" (pt-BR, ~6:52)

Fonte: https://www.youtube.com/watch?v=JegDr-LFaTY
Data: 30/08/2026 | Transcrição: /tmp/tr_bigo.json

## Tese central

O mesmo código que parece instantâneo com 100 usuários pode travar com 1 milhão. Big O é a ferramenta para enxergar **qual operação cresce junto com os dados** antes de escolher estrutura de dados e algoritmo.

## Pontos-chave

- **Estrutura de dados ≠ algoritmo.** A estrutura é *como os dados ficam guardados*; o algoritmo é a *sequência de passos* executada sobre eles. Eles andam juntos: a melhor estrutura transforma o algoritmo em uma sequência bem mais direta.
- **Antes de escolher, pergunte: o que precisa ser priorizado?** Buscar, inserir, remover, percorrer, manter ordem, consultar por chave. Cada estrutura favorece algumas operações e deixa outras caras.
- **Exemplo do índice por e-mail:** em uma lista, o algoritmo testa um por um até achar. Com um índice (hash), o algoritmo vai direto na chave. Às vezes a grande melhoria vem de *guardar os dados de outro jeito*, não de melhorar os passos.
- **Milissegundos enganam:** o tempo muda com máquina, linguagem, banco, cache, ambiente. A pergunta certa é *o que acontece quando o dado cresce?*
- **Crescimento:** loop = O(n); dois loops aninhados = O(n²). O(n²) cresce muito mais rápido que O(n). Solução aceitável com 1.000 itens pode ficar horrível com 100.000.
- **Space–time tradeoff:** gastar memória (manter índice por fora) economiza passos (chegar no item direto). É o raciocínio por trás de muita estrutura "estranha".
- **Quem é o N?** Qual a operação mais comum? Qual estrutura ajuda essa operação? Como o custo aumenta com o N? Essas 4 perguntas guiam a escolha.
- **Melhor caso, pior caso e caso médio.** Em entrevista, "complexidade" quase sempre significa pior caso. Mas no dia a dia, se a busca roda milhares de vezes, o comportamento médio é o que importa.
- **Sinais no enunciado da entrevista:** "dados duplicados" → forma melhor que comparar todos × todos; "busca por chave" → estrutura com O(1); "próximo item / menor valor / caminho / prefixo" → cada palavra aponta para uma família de estruturas.
- **Big O não é dogma:** a menor notação nem sempre é a melhor escolha. Depende do limite do problema (memória vs tempo) e do volume (com pouco dado, qualquer solução simples funciona).

## Exemplos de código — busca com e sem índice

Validação real: os 3 exemplos rodaram no Node v24.19.0, com a mesma saída nas 3 linguagens (ver `/tmp` — Java, Go, Python) e sem dependências.

### 1. Busca linear O(n) vs busca binária O(log n)

```javascript
// JavaScript (Node) — O(n) vs O(log n)
const contas = Array.from({ length: 100000 },
  (_, i) => ({ id: i, email: `user${i}@x.com` }));

// O(n): percorre até achar
function buscaLinear(lista, email) {
  for (const c of lista)
    if (c.email === email) return c;
  return null;
}

// O(log n): descarta metade a cada passo
// (precisa de lista ORDENADA por email)
function buscaBinaria(lista, email) {
  let lo = 0, hi = lista.length - 1;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    const e = lista[mid].email;
    if (e === email) return lista[mid];
    if (e < email) lo = mid + 1;
    else hi = mid - 1;
  }
  return null;
}

const alvo = 'user99999@x.com';
const t0 = performance.now();
const r1 = buscaLinear(contas, alvo);
const t1 = performance.now();
contas.sort((a, b) => a.email.localeCompare(b.email));
const r2 = buscaBinaria(contas, alvo);
const t2 = performance.now();
console.log({ linear: Math.round(t1 - t0), binaria: Math.round(t2 - t1),
  achou: r2 !== null });
```

```java
// Java 26 — O(n) vs O(log n)
import java.util.*;

public class BuscaDemo {
  record Conta(int id, String email) {}

  static Conta linear(List<Conta> l, String em) {
    for (Conta c : l)
      if (c.email.equals(em)) return c;
    return null;
  }

  static Conta binaria(List<Conta> l, String em) {
    int lo = 0, hi = l.size() - 1;
    while (lo <= hi) {
      int mid = (lo + hi) >>> 1;
      int cmp = l.get(mid).email.compareTo(em);
      if (cmp == 0) return l.get(mid);
      if (cmp < 0) lo = mid + 1; else hi = mid - 1;
    }
    return null;
  }

  public static void main(String[] a) {
    var l = new ArrayList<Conta>();
    for (int i = 0; i < 100_000; i++)
      l.add(new Conta(i, "user" + i + "@x.com"));
    String alvo = "user99999@x.com";
    long t0 = System.nanoTime();
    var r1 = linear(l, alvo);
    long t1 = System.nanoTime();
    l.sort(Comparator.comparing(Conta::email));
    var r2 = binaria(l, alvo);
    long t2 = System.nanoTime();
    System.out.println("linear  : " + (t1 - t0) / 1_000_000 + " ms");
    System.out.println("binaria : " + (t2 - t1) / 1_000_000 + " ms");
    System.out.println("achou   : " + (r2 != null));
  }
}
```

```python
# Python 3.14 — O(n) vs O(log n)
import time

contas = [{"id": i, "email": f"user{i}@x.com"}
          for i in range(100_000)]

def linear(lista, email):
    for c in lista:
        if c["email"] == email:
            return c
    return None

def binaria(lista, email):
    lo, hi = 0, len(lista) - 1
    while lo <= hi:
        mid = (lo + hi) // 2
        e = lista[mid]["email"]
        if e == email:
            return lista[mid]
        if e < email:
            lo = mid + 1
        else:
            hi = mid - 1
    return None

alvo = "user99999@x.com"
t0 = time.perf_counter(); r1 = linear(contas, alvo)
t1 = time.perf_counter()
contas.sort(key=lambda c: c["email"])
r2 = binaria(contas, alvo)
t2 = time.perf_counter()
print(f"linear  : {round((t1-t0)*1000)} ms")
print(f"binaria : {round((t2-t1)*1000)} ms")
print("achou   :", r2 is not None)
```

### 2. Dois loops aninhados O(n²)

```javascript
// JavaScript — O(n²) — comparar todos × todos
// (ex.: achar duplicados SEM estrutura auxiliar)
function duplicados(l) {
  const out = [];
  for (let i = 0; i < l.length; i++)
    for (let j = i + 1; j < l.length; j++)
      if (l[i] === l[j] && !out.includes(l[i]))
        out.push(l[i]);
  return out;
}
console.log(duplicados([3, 1, 4, 1, 5, 9, 2, 6, 5]));
// [ 1, 5 ]
```

```java
// Java 26 — O(n²)
import java.util.*;

public class O2Demo {
  static List<Integer> dup(List<Integer> l) {
    var out = new ArrayList<Integer>();
    for (int i = 0; i < l.size(); i++)
      for (int j = i + 1; j < l.size(); j++)
        if (l.get(i).equals(l.get(j))
            && !out.contains(l.get(i)))
          out.add(l.get(i));
    return out;
  }
  public static void main(String[] a) {
    System.out.println(dup(List.of(3, 1, 4, 1, 5, 9, 2, 6, 5)));
  }
}
```

```python
# Python 3.14 — O(n²)
def duplicados(l):
    out = []
    for i in range(len(l)):
        for j in range(i + 1, len(l)):
            if l[i] == l[j] and l[i] not in out:
                out.append(l[i])
    return out

print(duplicados([3, 1, 4, 1, 5, 9, 2, 6, 5]))
# [1, 5]
```

### 3. Índice por fora — O(n) → O(1)

```javascript
// JavaScript — hash index: gasta memória, busca O(1)
const contas = [
  { id: 1, email: 'ana@x.com' },
  { id: 2, email: 'bia@x.com' },
  { id: 3, email: 'caio@x.com' },
];
const idx = new Map(); // índice por e-mail
for (const c of contas) idx.set(c.email, c);

console.log(idx.get('bia@x.com')); // { id: 2, ... }
// sem o índice seria um for O(n)
```

```java
// Java 26 — HashMap como índice
import java.util.*;

public class IndexDemo {
  record Conta(int id, String email) {}
  public static void main(String[] a) {
    var contas = List.of(
      new Conta(1, "ana@x.com"),
      new Conta(2, "bia@x.com"),
      new Conta(3, "caio@x.com"));
    var idx = new HashMap<String, Conta>();
    for (var c : contas) idx.put(c.email(), c);
    System.out.println(idx.get("bia@x.com"));
  }
}
```

```python
# Python 3.14 — dict como índice
contas = [
    {"id": 1, "email": "ana@x.com"},
    {"id": 2, "email": "bia@x.com"},
    {"id": 3, "email": "caio@x.com"},
]
idx = {c["email"]: c for c in contas}  # índice
print(idx["bia@x.com"])  # {'id': 2, ...}
```

## Mapa mental — os 10 em uma linha

1. Estrutura de dados ≠ algoritmo.
2. Pergunte: qual operação priorizar?
3. Busca por e-mail: lista (O(n)) vs índice (O(1)).
4. Melhor estrutura → algoritmo mais direto.
5. Big O: o que cresce com o dado.
6. O(n) vs O(n²): loop vs loop aninhado.
7. Space–time tradeoff: memória por passos.
8. Melhor/pior/médio caso — entrevista = pior caso.
9. Sinais: duplicados, chave, próximo, caminho...
10. Menor notação ≠ sempre melhor.

## Aviso final do vídeo

"Se curtiu, se inscreve e deixa um like, ajuda bastante o canal."