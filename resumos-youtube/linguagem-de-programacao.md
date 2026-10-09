# Resumo — "Como criar uma Linguagem de Programação" (pt-BR, ~13:45)

Fonte: https://www.youtube.com/watch?v=fDtjZpiWxi4
Data: 30/08/2026 | Transcrição: /tmp/tr_ling.json

## Tese central

Criar uma linguagem é responder, uma por uma, as perguntas escondidas atrás de um `print("hello world")`: *quais keywords existem? que ordem elas podem ter? o que é erro? o que é número? o que é texto? como isso vira execução?*

## O processo (passo a passo)

### 1. Propósito
Toda linguagem nasce para resolver um problema:
- C → controle total do hardware
- Python → produtividade
- SQL → consultar dados
- Rust → segurança de memória sem GC
- Go → simplificar concorrência
- Elixir → tolerância a falhas do BEAM com sintaxe moderna

Nenhuma começou tentando ser boa em tudo. A pergunta guia: *qual problema a minha linguagem resolve melhor que as existentes?*

### 2. Gramática (EBNF)
Regras formais descrevem a estrutura válida. Um `statement` pode ser atribuição ou `mostre`; uma atribuição é `variavel` + identificador + `=` + expressão; expressão pode ser número, string, identificador ou operação. O **parser** tenta derivar o código a partir das regras — se consegue, é válido; senão, erro de sintaxe.

**Ambiguidade**: `1 + 2 * 3` precisa de **precedência** (multiplicação antes da soma) e **associatividade** para ter leitura única.

### 3. Front end: Lexer + Parser
- **Lexer**: lê texto char a char e agrupa em **tokens** (`variavel` → keyword, `nome` → identificador, `=` → operador).
- **Parser**: monta a **AST** (Abstract Syntax Tree) a partir dos tokens. Nó raiz = atribuição; lado direito = expressão de soma.
- Parser à mão (**descida recursiva** — uma função por regra da gramática) ou **gerador** (PEG como `parte`). Compiladores maduros (Go, Rust, TypeScript) usam parsers manuais por causa de mensagens de erro úteis e sintaxe complexa (JSX, tipos).

### 4. Sistema de tipos
- **Estática** (C, Go): verifica em **compilação** — pega erros cedo, melhor autocomplete, custo de escrever mais anotações (parâmetros, genéricos, null).
- **Dinâmica** (Python, JS): verifica em **execução** — mais flexível e rápido de escrever, porém erros só aparecem no caminho que roda (às vezes em produção).
- **Inferência** (TypeScript, Rust): `let x = 42` — o compilador deduz; segurança do estático com menos verbosidade.
- Além: funções com retornos variados, genéricos, representação de ausência (null/Option).

O mesmo `"1" + 1` muda conforme a linguagem: JS converte número para string e concatena; Python lança erro em runtime; linguagem estaticamente tipada nem compila.

### 5. Execução — três caminhos
1. **Intérprete direto**: percorre a AST nó a nó e executa. Simples, foco na semântica; porém lento (nós espalhados na memória, estouro de cache).
2. **Código nativo**: AST → IR (ex.: LLVM) → código de máquina. Mais rápido, mais difícil (registradores, alocação, arquiteturas). C, C++, Rust.
3. **Bytecode + VM** (meio termo): AST → bytecode compacto e sequencial → máquina virtual. Mais rápido que percorrer AST, mais fácil que nativo. Java (JVM), Python (CPython), Lua. VMs modernas adicionam **JIT**: compilam para nativo os trechos mais executados **em runtime**.

Exemplo de bytecode para `mostre 10 + 20`: `LOAD 10; LOAD 20; ADD; PRINT`.

### 6. Memória
- **Manual** (C `malloc`/`free`): controle total, risco de leak/use-after-free.
- **Garbage Collector** (Java, Go, Python, JS): runtime monitora e libera; seguro, porém pausas.
- **Ownership** (Rust): dono libera ao sair do escopo, checado em compilação — sem GC, sem frees manuais.

### 7. Runtime + Concorrência
O runtime define o modelo: threads (Java), event loop (JS), goroutines (Go). Decisão difícil de mudar depois — o código dos usuários se apoia nela.

### 8. Standard Library + Ecossistema
- Python = **batteries included** (HTTP, regex, CSV na caixa).
- Go = stdlib forte p/ servidores (HTTP, JSON, crypto, testes) sem dependência externa.
- **Package manager** é quase obrigatório (npm, pip/uv, cargo).
- **Ferramentas**: formatter, linter, debugger — `gofmt`, `go test`, `go build` acertaram desde o começo.
- **LSP** (Language Server Protocol, da Microsoft) conecta editores ao servidor da linguagem: autocomplete, erros inline, ir para definição, refatoração — em VS Code, Neovim, IntelliJ, etc.
- **Comunidade** é o que mantém a linguagem viva: bibliotecas, respostas, bug reports.

## Recursos para aprender
- **Crafting Interpreters** (Robert Nystrom) — gratuito online; constrói 2 implementações da linguagem Lox: interpretador em Java + VM com bytecode em C.
- **Dragon Book** — o livro clássico de compiladores.
- **LLVM** como backend — gere IR p/ LLVM e ele cuida de otimização e geração p/ várias arquiteturas (Rust, Swift fazem isso).

## Conclusão
Mesmo sem criar uma linguagem de produção, o processo obriga a entender **como código vira execução** — e isso muda como você programa em qualquer linguagem.

---

## Exemplos de código — Python 3.14, Go 1.26 e Java 26

### 1. Lexer: texto → tokens
```python
# Python 3.14 — mini lexer (tokens)
import re

def lexer(src):
    specs = [
        ('NUM', r'\d+'), ('ID', r'[a-z]+'),
        ('OP', r'[+\-*/=]'), ('WS', r'\s+'),
    ]
    tokens = []
    pos = 0
    while pos < len(src):
        for name, pat in specs:
            m = re.match(pat, src[pos:])
            if m:
                if name != 'WS':
                    tokens.append((name, m.group()))
                pos += len(m.group())
                break
        else:
            raise SyntaxError(f'caractere inesperado: {src[pos]!r}')
    return tokens

print(lexer('variavel x = 10 + 20'))
# [('ID','variavel'), ('ID','x'), ('OP','='), ('NUM','10'), ('OP','+'), ('NUM','20')]
```
```go
// Go 1.26 — mini lexer (tokens)
package main

import (
	"fmt"
	"regexp"
)

type Token struct{ tipo, valor string }

func lexer(src string) []Token {
	specs := []struct{ tipo, pat string }{
		{"NUM", `\d+`}, {"ID", `[a-z]+`}, {"OP", `[+\-*/=]`},
	}
	var tokens []Token
	pos := 0
	for pos < len(src) {
		matched := false
		for _, sp := range specs {
			re := regexp.MustCompile(`^` + sp.pat)
			m := re.FindString(src[pos:])
			if m != "" {
				tokens = append(tokens, Token{sp.tipo, m})
				pos += len(m)
				matched = true
				break
			}
		}
		if !matched {
			if src[pos] == ' ' { pos++; continue }
			panic(fmt.Sprintf("caractere inesperado: %q", src[pos]))
		}
	}
	return tokens
}

func main() {
	fmt.Println(lexer("variavel x = 10 + 20"))
}
```
```java
// Java 26 — mini lexer (tokens)
import java.util.*;
import java.util.regex.*;

public class LexerDemo {
  record Token(String tipo, String valor) {}

  static List<Token> lexer(String src) {
    Map<String, String> specs = Map.of(
      "NUM", "\\d+", "ID", "[a-z]+", "OP", "[+\\-*/=]");
    List<Token> tokens = new ArrayList<>();
    int pos = 0;
    while (pos < src.length()) {
      boolean matched = false;
      for (var e : specs.entrySet()) {
        Matcher m = Pattern.compile("^" + e.getValue()).matcher(src.substring(pos));
        if (m.find()) {
          tokens.add(new Token(e.getKey(), m.group()));
          pos += m.group().length();
          matched = true;
          break;
        }
      }
      if (!matched) {
        if (src.charAt(pos) == ' ') { pos++; continue; }
        throw new IllegalArgumentException("caractere inesperado: " + src.charAt(pos));
      }
    }
    return tokens;
  }

  public static void main(String[] a) {
    System.out.println(lexer("variavel x = 10 + 20"));
  }
}
```
Saída (3 linguagens): `[('ID','variavel'), ('ID','x'), ('OP','='), ('NUM','10'), ('OP','+'), ('NUM','20')]`.

### 2. Parser: tokens → AST (descida recursiva com precedência)
```python
# Python 3.14 — parser de expressoes (recursive descent)
class Node: pass

class Num(Node):
    def __init__(self, v): self.v = v

class Bin(Node):
    def __init__(self, op, l, r): self.op, self.l, self.r = op, l, r

class Parser:
    def __init__(self, tokens):
        self.ts = tokens; self.i = 0

    def peek(self): return self.ts[self.i] if self.i < len(self.ts) else ('EOF', '')

    def eat(self, tipo):
        tok = self.peek()
        if tok[0] != tipo: raise SyntaxError(f'era {tipo}, veio {tok}')
        self.i += 1
        return tok

    def parse(self):
        return self.soma()

    def soma(self):            # precedencia menor
        n = self.mul()
        while self.peek()[0] == 'OP' and self.peek()[1] in '+-':
            op = self.eat('OP')[1]; n = Bin(op, n, self.mul())
        return n

    def mul(self):             # precedencia maior
        n = self.fator()
        while self.peek()[0] == 'OP' and self.peek()[1] in '*/':
            op = self.eat('OP')[1]; n = Bin(op, n, self.fator())
        return n

    def fator(self):
        t = self.eat('NUM')
        return Num(int(t[1]))

def mostra(n, recuo=0):
    if isinstance(n, Num): return str(n.v)
    return f'({mostra(n.l)} {n.op} {mostra(n.r)})'

tokens = [('NUM','1'),('OP','+'),('NUM','2'),('OP','*'),('NUM','3')]
ast = Parser(tokens).parse()
print(mostra(ast))   # (1 + (2 * 3)) — precedencia aplicada
```
```go
// Go 1.26 — parser de expressoes (recursive descent)
package main

import "fmt"

type Token struct{ tipo, valor string }

type Node interface{ String() string }

type Num struct{ v int }

func (n Num) String() string { return fmt.Sprint(n.v) }

type Bin struct {
	op string
	l, r Node
}

func (b Bin) String() string { return fmt.Sprintf("(%s %s %s)", b.l, b.op, b.r) }

type Parser struct {
	ts []Token
	i  int
}

func (p *Parser) peek() Token {
	if p.i < len(p.ts) { return p.ts[p.i] }
	return Token{"EOF", ""}
}

func (p *Parser) eat(tipo string) Token {
	t := p.peek()
	if t.tipo != tipo { panic(fmt.Sprintf("era %s, veio %v", tipo, t)) }
	p.i++
	return t
}

func (p *Parser) soma() Node {
	n := p.mul()
	for p.peek().tipo == "OP" && (p.peek().valor == "+" || p.peek().valor == "-") {
		op := p.eat("OP").valor
		n = Bin{op, n, p.mul()}
	}
	return n
}

func (p *Parser) mul() Node {
	n := p.fator()
	for p.peek().tipo == "OP" && (p.peek().valor == "*" || p.peek().valor == "/") {
		op := p.eat("OP").valor
		n = Bin{op, n, p.fator()}
	}
	return n
}

func (p *Parser) fator() Node {
	t := p.eat("NUM")
	var v int
	fmt.Sscanf(t.valor, "%d", &v)
	return Num{v}
}

func main() {
	ts := []Token{{"NUM", "1"}, {"OP", "+"}, {"NUM", "2"}, {"OP", "*"}, {"NUM", "3"}}
	fmt.Println((&Parser{ts, 0}).soma())   // (1 + (2 * 3))
}
```
```java
// Java 26 — parser de expressoes (recursive descent)
import java.util.*;

public class ParserDemo {
  record Token(String tipo, String valor) {}
  sealed interface Node permits Num, Bin {}
  record Num(int v) implements Node {}
  record Bin(String op, Node l, Node r) implements Node {}

  static class P {
    List<Token> ts; int i = 0;
    P(List<Token> ts) { this.ts = ts; }
    Token peek() { return i < ts.size() ? ts.get(i) : new Token("EOF", ""); }
    Token eat(String tipo) {
      Token t = peek();
      if (!t.tipo().equals(tipo)) throw new IllegalArgumentException("era " + tipo + ", veio " + t);
      i++;
      return t;
    }
    Node soma() {
      Node n = mul();
      while (peek().tipo().equals("OP") && (peek().valor().equals("+") || peek().valor().equals("-"))) {
        String op = eat("OP").valor();
        n = new Bin(op, n, mul());
      }
      return n;
    }
    Node mul() {
      Node n = fator();
      while (peek().tipo().equals("OP") && (peek().valor().equals("*") || peek().valor().equals("/"))) {
        String op = eat("OP").valor();
        n = new Bin(op, n, fator());
      }
      return n;
    }
    Node fator() {
      Token t = eat("NUM");
      return new Num(Integer.parseInt(t.valor()));
    }
  }

  static String mostra(Node n) {
    if (n instanceof Num num) return String.valueOf(num.v());
    if (n instanceof Bin b) return "(" + mostra(b.l()) + " " + b.op() + " " + mostra(b.r()) + ")";
    return "";
  }

  public static void main(String[] a) {
    List<Token> ts = List.of(
      new Token("NUM", "1"), new Token("OP", "+"),
      new Token("NUM", "2"), new Token("OP", "*"), new Token("NUM", "3"));
    System.out.println(mostra(new P(ts).soma()));   // (1 + (2 * 3))
  }
}
```
Saída (3 linguagens): `(1 + (2 * 3))` — a multiplicação agrupou primeiro (precedência).

### 3. Interpretador de bytecode (VM)
```python
# Python 3.14 — VM de pilha (bytecode)
def run(bytecode):
    pilha = []
    for op in bytecode:
        if op[0] == 'LOAD': pilha.append(op[1])
        elif op[0] == 'ADD': pilha.append(pilha.pop() + pilha.pop())
        elif op[0] == 'PRINT': print(pilha.pop())

run([('LOAD', 10), ('LOAD', 20), ('ADD',), ('PRINT',)])
# 30
```
```go
// Go 1.26 — VM de pilha (bytecode)
package main

import "fmt"

type Op struct{ nome string; v int }

func run(bytecode []Op) {
	var pilha []int
	for _, op := range bytecode {
		switch op.nome {
		case "LOAD":
			pilha = append(pilha, op.v)
		case "ADD":
			b, a := pilha[len(pilha)-1], pilha[len(pilha)-2]
			pilha = pilha[:len(pilha)-2]
			pilha = append(pilha, a+b)
		case "PRINT":
			v := pilha[len(pilha)-1]
			pilha = pilha[:len(pilha)-1]
			fmt.Println(v)
		}
	}
}

func main() {
	run([]Op{{"LOAD", 10}, {"LOAD", 20}, {"ADD", 0}, {"PRINT", 0}})
}
```
```java
// Java 26 — VM de pilha (bytecode)
import java.util.*;

public class VM {
  record Op(String nome, int v) {}

  static void run(List<Op> bytecode) {
    Deque<Integer> pilha = new ArrayDeque<>();
    for (Op op : bytecode) {
      switch (op.nome()) {
        case "LOAD" -> pilha.push(op.v());
        case "ADD"  -> pilha.push(pilha.pop() + pilha.pop());
        case "PRINT" -> System.out.println(pilha.pop());
      }
    }
  }

  public static void main(String[] a) {
    run(List.of(new Op("LOAD", 10), new Op("LOAD", 20), new Op("ADD", 0), new Op("PRINT", 0)));
  }
}
```
Saída (3 linguagens): `30`.

---

## Destaques

- Linguagem nasce de um **propósito**; as outras decisões (tipos, execução, memória, runtime) derivam dele.
- **Gramática EBNF** → **lexer** → **parser** → **AST** → **tipos** → **execução** (intérprete/nativo/bytecode) → **memória** → **stdlib/ecossistema**.
- **LSP** e package manager são o que separam linguagem "de brinquedo" de uma usável.
- Recursos: **Crafting Interpreters**, **Dragon Book**, **LLVM**.