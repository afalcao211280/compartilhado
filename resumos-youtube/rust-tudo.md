# Resumo — "Rust: por que ele está em todo lugar?" (pt-BR, ~17:21)

Fonte: https://www.youtube.com/watch?v=NovBtvFLwn8
Data: 30/08/2026 | Transcrição: /tmp/tr_rust.json

## Tese central

Rust é uma linguagem de sistema que busca **desempenho de C sem garbage collector e com segurança de memória garantida em tempo de compilação**. A aposta: pagar mais na compilação para levar menos susto em produção. Em C, um bug de memória compila, roda e explode depois; em Rust, o compilador barra antes da primeira linha rodar.

## Os 4 pilares

### 1. Ownership (posse)
Todo valor tem um **dono**. Quando o dono sai de escopo, o valor é liberado automaticamente. Só existe UM dono por vez: na atribuição, a posse **move** (não copia referência). Isso elimina double-free (liberar 2×), memory leak (nunca liberar) e use-after-free (usar memória já liberada).

### 2. Borrowing (empréstimo)
Para passar dados a funções sem destruí-los, empresta-se uma **referência** (`&`). A função lê sem virar dona; o valor original continua vivo. Regras:
- Várias referências **imutáveis** ao mesmo tempo: OK.
- Uma referência **mutável** (`&mut`) precisa estar **sozinha**: ou vários leitores, ou um escritor.
- Isso elimina **data races** (duas threads acessando a mesma memória sem coordenação, com pelo menos uma escrita) — o compilador **recusa** código com `&a` + `&mut a` simultâneos.

### 3. Lifetimes (tempo de vida)
Garantia do compilador de que uma referência **nunca vive mais que o valor apontado**. Na maioria do código é inferido; só se escreve `'a` quando um struct guarda referências ou uma função devolve referência — aí a assinatura precisa declarar de onde a referência veio.

### 4. Tipos que representam ausência/erro
- **`Option<T>`**: `Some(v)` ou `None` — força tratar os dois casos (nada de valor mágico).
- **`Result<T, E>`**: `Ok(v)` ou `Err(e)`; o operador `?` propaga o erro no caminho feliz sem esconder que erro existe.
- **`enum` + `match` exaustivo**: modelar estado inválido como **impossível de representar** (pedido `Aberto` sem `pago_em`; `Cancelado` com `motivo`; `Pago` com `pago_em`). Se amanhã adicionarem um estado, o compilador aponta **onde** o código precisa mudar.

## Sintaxe e ferramentas

- `struct` define dados; `impl` associa métodos (self, `&mut self`); `enum` define alternativas.
- **Imutabilidade por padrão**: `mut` marca explicitamente a mutação.
- **`trait`** é contrato de comportamento (interface com ligação forte ao sistema de tipos: genéricos, `?`, conversões, iteradores).
- **Iterators** + closures: pipelines que o compilador otimiza agressivamente.
- Macros usam `!` (`println!`, `format!`).
- **Cargo**: `cargo new`, `cargo run`, `cargo test`, `cargo fmt` — fluxo padrão de projeto/build/dependências/testes/publicação; repositório público = crates.io.

## Onde Rust faz sentido (e onde não)

Faz sentido quando: **custo de falha alto + necessidade de controle alta** (sistemas, drivers, runtimes, bancos de dados, proxies, CLIs, embarcados). Binário nativo único, latência e previsibilidade de memória importam.

Não faz sentido: validar ideia em 2 dias, app de tela/formulário/CRUD — TypeScript, Ruby, Python ou Go resolvem com muito menos atrito.

## Adoção real (Rust como "motor embaixo")

| Exemplo | Onde entra |
|---|---|
| Linux kernel | Frente de abstrações e drivers em Rust (não todo o kernel) |
| Android | Componentes nativos — bugs de memória em C/C++ viram vulnerabilidades |
| AWS Firecracker | MicroVMs (Lambda, Fargate): subir rápido, pouco overhead |
| Cloudflare Pingora | Framework Rust para proxies HTTP de altíssimo tráfego |
| Deno | Runtime JS/TS/WASM — base tem V8 + Rust + Tokio |
| uv (Python) | Gerenciador de pacotes Python escrito em Rust |

## Tradeoffs

- **Aprendizado**: ownership/borrowing/lifetimes exigidos desde o início; o compilador não deixa empurrar dúvidas.
- **Velocidade de compilação**: pode ser mais lento que Go em projetos grandes.
- **Verbose em alguns casos**: trait bounds, genéricos com mensagens longas, estruturas com referências internas.
- Não impede deadlock, nem conserta arquitetura ruim — mas tira um conjunto grande de erros que em outras linguagens acontecem silenciosamente.

## Conclusão

Rust força a responder perguntas que outras linguagens deixam implícitas: *quem é dono deste valor? quem pode mudar? esta referência vive o suficiente? este erro foi tratado? este estado inválido pode existir?* No começo parece burocracia; depois vira design. "Pague mais na compilação para levar menos susto em produção."

---

## Exemplos de código — Rust 1.98

### 1. Ownership: move vs cópia

```rust
// Rust 1.98 — ownership (move)
fn main() {
    let nome = String::from("arthur");
    let saudacao = nome;          // move: nome deixa de ser dono
    // println!("{nome}");        // ERRO de compilacao: valor movido
    println!("{saudacao}");       // OK: saudacao e a dona
}
```

`nome` foi *movido* para `saudacao`; usar `nome` depois é erro de compilação — impossível double-free ou use-after-free.

### 2. Borrowing: vários leitores OU um escritor

```rust
// Rust 1.98 — borrowing (emprestimos)
fn tamanho(s: &String) -> usize {  // emprestimo imutavel
    s.len()
}

fn main() {
    let mut texto = String::from("ola");
    let r1 = &texto;               // leitor 1 OK
    let r2 = &texto;               // leitor 2 OK
    println!("{} {}", tamanho(r1), tamanho(r2));
    let r3 = &mut texto;           // escritor: precisa estar sozinho
    r3.push_str(" mundo");
    println!("{r3}");
    // println!("{r1}");           // ERRO: r1 ja nao pode ser usado
}
```

Aqui `r3` (mutável) só nasce depois que `r1`/`r2` (imutáveis) deixam de ser usados. Se `r1` fosse usado após `r3`, o borrow checker recusaria — **data race impossível**:

```rust
// Rust 1.98 — o que o compilador RECUSA (data race)
fn main() {
    let mut texto = String::from("ola");
    let r1 = &texto;        // emprestimo imutavel
    let r3 = &mut texto;    // emprestimo mutavel
    println!("{} {}", r1, r3);  // ERRO E0502
}
/*
error[E0502]: cannot borrow `texto` as mutable because it is also borrowed as immutable
 --> main.rs:4:14
  |
3 |     let r1 = &texto;
  |              ------ immutable borrow occurs here
4 |     let r3 = &mut texto;
  |              ^^^^^^^^^^ mutable borrow occurs here
*/
```

### 3. Option/Result com `?`

```rust
// Rust 1.98 — Option + Result com o operador ?
use std::fs;

fn ler_id(linha: &str) -> Option<u32> {
    linha.split('=').nth(1)?.trim().parse().ok()
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let conteudo = fs::read_to_string("config.txt")?;   // propaga erro
    if let Some(id) = ler_id(&conteudo) {
        println!("ID: {id}");
    } else {
        println!("ID ausente");
    }
    Ok(())
}
```

`?` propaga o erro no caminho feliz; `Option` força tratar o caso `None` (via `if let` ou `match`). Nada de valor mágico escondido.

### 4. Modelando estado inválido como impossível: enum + match exaustivo

```rust
// Rust 1.98 — estado invalido impossivel de representar
enum PedidoStatus {
    Aberto,
    Pago { pago_em: String },
    Cancelado { motivo: String },
}

struct Pedido { id: u32, total_cents: u64, status: PedidoStatus }

fn descreve(p: &Pedido) -> String {
    match &p.status {
        PedidoStatus::Aberto => format!("pedido {} aberto", p.id),
        PedidoStatus::Pago { pago_em } =>
            format!("pedido {} pago em {}", p.id, pago_em),
        PedidoStatus::Cancelado { motivo } =>
            format!("pedido {} cancelado: {}", p.id, motivo),
    }
}

fn main() {
    let p = Pedido {
        id: 42,
        total_cents: 9990,
        status: PedidoStatus::Pago { pago_em: String::from("2026-08-30") },
    };
    println!("{}", descreve(&p));
}
```

Não existe `PedidoStatus` inválido: `Pago` carrega `pago_em`, `Cancelado` carrega `motivo`, `Aberto` não tem campos vazios. `match` é exaustivo — se adicionarem um estado, o compilador aponta todos os lugares a atualizar.

---

## Destaques

- Ownership + borrowing + lifetimes = segurança de memória **sem GC** e **sem custo de runtime**.
- `Option`/`Result`/`enum` + `match` exaustivo: o comportamento possível mora no **tipo**; o compilador cobra que você trate.
- Rust não é para todo projeto — é para quando o **custo de falhar** e a **necessidade de controle** são altos.
- "Rust obriga você a responder perguntas que outras linguagens deixam implícitas."