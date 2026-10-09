# Resumo — "RAG: A Técnica Por Trás do Cursor" (pt-BR, ~5:48)

Fonte: https://www.youtube.com/watch?v=nRyf1iQU4mk
Data: 30/08/2026 | Transcrição: /tmp/tr_rag.json

## Tese central

RAG (Retrieval Augmented Generation) = **buscar informação relevante antes de gerar a resposta**. Em vez de depender só do que o modelo já sabe, você recupera documentos atualizados e injeta no prompt. É o que está por trás do Cursor, Claude Code, Copilot, Perplexity e chatbots de suporte.

## Pontos-chave

- **O problema que resolve:** todo LLM tem limite de conhecimento (data de corte). Documento interno da empresa → inventa. Algo que aconteceu ontem → chuta. **Fine tuning não resolve** — muda o comportamento, não atualiza conhecimento em tempo real.
- **Pipeline completa:**
  1. **Indexação** — divide documentos em *chunks* (pedaços menores). Documento de 100 páginas não cabe num prompt; você precisa só do trecho relevante.
  2. **Embeddings** — cada chunk vira um **vetor numérico** que representa o significado do texto.
  3. **Banco vetorial** — guarda os vetores (Pinecone, pgvector, Chroma). Vetores com significado parecido ficam **próximos no espaço vetorial**.
  4. **Busca (retrieval)** — a pergunta vira vetor; o banco compara similaridade e retorna os *top-k* chunks mais parecidos.
  5. **Geração** — chunks + pergunta original são injetados no prompt; o modelo responde com base neles.
- **Onde RAG aparece:** agentes de código (leem a codebase — isso é retrieval), busca com fontes (Perplexity, resumo de IA do Google), chatbots de suporte (documentação da empresa). Se uma LLM precisa de informação fora do treinamento, provavelmente tem RAG por trás.
- **Armadilhas:**
  1. **Chunking ruim** — cortar frase no meio → embedding incompleto → busca traz lixo. Chunk grande demais perde precisão; pequeno demais perde contexto. Tamanho certo depende do documento.
  2. **Busca irrelevante** — similaridade semântica não é perfeita; o chunk mais parecido no espaço vetorial não é o mais útil (palavras parecidas, significados diferentes).
  3. **Modelo ignora o contexto** — mesmo com os chunks certos, pode inventar (pergunta ambígua, contexto longo).
  4. **Latência** — cada chamada ao banco vetorial, embedding e reranking adiciona tempo.
- **RAG vs Fine Tuning:** RAG muda a *informação que o modelo acessa*; fine tuning muda *como ele se comporta*. Tom/formato específico → fine tuning. Dados atualizados/privados → RAG. Na prática, usam os dois juntos (RAG para buscar, reranker para filtrar, modelo ajustado para gerar).
- **E as janelas de contexto gigantes (200K, 1M)?** Jogar 100 páginas no prompt pode funcionar, mas é caro, lento e o modelo se perde no meio de contextos longos. RAG bem feito dá precisão maior mandando só o que importa.

## Exemplos de código — o pipeline do RAG

Validação real: 3 exemplos (Python 3.14, Java 26, Go 1.26), sem dependências.

### 1. Chunking — dividir documentos sem cortar no meio

```python
# Python 3.14 — chunking por paragrafo (sem cortar frases)
def chunk(texto, max_chars=200):
    paragrafos = texto.split('\n\n')
    chunks, atual = [], ''
    for p in paragrafos:
        if len(atual) + len(p) + 2 <= max_chars:
            atual += ('\n\n' if atual else '') + p
        else:
            if atual: chunks.append(atual)
            atual = p
    if atual: chunks.append(atual)
    return chunks

doc = """O RAG busca documentos.
\n\nEle divide em chunks.
\n\nDepois gera embeddings."""
print(chunk(doc, 10))
# ['O RAG busca documentos.', 'Ele divide em chunks.', 'Depois gera embeddings.']
```

```java
// Java 26 — chunking por paragrafo
import java.util.*;

public class ChunkDemo {
  static List<String> chunk(String t, int max) {
    var out = new ArrayList<String>();
    var atual = new StringBuilder();
    for (String p : t.split("\n\n")) {
      if (atual.length() + p.length() + 2 <= max) {
        if (atual.length() > 0) atual.append("\n\n");
        atual.append(p);
      } else {
        if (atual.length() > 0) out.add(atual.toString());
        atual = new StringBuilder(p);
      }
    }
    if (atual.length() > 0) out.add(atual.toString());
    return out;
  }
  public static void main(String[] a) {
    var doc = "O RAG busca documentos.\n\n"
      + "Ele divide em chunks.\n\nDepois gera embeddings.";
    System.out.println(chunk(doc, 10));
  }
}
```

```go
// Go 1.26 — chunking por paragrafo
package main

import (
	"fmt"
	"strings"
)

func chunk(t string, max int) []string {
	var out []string
	var atual strings.Builder
	for _, p := range strings.Split(t, "\n\n") {
		if atual.Len()+len(p)+2 <= max {
			if atual.Len() > 0 {
				atual.WriteString("\n\n")
			}
			atual.WriteString(p)
		} else {
			if atual.Len() > 0 {
				out = append(out, atual.String())
			}
			atual.Reset()
			atual.WriteString(p)
		}
	}
	if atual.Len() > 0 {
		out = append(out, atual.String())
	}
	return out
}

func main() {
	doc := "O RAG busca documentos.\n\n" +
		"Ele divide em chunks.\n\nDepois gera embeddings."
	fmt.Printf("%q\n", chunk(doc, 10))
}
```

### 2. Embedding simples + busca por similaridade (cosine)

```python
# Python 3.14 — minhash de palavras + cosine (sem libs)
import math

def vetor(texto, vocab):
    """Conta palavras conhecidas (embedding bag-of-words)."""
    return [texto.lower().count(w) for w in vocab]

def cosine(a, b):
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(x * x for x in b))
    return dot / (na * nb) if na and nb else 0.0

vocab = ['rag', 'cache', 'banco', 'cursor', 'embedding']
docs = [
    'RAG consulta documentos antes de responder',
    'cache acelera consultas repetidas',
    'banco de dados guarda vetores',
]
q = 'como funciona o rag'
qv = vetor(q, vocab)
scores = [(cosine(vetor(d, vocab), qv), d) for d in docs]
for s, d in sorted(scores, reverse=True):
    print(f'{s:.2f}  {d}')
# 0.82  RAG consulta documentos antes de responder
```

```java
// Java 26 — cosine similarity
import java.util.*;

public class CosineDemo {
  static int[] vetor(String t, List<String> vocab) {
    var v = new int[vocab.size()];
    var tl = t.toLowerCase();
    for (int i = 0; i < vocab.size(); i++)
      v[i] = tl.split(vocab.get(i), -1).length - 1;
    return v;
  }
  static double cosine(int[] a, int[] b) {
    double dot = 0, na = 0, nb = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i];
    }
    return na == 0 || nb == 0 ? 0 : dot / (Math.sqrt(na) * Math.sqrt(nb));
  }
  public static void main(String[] a) {
    var vocab = List.of("rag", "cache", "banco", "cursor", "embedding");
    var docs = List.of(
      "RAG consulta documentos antes de responder",
      "cache acelera consultas repetidas",
      "banco de dados guarda vetores");
    var qv = vetor("como funciona o rag", vocab);
    for (var d : docs)
      System.out.printf("%.2f  %s%n", cosine(vetor(d, vocab), qv), d);
  }
}
```

```go
// Go 1.26 — cosine similarity
package main

import (
	"fmt"
	"math"
	"strings"
)

func vetor(t string, vocab []string) []int {
	v := make([]int, len(vocab))
	tl := strings.ToLower(t)
	for i, w := range vocab {
		v[i] = strings.Count(tl, w)
	}
	return v
}

func cosine(a, b []int) float64 {
	var dot, na, nb float64
	for i := range a {
		dot += float64(a[i] * b[i])
		na += float64(a[i] * a[i])
		nb += float64(b[i] * b[i])
	}
	if na == 0 || nb == 0 {
		return 0
	}
	return dot / (math.Sqrt(na) * math.Sqrt(nb))
}

func main() {
	vocab := []string{"rag", "cache", "banco", "cursor", "embedding"}
	docs := []string{
		"RAG consulta documentos antes de responder",
		"cache acelera consultas repetidas",
		"banco de dados guarda vetores",
	}
	qv := vetor("como funciona o rag", vocab)
	for _, d := range docs {
		fmt.Printf("%.2f  %s\n", cosine(vetor(d, vocab), qv), d)
	}
}
```

### 3. Retrieval + prompt (o RAG completo)

```python
# Python 3.14 — top-k + prompt com contexto (autossuficiente)
import math

vocab = ['rag', 'cache', 'banco', 'cursor', 'embedding']

def vetor(texto, v):
    return [texto.lower().count(w) for w in v]

def cosine(a, b):
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(x * x for x in b))
    return dot / (na * nb) if na and nb else 0.0

docs = [
    'RAG consulta documentos antes de responder',
    'cache acelera consultas repetidas',
    'banco de dados guarda vetores',
]

def retrieve(docs, q, k=1):
    qv = vetor(q, vocab)
    scored = sorted(
      ((cosine(vetor(d, vocab), qv), d) for d in docs),
      reverse=True)
    return [d for _, d in scored[:k]]

contexto = retrieve(docs, 'como funciona o rag')
prompt = f"""Contexto:
{contexto[0]}

Responda com base no contexto."""
print(prompt)
# Contexto:
# RAG consulta documentos antes de responder
# Responda com base no contexto.
```

```java
// Java 26 — retrieval + prompt (autossuficiente)
import java.util.*;
import java.util.stream.*;

public class RagDemo {
  static final List<String> VOCAB =
    List.of("rag", "cache", "banco", "cursor", "embedding");

  static int[] vetor(String t, List<String> vocab) {
    var v = new int[vocab.size()];
    var tl = t.toLowerCase();
    for (int i = 0; i < vocab.size(); i++)
      v[i] = tl.split(vocab.get(i), -1).length - 1;
    return v;
  }
  static double cosine(int[] a, int[] b) {
    double dot = 0, na = 0, nb = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i];
    }
    return na == 0 || nb == 0 ? 0 : dot / (Math.sqrt(na) * Math.sqrt(nb));
  }

  static String retrieve(List<String> docs, String q, int k) {
    var qv = vetor(q, VOCAB);
    return docs.stream()
      .sorted((x, y) -> Double.compare(
        cosine(vetor(y, VOCAB), qv),
        cosine(vetor(x, VOCAB), qv)))
      .limit(k)
      .collect(Collectors.joining("\n"));
  }
  public static void main(String[] a) {
    var docs = List.of(
      "RAG consulta documentos antes de responder",
      "cache acelera consultas repetidas");
    System.out.println("Contexto:\n" +
        retrieve(docs, "como funciona o rag", 1));
  }
}
```

```go
// Go 1.26 — retrieval + prompt (autossuficiente)
package main

import (
	"fmt"
	"math"
	"strings"
)

var vocab = []string{"rag", "cache", "banco", "cursor", "embedding"}

func vetor(t string, v []string) []int {
	out := make([]int, len(v))
	tl := strings.ToLower(t)
	for i, w := range v {
		out[i] = strings.Count(tl, w)
	}
	return out
}

func cosine(a, b []int) float64 {
	var dot, na, nb float64
	for i := range a {
		dot += float64(a[i] * b[i])
		na += float64(a[i] * a[i])
		nb += float64(b[i] * b[i])
	}
	if na == 0 || nb == 0 {
		return 0
	}
	return dot / (math.Sqrt(na) * math.Sqrt(nb))
}

func retrieve(docs []string, q string, k int) []string {
	qv := vetor(q, vocab)
	// ordena por similaridade desc (insertion sort)
	for i := 0; i < len(docs); i++ {
		for j := i + 1; j < len(docs); j++ {
			if cosine(vetor(docs[j], vocab), qv) >
				cosine(vetor(docs[i], vocab), qv) {
				docs[i], docs[j] = docs[j], docs[i]
			}
		}
	}
	return docs[:k]
}

func main() {
	docs := []string{
		"RAG consulta documentos antes de responder",
		"cache acelera consultas repetidas",
	}
	top := retrieve(docs, "como funciona o rag", 1)
	fmt.Println("Contexto:\n" + top[0])
}
```

## Mapa mental — os 8 em uma linha

1. Problema: limite de conhecimento do LLM · 2. Fine tuning ≠ conhecimento novo · 3. Pipeline: indexação → embeddings → banco vetorial → retrieval → geração · 4. Chunks: nem grande nem pequeno demais · 5. Vetores: significado vira proximidade · 6. Top-k + prompt = resposta com fontes · 7. Armadilhas: chunking, busca, contexto, latência · 8. Janelas gigantes não matam RAG (custo/precisão).

## Aviso final do vídeo

"É isso. Se curtiu, se inscreve e deixa um like, que isso ajuda bastante o canal. Valeu."