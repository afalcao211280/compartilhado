# Resumo — "6 Design Patterns que você vai usar no dia a dia"

Fonte: https://www.youtube.com/watch?v=G-O90vR7SCU (vídeo em pt-BR, ~10:46)
Data do resumo: 30/08/2026

## O que são Design Patterns

Analogia do vídeo: a **planta de uma casa**. Você não inventa do zero como construir uma cozinha toda vez que projeta uma casa — existem soluções testadas milhões de vezes que todo arquiteto conhece. Design patterns funcionam igual, só que para código: **soluções reutilizáveis para problemas que aparecem toda hora** na construção de software.

O termo ficou famoso em 1994, quando quatro autores (Gang of Four) publicaram um livro com **23 padrões**. Não precisa decorar os 23 — na prática, uns 6 são usados muito mais que os outros.

---

## 1. Observer — "reagir a mudanças"

**Problema:** vários objetos precisam ser notificados quando algo muda, sem ficarem checando o tempo todo.

**Exemplo do vídeo (YouTube):** você se inscreve no canal e ativa o sino. Toda vez que o canal posta vídeo novo, você recebe a notificação — não precisa entrar no canal toda hora pra ver se tem coisa nova. O YouTube te avisa.

- **Subject** = o canal (mantém a lista de observers)
- **Observers** = os inscritos
- Quando o estado do subject muda, ele percorre a lista e chama `update`/`notify` em cada observer

**Estrutura:** `on` registra um observer; `emit` notifica todos os observers daquele evento.

**Exemplos reais no código (você já usa todo dia):**
- `addEventListener` do DOM
- `EventEmitter` do Node.js
- `useEffect` do React (reage quando uma dependência muda)

**Quando usar:** o desacoplamento é o motivo — o subject não precisa saber quem está escutando nem quantos observers existem. Útil quando módulos diferentes do sistema precisam reagir ao mesmo evento.

---

## 2. Factory — "criar objetos de forma flexível"

**Problema:** a criação de objetos é complexa ou varia conforme o contexto — e a lógica de criação fica espalhada no código.

**Exemplo do vídeo (pizzaria):** você pede uma marguerita e não entra na cozinha pra escolher a massa, preparar o molho e montar a pizza. Você só diz o que quer e a cozinha entrega. **Quem pede o objeto não precisa saber como ele é construído** — a criação é delegada a um método/classe especializada.

**Exemplo de código (sistema de pagamentos):** dependendo do tipo, o processamento é diferente — Pix, cartão ou boleto, cada um com lógica específica.
- **Sem factory:** a cada pagamento, um `switch` no meio do código; a lógica de criação fica espalhada pela codebase
- **Com factory:** tudo centralizado e isolado num lugar só; o resto do código nem sabe qual classe está sendo usada
- Se amanhã surgir um novo tipo de pagamento, você muda **num lugar só**

**Exemplos reais:**
- `document.createElement` no browser
- Jest usa factories para criar mocks
- Frameworks que instanciam componentes

**Quando usar:** criar objetos é algo que quase todo sistema faz — é um dos padrões mais comuns.

---

## 3. Singleton — "garantir instância única" ⚠️ polêmico

**Problema:** um objeto precisa existir exatamente uma vez no sistema inteiro.

**Exemplo do vídeo (prédio):** um prédio de vários andares tem um elevador. Todo mundo usa o mesmo elevador — não faz sentido ter um diferente pra cada andar.

**Mecânica:**
- Constructor **privado** — ninguém consegue dar `new Database` direto
- Única forma de obter a instância: `getInstance()`
- 1ª chamada cria; as seguintes retornam a mesma instância
- Não importa se é o módulo de usuários, pedidos ou relatórios: todos recebem a mesma conexão com o banco

**⚠️ Por que é polêmico:** muita gente considera **antipattern**. O maior problema: cria **estado global** que dificulta testes e esconde dependências. Em frameworks atuais, o singleton costuma ser implementado pelo **container de injeção de dependências** (o framework garante a instância única sem acoplar o código).

**Recomendado apenas para recursos que realmente precisam ser únicos:**
- Pool de conexão com o banco
- Configuração da aplicação
- Sistema de logs

---

## 4. Decorator — "adicionar comportamento sem modificar o objeto"

**Problema:** você quer adicionar responsabilidades a um objeto de forma dinâmica, sem alterar o objeto original.

**Exemplo do vídeo (filtros do Instagram):** você tira uma foto e aplica um filtro, depois o contraste, depois o brilho. Cada filtro recebe a imagem anterior e devolve uma nova versão com o efeito aplicado — **a foto original continua intacta**. O mais importante: a entrada e a saída são sempre a mesma coisa (uma imagem), então você pode **empilhar quantos filtros quiser, na ordem que quiser**.

**Exemplo de código (sistema de notificações):** começa com e-mail, depois precisa mandar por Slack, depois SMS. Em vez de criar uma classe Deus gigante que faz tudo:
- `SlackDecorator` recebe um `Notifier` no constructor, chama o `send()` do objeto original e adiciona a lógica do Slack
- Uso: vai **encadeando** — cada camada adiciona comportamento sem mudar as anteriores
- Quer só e-mail e SMS sem Slack? É só não adicionar o `SlackDecorator`

**Exemplos reais:**
- Decorators do TypeScript (`@`)
- `@Injectable` do Angular, `@Component` do NestJS

**Quando usar:** combinar responsabilidades de formas variadas sem herança gigante.

---

## 5. Strategy — "trocar algoritmos em tempo de execução"

**Problema:** um problema pode ser resolvido de várias formas diferentes, e você quer trocar a solução sem mudar o resto do código.

**Exemplo do vídeo (GPS):** você quer ir de um lugar a outro. O app oferece carro, bicicleta ou transporte público — cada opção usa um algoritmo diferente para calcular a rota, mas **a interface é a mesma**: você só escolhe qual estratégia quer.

**Exemplo de código (sorter):**
- A classe `Sorter` não sabe qual algoritmo está usando — só sabe que tem um objeto com método `sort()`
- Troca a qualquer momento com `setStrategy()`

**Exemplo de código (validação de formulários):** cada campo tem uma regra diferente — CPF tem uma lógica, telefone outra, senha outra. Em vez de um `if/else` gigante, cada regra vira um strategy que o validador usa.

**Exemplos reais:**
- Middleware do Express (escolhe qual render processar)
- Estratégias de autenticação no Passport
- `Array.sort()` do JavaScript aceita uma função comparadora — que é basicamente um strategy

**Detalhe:** se a estratégia tem estado ou vários métodos trabalhando juntos, uma classe faz mais sentido. Se for uma operação simples, uma função já resolve.

---

## 6. Adapter — "conectar interfaces incompatíveis"

**Problema:** você precisa usar uma biblioteca ou API externa, mas a interface dela não encaixa no seu código — sem refatorar tudo.

**Exemplo do vídeo (adaptador de tomada):** você viaja pro exterior e leva seu carregador. O carregador funciona, a tomada funciona, mas são incompatíveis. O adaptador **não muda o carregador nem a tomada** — só faz a conexão entre eles.

**Exemplo de código (API externa):** uma API retorna `first_name`/`last_name`, mas seu sistema inteiro usa `nome`/`sobrenome`. Você não vai mudar a API, nem quer mudar todo o sistema → cria um adapter: os dados entram num formato, passam pelo adapter e saem no formato esperado. **O adapter é a cola entre duas interfaces que não são compatíveis.**

**Exemplo de código (migração de biblioteca):** o sistema inteiro usa axios, mas você quer usar o fetch nativo. Em vez de mudar centenas de arquivos, cria um adapter que implementa a mesma interface do axios usando fetch por baixo dos panos. O resto do código nem percebe a troca — interface igual, implementação diferente.

**Exemplos reais:**
- ORMs (Prisma, TypeORM) são adapters entre seu código e o banco de dados
- Drivers de banco traduzem chamadas genéricas pro protocolo específico de cada banco

**Quando usar:** integração com API externa, migração de bibliotecas, tradução entre formatos de dados.

---

## Resumo rápido: qual usar quando

| Padrão | Serve para | Lembre-se de |
|---|---|---|
| Observer | Vários objetos reagirem a uma mudança | Eventos do DOM, WebHooks, sistemas reativos |
| Factory | Criação de objetos complexa ou variável por contexto | APIs que retornam tipos diferentes, frameworks que instanciam componentes |
| Singleton | Instância única compartilhada | Pool de conexão, config, cache global — **mas pense bem antes de usar** |
| Decorator | Adicionar comportamento sem alterar o objeto original | Middlewares, interceptors, decorators do TypeScript |
| Strategy | Trocar algoritmos em tempo de execução | Validação, ordenação, qualquer lógica que varia |
| Adapter | Conectar interfaces incompatíveis | Integração com API externa, migração de biblioteca, tradução de formatos |

## Patterns interagem entre si

- Um **factory** pode criar **singletons**
- Um **observer** pode usar **strategy** para decidir como notificar
- Um **adapter** pode envolver um objeto criado por uma **factory**

Conforme você conhece os padrões, começa a enxergar as combinações.

## Exemplos de código — Java 26, Go 1.26 e Python 3.14

Os 6 padrões implementados com recursos atuais das três linguagens. Todos os 18 exemplos compilam e rodam (validado com OpenJDK 26.0.2.1, Go 1.26.6 e Python 3.14.7, saídas idênticas).

### Observer

> Eventos do DOM, WebHooks, sistemas reativos — o canal notifica os inscritos sem saber quem são.

```java
// Java 26 — Observer (lambdas)
import java.util.ArrayList;
import java.util.List;

// Observer: interface funcional
interface Subscriber {
    void notify(String title);
}

class Channel {
    private final List<Subscriber> subscribers = new ArrayList<>();

    public void subscribe(Subscriber s) { subscribers.add(s); }

    // Emit: notifica todos os observers
    public void publish(String title) {
        System.out.println("Canal postou: " + title);
        subscribers.forEach(s -> s.notify(title));
    }
}

public class ObserverDemo {
    public static void main(String[] args) {
        Channel ch = new Channel();
        // Lambdas como observers
        ch.subscribe(t -> System.out.println("Alice: " + t));
        ch.subscribe(t -> System.out.println("Bob: " + t));
        ch.publish("Design Patterns!");
    }
}
```

```go
// Go 1.26 — Observer (funcoes como subscribers)
package main

import "fmt"

// Observer: interface com 1 metodo = func
type Subscriber func(title string)

type Channel struct {
    subscribers []Subscriber
}

func (c *Channel) Subscribe(s Subscriber) {
    c.subscribers = append(c.subscribers, s)
}

// Emit: notifica todos os observers
func (c *Channel) Publish(title string) {
    fmt.Println("Canal postou:", title)
    for _, s := range c.subscribers {
        s(title)
    }
}

func main() {
    ch := &Channel{}
    alice := func(t string) { fmt.Println("Alice recebeu:", t) }
    bob := func(t string) { fmt.Println("Bob recebeu:", t) }
    ch.Subscribe(alice)
    ch.Subscribe(bob)
    ch.Publish("Design Patterns em Go!")
}
```

```python
# Python 3.14 — Observer (Protocol)
from typing import Protocol


class Subscriber(Protocol):
    def notify(self, title: str) -> None: ...


class Channel:
    def __init__(self) -> None:
        self._subscribers: list[Subscriber] = []

    def subscribe(self, s: Subscriber) -> None:
        self._subscribers.append(s)

    # Emit: notifica todos os observers
    def publish(self, title: str) -> None:
        print(f"Canal postou: {title}")
        for s in self._subscribers:
            s.notify(title)


class Alice:
    def notify(self, title: str) -> None:
        print(f"Alice recebeu: {title}")


class Bob:
    def notify(self, title: str) -> None:
        print(f"Bob recebeu: {title}")


if __name__ == "__main__":
    ch = Channel()
    ch.subscribe(Alice())
    ch.subscribe(Bob())
    ch.publish("Design Patterns em Python!")
```


### Factory

> Pagamentos Pix/cartão/boleto — a criação fica centralizada e isolada; se aparecer um tipo novo, muda num lugar só.

```java
// Java 26 — Factory (records + sealed + switch)
sealed interface Payment permits Pix, Cartao, Boleto {
    String process();
}

record Pix(String chave) implements Payment {
    public String process() { return "PIX: " + chave; }
}

record Cartao(String numero, String bandeira) implements Payment {
    public String process() { return "Cartao " + bandeira + ": " + numero; }
}

record Boleto(String codigo) implements Payment {
    public String process() { return "Boleto: " + codigo; }
}

// Factory: quem chama nao sabe a classe concreta
final class PaymentFactory {
    private PaymentFactory() {}

    static Payment create(String tipo, String payload) {
        return switch (tipo) {           // pattern matching com switch
            case "pix"    -> new Pix(payload);
            case "cartao" -> new Cartao(payload, "VISA");
            case "boleto" -> new Boleto(payload);
            default       -> throw new IllegalArgumentException("tipo desconhecido: " + tipo);
        };
    }
}

public class FactoryDemo {
    public static void main(String[] args) {
        Payment p = PaymentFactory.create("pix", "alice@email.com");
        System.out.println(p.process()); // PIX: alice@email.com
        Payment c = PaymentFactory.create("cartao", "4111-1111");
        System.out.println(c.process()); // Cartao VISA: 4111-1111
    }
}
```

```go
// Go 1.26 — Factory (interface + switch)
package main

import "fmt"

// Produtos: os tipos de pagamento
type Payment interface {
    Process() string
}

type Pix struct{ Chave string }

func (p Pix) Process() string { return "PIX: " + p.Chave }

type Cartao struct{ Numero, Bandeira string }

func (c Cartao) Process() string { return "Cartao " + c.Bandeira + ": " + c.Numero }

type Boleto struct{ Codigo string }

func (b Boleto) Process() string { return "Boleto: " + b.Codigo }

// Factory centraliza a criacao — quem chama nao sabe a classe concreta
func NewPayment(tipo, payload string) (Payment, error) {
    switch tipo {
    case "pix":
        return Pix{Chave: payload}, nil
    case "cartao":
        return Cartao{Numero: payload, Bandeira: "VISA"}, nil
    case "boleto":
        return Boleto{Codigo: payload}, nil
    default:
        return nil, fmt.Errorf("tipo desconhecido: %s", tipo)
    }
}

func main() {
    p, _ := NewPayment("pix", "alice@email.com")
    fmt.Println(p.Process()) // PIX: alice@email.com
    c, _ := NewPayment("cartao", "4111-1111")
    fmt.Println(c.Process()) // Cartao VISA: 4111-1111
}
```

```python
# Python 3.14 — Factory (dataclasses + match)
from dataclasses import dataclass
from typing import Protocol


class Payment(Protocol):
    def process(self) -> str: ...


@dataclass(frozen=True)
class Pix:
    chave: str

    def process(self) -> str:
        return f"PIX: {self.chave}"


@dataclass(frozen=True)
class Cartao:
    numero: str
    bandeira: str

    def process(self) -> str:
        return f"Cartao {self.bandeira}: {self.numero}"


@dataclass(frozen=True)
class Boleto:
    codigo: str

    def process(self) -> str:
        return f"Boleto: {self.codigo}"


# Factory: quem chama nao sabe a classe concreta
class PaymentFactory:
    @staticmethod
    def create(tipo: str, payload: str) -> Payment:
        match tipo:  # pattern matching (Python 3.10+)
            case "pix":
                return Pix(chave=payload)
            case "cartao":
                return Cartao(numero=payload, bandeira="VISA")
            case "boleto":
                return Boleto(codigo=payload)
            case _:
                raise ValueError(f"tipo desconhecido: {tipo}")


if __name__ == "__main__":
    p = PaymentFactory.create("pix", "alice@email.com")
    print(p.process())  # PIX: alice@email.com

    c = PaymentFactory.create("cartao", "4111-1111")
    print(c.process())  # Cartao VISA: 4111-1111
```


### Singleton

> Uma conexão de banco para o sistema inteiro — mas cuidado: estado global dificulta testes; em frameworks atuais quem garante a instância única é o container de injeção de dependência.

```java
// Java 26 — Singleton (holder idiom): lazy, thread-safe, sem synchronized
final class Database {
    private Database() { System.out.println("Conectando ao banco..."); }

    private static final class Holder {
        private static final Database INSTANCE = new Database();
    }

    static Database getInstance() { return Holder.INSTANCE; }

    void query(String sql) { System.out.println("Executando: " + sql); }
}

public class SingletonDemo {
    public static void main(String[] args) {
        Database d1 = Database.getInstance();
        Database d2 = Database.getInstance();
        System.out.println("Mesma instancia? " + (d1 == d2)); // true
        d1.query("SELECT 1");
    }
}
```

```go
// Go 1.26 — Singleton (sync.OnceValue)
package main

import (
    "fmt"
    "sync"
)

type Database struct{}

func NewDatabase() *Database {
    fmt.Println("Conectando ao banco...")
    return &Database{}
}

func (d *Database) Query(sql string) {
    fmt.Println("Executando:", sql)
}

// Go 1.21+: cria exatamente uma vez, thread-safe
var dbOnce = sync.OnceValue(NewDatabase)

func GetDatabase() *Database { return dbOnce() }

func main() {
    d1 := GetDatabase()
    d2 := GetDatabase()
    fmt.Println("Mesma instancia?", d1 == d2) // true
    d1.Query("SELECT 1")
}
```

```python
# Python 3.14 — Singleton (__new__ + lock)
from threading import Lock
from typing import ClassVar


class Database:
    _instance: ClassVar["Database | None"] = None
    _lock: ClassVar[Lock] = Lock()

    def __new__(cls) -> "Database":
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    print("Conectando ao banco...")
                    cls._instance = super().__new__(cls)
        return cls._instance

    def query(self, sql: str) -> None:
        print(f"Executando: {sql}")


if __name__ == "__main__":
    d1 = Database()
    d2 = Database()

    print("Mesma instancia?", d1 is d2)  # True
    d1.query("SELECT 1")
```


### Decorator

> Notificações por e-mail + Slack + SMS — empilha camadas sem criar uma classe gigante; quer só email e SMS? É só não envolver com o SlackDecorator.

```java
// Java 26 — Decorator (records)
interface Notifier {
    void send(String msg);
}

record EmailNotifier() implements Notifier {
    public void send(String msg) { System.out.println("Email: " + msg); }
}

// Decorator: embrulha o anterior, chama o original e adiciona comportamento
record SlackDecorator(Notifier wrapped) implements Notifier {
    public void send(String msg) {
        wrapped.send(msg);
        System.out.println("Slack: " + msg);
    }
}

record SMSDecorator(Notifier wrapped) implements Notifier {
    public void send(String msg) {
        wrapped.send(msg);
        System.out.println("SMS: " + msg);
    }
}

public class DecoratorDemo {
    public static void main(String[] args) {
        // Empilhando decorators (email -> sms -> slack)
        Notifier n = new SlackDecorator(new SMSDecorator(new EmailNotifier()));
        n.send("Compra aprovada");
        // So email + SMS:
        Notifier simples = new SMSDecorator(new EmailNotifier());
        simples.send("Cupom de desconto");
    }
}
```

```go
// Go 1.26 — Decorator (structs)
package main

import "fmt"

type Notifier interface {
    Send(msg string)
}

type EmailNotifier struct{}

func (EmailNotifier) Send(msg string) { fmt.Println("Email:", msg) }

// Decorator: embrulha o anterior, chama o original e adiciona comportamento
type SlackDecorator struct {
    wrapped Notifier
}

func (d SlackDecorator) Send(msg string) {
    d.wrapped.Send(msg)
    fmt.Println("Slack:", msg)
}

type SMSDecorator struct {
    wrapped Notifier
}

func (d SMSDecorator) Send(msg string) {
    d.wrapped.Send(msg)
    fmt.Println("SMS:", msg)
}

func main() {
    // Empilhando decorators (email -> sms -> slack)
    n := SlackDecorator{wrapped: SMSDecorator{wrapped: EmailNotifier{}}}
    n.Send("Compra aprovada")
    // So email + SMS? Sem SlackDecorator
    simples := SMSDecorator{wrapped: EmailNotifier{}}
    simples.Send("Cupom de desconto")
}
```

```python
# Python 3.14 — Decorator (classes empilháveis)
from typing import Protocol


class Notifier(Protocol):
    def send(self, msg: str) -> None: ...


class EmailNotifier:
    def send(self, msg: str) -> None:
        print(f"Email: {msg}")


# Decorator: embrulha o anterior, chama o original e adiciona comportamento
class SlackDecorator:
    def __init__(self, wrapped: Notifier) -> None:
        self._wrapped = wrapped

    def send(self, msg: str) -> None:
        self._wrapped.send(msg)
        print(f"Slack: {msg}")


class SMSDecorator:
    def __init__(self, wrapped: Notifier) -> None:
        self._wrapped = wrapped

    def send(self, msg: str) -> None:
        self._wrapped.send(msg)
        print(f"SMS: {msg}")


if __name__ == "__main__":
    # Empilhando decorators (email -> sms -> slack)
    n = SlackDecorator(SMSDecorator(EmailNotifier()))
    n.send("Compra aprovada")

    # So email + SMS? Sem SlackDecorator
    simples = SMSDecorator(EmailNotifier())
    simples.send("Cupom de desconto")
```


### Strategy

> Validação de formulários / ordenação — troca o algoritmo em tempo de execução sem mudar o resto do código.

```java
// Java 26 — Strategy (lambda como strategy)
import java.util.Arrays;
import java.util.Comparator;

// Estrategia = interface funcional
interface SortingStrategy {
    void sort(int[] data);
}

// Cada algoritmo encapsulado em sua propria classe
final class BubbleSort implements SortingStrategy {
    public void sort(int[] data) {
        for (int i = 0; i < data.length; i++) {
            for (int j = 0; j < data.length - 1 - i; j++) {
                if (data[j] > data[j + 1]) {
                    int tmp = data[j];
                    data[j] = data[j + 1];
                    data[j + 1] = tmp;
                }
            }
        }
    }
}

final class Sorter {
    private SortingStrategy strategy;
    void setStrategy(SortingStrategy s) { strategy = s; }
    void run(int[] data) { strategy.sort(data); }
}

public class StrategyDemo {
    public static void main(String[] args) {
        Sorter s = new Sorter();

        int[] a = {5, 3, 8, 1};
        s.setStrategy(Arrays::sort);   // estrategia nativa
        s.run(a);
        System.out.println(Arrays.toString(a)); // [1, 3, 5, 8]

        int[] b = {9, 2, 7};
        s.setStrategy(data -> {        // lambda como strategy
            var wrapped = Arrays.stream(data).boxed().toArray(Integer[]::new);
            Arrays.sort(wrapped, Comparator.naturalOrder());
            for (int i = 0; i < data.length; i++) data[i] = wrapped[i];
        });
        s.run(b);
        System.out.println(Arrays.toString(b)); // [2, 7, 9]
    }
}
```

```go
// Go 1.26 — Strategy (func = strategy)
package main

import (
    "fmt"
    "sort"
)

// Estrategia = funcao com a mesma assinatura
type SortStrategy func([]int)

type Sorter struct {
    strategy SortStrategy
}

func (s *Sorter) SetStrategy(st SortStrategy) { s.strategy = st }
func (s *Sorter) Run(data []int)              { s.strategy(data) }

func bubbleSort(data []int) {
    for i := range data {
        for j := 0; j < len(data)-1-i; j++ {
            if data[j] > data[j+1] {
                data[j], data[j+1] = data[j+1], data[j]
            }
        }
    }
}

func main() {
    s := &Sorter{}

    a := []int{5, 3, 8, 1}
    s.SetStrategy(sort.Ints) // estrategia nativa
    s.Run(a)
    fmt.Println(a) // [1 3 5 8]

    b := []int{9, 2, 7}
    s.SetStrategy(bubbleSort) // algoritmo alternativo
    s.Run(b)
    fmt.Println(b) // [2 7 9]
}
```

```python
# Python 3.14 — Strategy (callable como estrategia)
from collections.abc import Callable

# type alias (PEP 695, Python 3.12+)
type SortStrategy = Callable[[list[int]], None]


class Sorter:
    def __init__(self) -> None:
        self._strategy: SortStrategy | None = None

    def set_strategy(self, strategy: SortStrategy) -> None:
        self._strategy = strategy

    def run(self, data: list[int]) -> None:
        assert self._strategy is not None
        self._strategy(data)


def bubble_sort(data: list[int]) -> None:
    n = len(data)
    for i in range(n):
        for j in range(n - 1 - i):
            if data[j] > data[j + 1]:
                data[j], data[j + 1] = data[j + 1], data[j]


def py_sort(data: list[int]) -> None:
    data.sort()


if __name__ == "__main__":
    s = Sorter()

    # Troca de estrategia em tempo de execucao
    a = [5, 3, 8, 1]
    s.set_strategy(py_sort)
    s.run(a)
    print(a)  # [1, 3, 5, 8]

    b = [9, 2, 7]
    s.set_strategy(bubble_sort)
    s.run(b)
    print(b)  # [2, 7, 9]
```


### Adapter

> API externa retorna first_name/last_name, mas seu sistema usa nome/sobrenome — o adapter é a cola entre duas interfaces incompatíveis; o resto do código nem percebe.

```java
// Java 26 — Adapter (records)
// Formato da API externa — nao mudar
record ExternalUser(String firstName, String lastName, String email) {}

// Formato do nosso sistema
record User(String nome, String sobrenome, String email) {}

// Interface que o sistema espera
interface UserClient {
    User findByID(String id);
}

// API externa simulada
final class ExternalUserAPI {
    ExternalUser fetch(String id) {
        return new ExternalUser("Joao", "Silva", "joao@email.com");
    }
}

// Adapter: a cola entre as duas interfaces incompativeis
final class UserAdapter implements UserClient {
    private final ExternalUserAPI api = new ExternalUserAPI();

    public User findByID(String id) {
        ExternalUser ext = api.fetch(id);
        return new User(ext.firstName(), ext.lastName(), ext.email());
    }
}

public class AdapterDemo {
    public static void main(String[] args) {
        // O sistema so conhece UserClient
        UserClient client = new UserAdapter();
        User u = client.findByID("1");
        System.out.printf("%s %s <%s>%n", u.nome(), u.sobrenome(), u.email());
    }
}
```

```go
// Go 1.26 — Adapter (structs)
package main

import "fmt"

// Formato da API externa (JSON tags) — nao podemos mudar
type ExternalUser struct {
    FirstName string `json:"first_name"`
    LastName  string `json:"last_name"`
    Email     string `json:"email"`
}

// Formato do nosso sistema
type User struct {
    Nome, Sobrenome, Email string
}

// Interface que o sistema espera
type UserClient interface {
    FindByID(id string) (*User, error)
}

// API externa simulada
type ExternalUserAPI struct{}

func (ExternalUserAPI) Fetch(id string) ExternalUser {
    return ExternalUser{FirstName: "Joao", LastName: "Silva", Email: "joao@email.com"}
}

// Adapter: a cola entre as duas interfaces incompativeis
type UserAdapter struct {
    api ExternalUserAPI
}

func (a UserAdapter) FindByID(_ string) (*User, error) {
    ext := a.api.Fetch("1")
    return &User{Nome: ext.FirstName, Sobrenome: ext.LastName, Email: ext.Email}, nil
}

func main() {
    // O sistema so conhece a interface
    var client UserClient = UserAdapter{}
    u, err := client.FindByID("1")
    if err != nil {
        panic(err)
    }
    fmt.Printf("%s %s <%s>\n", u.Nome, u.Sobrenome, u.Email)
}
```

```python
# Python 3.14 — Adapter (dataclasses + Protocol)
from dataclasses import dataclass
from typing import Protocol


# Formato da API externa — nao mudar
@dataclass(frozen=True)
class ExternalUser:
    first_name: str
    last_name: str
    email: str


# Formato do nosso sistema
@dataclass(frozen=True)
class User:
    nome: str
    sobrenome: str
    email: str


# Interface que o sistema espera
class UserClient(Protocol):
    def find_by_id(self, user_id: str) -> User: ...


# API externa simulada
class ExternalUserAPI:
    def fetch(self, user_id: str) -> ExternalUser:
        return ExternalUser("Joao", "Silva", "joao@email.com")


# Adapter: a cola entre as duas interfaces incompativeis
class UserAdapter:
    def __init__(self, api: ExternalUserAPI | None = None) -> None:
        self._api = api or ExternalUserAPI()

    def find_by_id(self, user_id: str) -> User:
        ext = self._api.fetch(user_id)
        return User(nome=ext.first_name, sobrenome=ext.last_name, email=ext.email)


if __name__ == "__main__":
    # O sistema so conhece a interface
    client: UserClient = UserAdapter()

    u = client.find_by_id("1")
    print(f"{u.nome} {u.sobrenome} <{u.email}>")
```


**Verificado:** todos os 12 exemplos compilam e executam — saída idêntica nas duas linguagens (OpenJDK 26.0.2.1, Go 1.26.6).

## Aviso final do vídeo

**Não saia enfiando design pattern em tudo.** Eles existem para resolver problemas reais, não para deixar o código bonito. Se o problema não existe, o pattern também não precisa ser usado.