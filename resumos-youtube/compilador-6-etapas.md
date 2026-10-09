# Resumo — "Como um Compilador Funciona" (pt-BR, ~11:03)

Fonte: https://www.youtube.com/watch?v=7R9ZYaDTAAc
Data: 30/08/2026 | Transcrição: /tmp/tr_comp.json

## Tese central

Um compilador é um **pipeline**: cada estágio pega a saída do anterior, transforma e passa pro próximo. "Seis tokens de código → duas instruções de máquina" — a redução de um programa a código eficiente em 6 etapas bem definidas.

## As 6 etapas

### 1. Análise léxica (lexing)
- Lê o texto **caractere por caractere** e agrupa em **tokens**: `int` = keyword, `result` = identificador, `=` = operador, `2` = literal numérico, `;` encerra.
- Não precisa entender significado — só separar pedaços e classificar.
- Descarta: espaços em branco e comentários.

### 2. Análise sintática (parsing)
- Transforma tokens numa **AST** (árvore de sintaxe abstrata) — hierarquia.
- Resolve ambiguidades por **precedência**: em `a + b * 2`, `b * 2` agrupa primeiro (nó `+` tem filhos `a` e `b*2`).
- Mesmo padrão em bancos de dados: SQL → tokens → árvore → plano de execução.
- Estrutura errada (ex.: `x = ;`) → **erro de sintaxe** (o "vermelho" do editor).

### 3. Análise semântica
- Verifica se o programa **faz sentido** (a árvore só garante estrutura):
  - Tipos compatíveis? Variável declarada antes de usar? Função existe? Nº de argumentos OK?
- **Resolução de nomes** via **tabela de símbolos**: mapeia cada nome ao que representa (`a` → tipo int, escopo local, posição na stack). Cada declaração adiciona; cada uso consulta.

### 4. Representação intermediária (IR)
- Por que não ir direto a código de máquina? **N linguagens × M arquiteturas** → com IR são só N + M traduções.
- IR é simples: cada instrução faz **uma operação** (`a + b * 2` → `t1 = b * 2; t2 = a + t1; result = t2`). Sem precedência, sem expressões compostas.

### 5. Otimização
- **Constant folding**: `2 + 3` vira `5` em tempo de compilação.
- **Dead code elimination**: `if false { ... }` inteiro é descartado.
- **Loop unrolling**: desenrola iterações, eliminando o overhead de checagem/incremento.
- **Function inlining**: cópia o corpo da função no ponto de chamada (some o custo do stack frame).
- Compiladores modernos fazem **centenas** de otimizações — o código legível roda tão rápido (ou mais) que o otimizado à mão.

### 6. Geração de código
- Cada instrução IR → instrução de máquina da arquitetura alvo (`t1 = b * 2` → `imul` no x86).
- **Alocação de registradores**: CPU tem poucos registradores; variável de loop fica no registrador, variável de uso único vai pra stack.
- Assembly → **assembler** → bytes; **linker** junta com bibliotecas externas e gera o executável.

## Pipeline completo (exemplo do vídeo)

```
int square(int x) { return x * x; }
→ léxico: int | square | ( | int | x | ) | { | return | x | * | x | }
→ sintático: árvore FunctionDecl(nome=square, param=x:int, corpo=Return(x*x))
→ semântico: x é int × int → int, bate com a declaração ✓
→ IR: t1 = x * x; return t1
→ otimização: como a função é pequena, inline nos pontos de chamada
→ código: imul + ret (2 instruções de máquina)
```

## Compilador vs interpretador vs JIT

| | Compilador | Interpretador | JIT (meio-termo) |
|---|---|---|---|
| Traduz | programa inteiro antes | linha por linha, em tempo real | interpreta; detecta hot path e compila para nativo |
| Uso | C, Rust, Go | Python, Ruby | JVM (Java), V8 (JavaScript) |
| Perfil | compila devagar, executa rápido | inicia instantâneo, executa lento | equilibra |

## Ferramentas JS que são compiladores (sem você perceber)

- **TypeScript** → compila para JavaScript
- **Babel** → transpila sintaxe nova para navegadores antigos
- **Webpack** → resolve módulos e gera bundles

Todas fazem o MESMO pipeline: léxico → sintático → semântico → transformação → output.

## Como ler erros a partir de agora

- **Erro de sintaxe** → o parser não montou a árvore (faltou `(`, `;`, `}`).
- **Erro de tipo** → análise semântica achou incompatibilidade (string onde era número).
- **Variável undefined** → a tabela de símbolos não encontrou o nome.

---

## Exemplos de código — Python 3.14 (stdlib)

### 1. Lexer → tokens
```python
# Python 3.14 — mini lexer
import re

def lex(entrada):
    padroes = [
        ('INT',   r'int'),
        ('RETURN', r'return'),
        ('ID',    r'[a-z_][a-z0-9_]*'),
        ('NUM',   r'\d+'),
        ('OP',    r'[\*\+\-]'),
        ('LPAREN', r'\('),
        ('RPAREN', r'\)'),
        ('LBRACE', r'\{'),
        ('RBRACE', r'\}'),
        ('SEMI',  r';'),
        ('SKIP',  r'\s+'),
    ]
    tokens = []
    i = 0
    while i < len(entrada):
        for nome, p in padroes:
            m = re.match(p, entrada[i:])
            if m:
                if nome != 'SKIP':
                    tokens.append((nome, m.group()))
                i += len(m.group())
                break
        else:
            raise SyntaxError(f'caractere inesperado: {entrada[i]!r}')
    return tokens

codigo = 'int square(int x) { return x * x; }'
print(lex(codigo))
# [('INT','int'), ('ID','square'), ('LPAREN','('), ('INT','int'), ('ID','x'),
#  ('RPAREN',')'), ('LBRACE','{'), ('RETURN','return'), ('ID','x'),
#  ('OP','*'), ('ID','x'), ('SEMI',';'), ('RBRACE','}')]
```

### 2. Parser → AST + constant folding + dead code
```python
# Python 3.14 — parser de expressoes com precedencia + otimizacao
class Num:
    def __init__(self, v): self.v = v
    def eval(self): return self.v
    def __repr__(self): return str(self.v)

class Bin:
    def __init__(self, op, l, r): self.op, self.l, self.r = op, l, r
    def eval(self): return {'+': lambda a,b: a+b, '*': lambda a,b: a*b}[self.op](self.l.eval(), self.r.eval())
    def __repr__(self): return f'({self.l} {self.op} {self.r})'

tokens = [('NUM','2'),('OP','+'),('NUM','3')]

def parse_expr(ts):
    # precedencia: * antes de + (recursive descent simples)
    def fator(i):
        t, v = ts[i]
        return Num(int(v)), i + 1
    def termo(i):
        l, i = fator(i)
        while i < len(ts) and ts[i][0] == 'OP' and ts[i][1] == '*':
            _, op = ts[i]
            r, i = fator(i + 1)
            l = Bin(op, l, r)
        return l, i
    def soma(i):
        l, i = termo(i)
        while i < len(ts) and ts[i][0] == 'OP':
            _, op = ts[i]
            r, i = termo(i + 1)
            l = Bin(op, l, r)
        return l, i
    ast, _ = soma(0)
    return ast

ast = parse_expr([('NUM','2'),('OP','+'),('NUM','3')])
print('AST:', ast)            # (2 + 3) — a arvore mostra a estrutura
print('eval:', ast.eval())    # 5

# constant folding: 2 + 3 vira 5 (nao precisa calcular em runtime)
def constant_fold(node):
    if isinstance(node, Bin) and isinstance(node.l, Num) and isinstance(node.r, Num):
        return Num(node.eval())
    return node

print('folded:', constant_fold(ast))   # 5
# AST: (2 + 3)
# eval: 5
# folded: 5
```
> No exemplo do vídeo: `a + b * 2` → AST `(a + (b * 2))` — a multiplicação agrupa primeiro (precedência). Aqui o constant folding substitui `2 + 3` por `5` direto.

### 3. Otimização: dead code + IR/gerador de código
```python
# Python 3.14 — dead code elimination + geracao de "assembly"
class Num:
    def __init__(self, v): self.v = v

def dead_code(ast):
    # if false { ... } inteiro e descartado
    if isinstance(ast, If) and isinstance(ast.cond, Num) and ast.cond.v == 0:
        return None   # bloco morto removido
    return ast

class If:
    def __init__(self, cond, corpo): self.cond, self.corpo = cond, corpo

# um programa simples: if false { ... } (morreria no binario)
prog = If(Num(0), 'bloco que nunca roda')
print('dead code removido:', dead_code(prog) is None)   # True

# IR de a + b * 2 — cada instrucao faz UMA operacao
a, b = 1, 2
t1 = b * 2
t2 = a + t1
ir = [('mul', 't1', 'b', '2'), ('add', 't2', 'a', 't1'), ('mov', 'result', 't2')]
# geracao de codigo (x86 simplificado)
asm = {
    'mul': 'imul', 'add': 'add', 'mov': 'mov',
}
for instr in ir:
    op, resto = instr[0], instr[1:]
    print(f'{asm[op]} ' + ', '.join(resto))
# imul t1, b, 2
# add  t2, a, t1
# mov  result, t2
```
> O vídeo: `t1 = b * 2 → imul`, `t2 = a + t1 → add`, `result = t2 → mov`. A IR é independente de arquitetura; a geração de código a traduz para o alvo (x86, ARM...).

---

## Destaques

- Compilador = pipeline de 6 estágios, cada um resolvendo um problema definido.
- **Lexer** separa, **parser** monta árvore, **semântica** dá significado, **IR** simplifica, **otimização** acelera, **código** materializa.
- IR existe para **N linguagens × M arquiteturas** virarem N + M.
- Otimizações: constant folding, dead code, loop unrolling, inlining — centenas nos compiladores modernos.
- Erros do editor mapeiam 1:1 para estágios (sintaxe = parser, tipo = semântica, undefined = tabela de símbolos).
- TypeScript, Babel e Webpack são compiladores com o mesmo pipeline.