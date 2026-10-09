# Resumo — "10 conceitos essenciais de backend" (pt-BR, ~12:11)

Fonte: https://www.youtube.com/watch?v=P641CIXP2tY
Data: 30/08/2026 | Transcrição: /tmp/vid4.json

## Tese central

Você clica em "entrar"; em menos de 1 s o sistema valida a requisição, checa a senha, cria sessão, consulta o banco, escreve logs e devolve a resposta. Por trás do clique existe um backend inteiro tomando decisões — e **quase todo backend profissional se apoia nas mesmas 10 ideias**, independente da linguagem ou framework.

O vídeo conta do 10 ao 1: do básico (requisição/resposta) ao que amarra tudo (observabilidade).

---

## 10. Requisição e resposta

Todo backend começa com uma mensagem chegando: um app pede algo, o servidor processa, uma resposta volta.

**Requisição** tem:
- **Método**: GET (buscar), POST (criar), PUT (atualizar), DELETE (remover)
- **Rota**: ex.: `/api/orders`
- **Headers**: metadados (token, idioma, tipo de conteúdo)
- **Body**: o corpo da mensagem (quando tem)

**Resposta** tem status:
- **200** deu certo · **401** faltou autenticação · **404** não encontrado · **500** quebrou no servidor

Requisição e resposta são o "idioma básico" do backend — e as duas partes precisam combinar o formato dessas mensagens.

## 9. Contrato de API

A API é um **contrato entre quem pede e quem responde**.

- O frontend **não deveria precisar saber** como a tabela do banco foi montada nem qual framework o servidor usa — só precisa saber qual rota chamar, quais dados mandar e qual resposta esperar
- É o contrato que permite o backend **mudar internamente sem quebrar clientes**: trocar o banco, dividir o serviço, mudar regra interna — se o contrato fica estável, o cliente continua funcionando
- Contrato bem feito: deixa claro o que pode entrar, o que pode sair e **como o sistema se comporta quando algo dá errado**

## 8. Validação e regra de negócio

**O backend nunca pode confiar no que está vindo.**
- Quantidade negativa → não passa · e-mail que não é e-mail → não passa · preço vindo do cliente → o backend **ignora e recalcula**

**Organizar em camadas** (padrão que não espalha a regra crítica):
- **Controller**: entende de HTTP
- **Service**: entende de regra de negócio
- **Banco**: guarda os dados

Quando a regra fica espalhada, o sistema começa a se contradizer.

## 7. Autenticação e autorização

Duas coisas diferentes:
- **Autenticação**: quem é você (login)
- **Autorização**: o que você pode fazer (permissão)

Você pode estar logado e **mesmo assim não ter permissão** para pagar um usuário. Muita falha de segurança nasce quando o sistema não trata diferente o login da permissão.

O backend recebe alguma credencial (cookie de sessão, JWT token...) e verifica: veio de alguém conhecido? Essa pessoa tem permissão para acessar o recurso?

## 6. Banco de dados e modelagem

Guardar o dado é **decidir como o mundo real vira estrutura no backend**. Ex.: um pedido tem usuário, itens, pagamento, endereço, status.

- Modelagem ruim → regra confusa
- **Normalizar demais** → toda consulta vira vários JOINs, complexa
- Banco também é **performance**: query simples pode virar full scan gigante ou usar **índice** e achar o dado em poucos passos
- Algo lento → uma das primeiras coisas a olhar: consulta ruim? índice faltando? tabelas organizadas de um jeito que obriga o banco a ler de vários lugares?

## 5. Transações e consistência

Transferência: tirar R$ 100 de uma conta (op 1) + adicionar R$ 100 em outra (op 2) — **pro sistema precisa ser uma coisa só**: ou as duas acontecem, ou nenhuma.

- **Transação** cria isolamento: tudo dentro dela confirma ou dá errado junto (rede, bug, processo caindo não deixam estado impossível)
- **Concorrência**: duas pessoas compram o último produto ao mesmo tempo. Ambas leem estoque = 1, ambas tentam confirmar. Se o backend não protege a parte crítica, **vende mais do que tem**. Transação impede dados reais errados
- Consistência tem **tradeoff de tempo** — e quando o tempo vira problema, entra o próximo conceito

## 4. Cache

Cache = guardar uma resposta **perto de onde vai ser usada de novo**, para não calcular tudo ou consultar o banco toda vez.

- **Cache hit**: dado no cache → resposta rápida
- **Cache miss**: busca a informação original, guarda cópia, usa nas próximas vezes

**Problema**: se o dado muda, a cópia fica **velha** — e dado velho gera problema dependendo do domínio. Backend bem feito não usa cache só porque é rápido: **sabe como e quando invalidar** (TTL, invalidação por evento...).

## 3. Filas e workers

Nem tudo precisa acontecer enquanto o usuário espera.

- Checkout precisa responder rápido; **mandar e-mail, gerar nota fiscal** são *jobs* que não precisam travar a resposta principal
- **Fila** separa o pedido do processamento pesado: a API coloca uma mensagem, o **worker** pega depois
- Muitos jobs → fila cresce · precisa processar mais rápido → **sobem mais workers**

**Novos problemas das filas**: e se o job falhar? E se processar duas vezes? E se a fila crescer mais rápido que os workers consomem? → pensar em **retry, idempotência, ordem e monitoramento**.

## 2. Escala e disponibilidade

Escala = capacidade de continuar respondendo quando o volume aumenta. No começo um servidor resolve; conforme cresce: mais usuários, mais chamadas, mais consultas, mais jobs, mais picos.

**Disponibilidade** = sistema continua rodando mesmo com falhas.

- **Escalar vertical**: máquina mais potente (mais CPU/memória na mesma instância)
- **Escalar horizontal**: mais máquinas dividindo o tráfego (o mais usado hoje) — mas exige estratégia

**Stateless**: se cada servidor guarda informação só na própria memória, o usuário cai em outra instância e perde contexto (sessão da máquina A não existe na B; job em andamento some). Backends grandes tentam ser **stateless**: estado importante vai para lugares **compartilhados** (Redis, cache, fila, serviço externo) — qualquer instância responde a próxima requisição.

Disponibilidade também depende de saber quais partes estão saudáveis: **load balancer** (não mandar tráfego pra instância travada), **deploy gradual** (não derrubar tudo de uma vez), **rollback**, **redundância**.

## 1. Observabilidade (o que amarra tudo)

Capacidade de entender o que acontece **dentro** do sistema, coletando sinais que ele emite.

Quando o backend quebrar, você precisa saber mais do que "tá dando erro": **qual rota falhou, qual horário, com qual usuário, depois de qual deploy, em qual parte do fluxo ficou lento**.

**3 sinais**:
| Sinal | Responde |
|---|---|
| **Logs** | O que aconteceu (eventos específicos: requisição feita, validação falhou, pagamento recusado, worker processou job) |
| **Métricas** | Se o problema está crescendo (taxa de erro, latência, CPU, tamanho da fila, req/min) |
| **Traces** | Onde o tempo está sendo gasto (o caminho da requisição: API → auth → service → cache → banco; se o banco gastou 800 ms, o trace mostra) |

Exemplos: depois de um deploy, ver se a taxa de erro subiu; fila acumulando jobs, perceber antes do usuário; query lenta, achar qual rota chama e em quais condições.

Observabilidade **não substitui** banco, cache, fila, autenticação — amarra todos os conceitos no mundo real. **Sem ela, você até constrói um backend, mas não consegue mantê-lo com confiança.**

---

## Exemplos de código — Java 26, Go 1.26 e Python 3.14

3 conceitos com implementações reais (stdlib pura), todas validadas executando: transação nunca vende 2× o último item; cache expira via TTL; validação em camadas retorna 422/201.

### Validação em camadas (controller → service)

```java
// Java 26 — Validacao em camadas (controller -> service).
// Backend nunca confia no cliente: valida primeiro, aplica a regra depois.
import java.util.Map;

record PedidoDTO(String produtoId, int quantidade, double precoCliente, String email) {}
record Resultado(String corpo, int status) {}

final class PedidoService {
    // Regra de negocio: preco do catalogo, nao o preco do cliente
    PedidoDTO criar(PedidoDTO dto) {
        double precoReal = catalogo(dto.produtoId());
        double total = dto.quantidade() * precoReal;
        return new PedidoDTO(dto.produtoId(), dto.quantidade(), total, dto.email());
    }

    private double catalogo(String id) {
        return Map.of("p1", 99.90, "p2", 19.90).getOrDefault(id, 0.0);
    }
}

final class PedidoController {
    private final PedidoService service;

    PedidoController(PedidoService service) { this.service = service; }

    // Camada de entrada: valida o que veio, delega a regra
    Resultado post(PedidoDTO dto) {
        if (dto.quantidade() <= 0)
            return new Resultado("{\"erro\":\"quantidade invalida\"}", 422);
        if (!dto.email().contains("@"))
            return new Resultado("{\"erro\":\"email invalido\"}", 422);

        PedidoDTO pedido = service.criar(dto); // regra de negocio
        return new Resultado("{\"total\":" + pedido.precoCliente() + "}", 201);
    }
}

public class ValidacaoDemo {
    public static void main(String[] args) {
        var controller = new PedidoController(new PedidoService());

        // quantidade negativa -> 422
        System.out.println(controller.post(new PedidoDTO("p1", -1, 1.0, "a@x.com")));
        // preco do cliente ignorado; usa o do catalogo (99.90 * 2 = 199.80)
        System.out.println(controller.post(new PedidoDTO("p1", 2, 1.0, "a@x.com")));
    }
}
```

```go
// Go 1.26 — Validacao em camadas (controller -> service).
// Backend nunca confia no cliente: valida primeiro, aplica a regra depois.
package main

import (
	"errors"
	"fmt"
)

type PedidoDTO struct {
	ProdutoID    string
	Quantidade   int
	PrecoCliente float64 // o cliente manda, mas o backend recalcula
	Email        string
}

// Camada 1: controller — entende de HTTP e validacao de entrada
type PedidoController struct{ service *PedidoService }

func (c *PedidoController) Post(dto PedidoDTO) (string, int) {
	if dto.Quantidade <= 0 {
		return `{"erro":"quantidade invalida"}`, 422
	}
	if !containsAt(dto.Email) {
		return `{"erro":"email invalido"}`, 422
	}

	// Camada 2: service — regra de negocio
	total, err := c.service.Criar(dto)
	if err != nil {
		return fmt.Sprintf(`{"erro":"%v"}`, err), 422
	}
	return fmt.Sprintf(`{"total":%.2f}`, total), 201
}

type PedidoService struct{}

func (s *PedidoService) Criar(dto PedidoDTO) (float64, error) {
	precoReal, ok := catalogo[dto.ProdutoID]
	if !ok {
		return 0, errors.New("produto nao encontrado")
	}
	// O preco que importa e o do backend, nao o do cliente
	return precoReal * float64(dto.Quantidade), nil
}

var catalogo = map[string]float64{"p1": 99.90, "p2": 19.90}

func containsAt(s string) bool {
	for _, r := range s {
		if r == '@' {
			return true
		}
	}
	return false
}

func main() {
	c := PedidoController{service: &PedidoService{}}

	// quantidade negativa -> 422
	fmt.Println(c.Post(PedidoDTO{ProdutoID: "p1", Quantidade: -1,
		Email: "a@x.com", PrecoCliente: 1.0}))
	// preco do cliente ignorado; usa o do catalogo (99.90 * 2 = 199.80)
	fmt.Println(c.Post(PedidoDTO{ProdutoID: "p1", Quantidade: 2,
		Email: "a@x.com", PrecoCliente: 1.0}))
}
```

```python
# Python 3.14 — Validacao em camadas (controller -> service).
# Backend nunca confia no cliente: valida primeiro, aplica a regra depois.
from dataclasses import dataclass
from typing import Protocol


# Camada 1: controller — entende de HTTP e validacao de entrada
@dataclass(frozen=True)
class PedidoDTO:
    produto_id: str
    quantidade: int
    preco: float  # o cliente manda, mas o backend recalcula


class PedidoService(Protocol):
    def criar_pedido(self, produto_id: str, quantidade: int,
                     preco_cliente: float) -> dict: ...


class PedidoController:
    def __init__(self, service: PedidoService) -> None:
        self._service = service

    def post(self, body: dict) -> tuple[dict, int]:
        # Validacao: nunca confiar no que veio
        qtd = body.get("quantidade", 0)
        if qtd <= 0:
            return {"erro": "quantidade invalida"}, 422
        if "@" not in body.get("email", ""):
            return {"erro": "email invalido"}, 422

        # Regra de negocio fica no service
        pedido = self._service.criar_pedido(
            body["produto_id"], qtd, body.get("preco", 0.0))
        return pedido, 201


# Camada 2: service — regra de negocio
class PedidoServiceImpl:
    def criar_pedido(self, produto_id: str, quantidade: int,
                     preco_cliente: float) -> dict:
        # O preco que importa e o do backend, nao o do cliente
        preco_real = self._preco_catalogo(produto_id)
        total = quantidade * preco_real
        return {"pedido": produto_id, "total": round(total, 2)}

    def _preco_catalogo(self, produto_id: str) -> float:
        return {"p1": 99.90, "p2": 19.90}.get(produto_id, 0.0)


if __name__ == "__main__":
    controller = PedidoController(PedidoServiceImpl())

    # quantidade negativa -> 422
    print(controller.post({"produto_id": "p1", "quantidade": -1,
                           "email": "a@x.com", "preco": 1.0}))
    # preco do cliente ignorado; usa o do catalogo
    print(controller.post({"produto_id": "p1", "quantidade": 2,
                           "email": "a@x.com", "preco": 1.0}))
```

### Transação e concorrência (sem oversell)

```java
// Java 26 — Transacao: vender o ultimo item sem oversell
import java.util.concurrent.locks.ReentrantLock;

final class Inventory {
    private int stock;
    private final ReentrantLock lock = new ReentrantLock();

    Inventory(int stock) { this.stock = stock; }

    // "Transacao": verifica + decrementa de forma atomica
    boolean tryBuy(int qty) {
        lock.lock();
        try {
            if (stock < qty) return false;   // sem estoque
            stock -= qty;                     // confirma a venda
            return true;
        } finally {
            lock.unlock();
        }
    }

    int remaining() {
        lock.lock();
        try { return stock; } finally { lock.unlock(); }
    }
}

public class TransacaoDemo {
    public static void main(String[] args) throws Exception {
        var inv = new Inventory(1); // so 1 unidade
        // 2 compradores simultaneos
        var t1 = Thread.ofPlatform().start(() ->
            System.out.println("comprador A: " + (inv.tryBuy(1) ? "comprou" : "sem estoque")));
        var t2 = Thread.ofPlatform().start(() ->
            System.out.println("comprador B: " + (inv.tryBuy(1) ? "comprou" : "sem estoque")));
        t1.join(); t2.join();
        System.out.println("estoque restante: " + inv.remaining());
    }
}
```

```go
// Go 1.26 — Transacao: vender o ultimo item sem oversell
package main

import (
	"fmt"
	"sync"
)

type Inventory struct {
	mu    sync.Mutex
	stock int
}

func NewInventory(stock int) *Inventory { return &Inventory{stock: stock} }

// "Transacao": verifica + decrementa de forma atomica
func (i *Inventory) TryBuy(qty int) bool {
	i.mu.Lock()
	defer i.mu.Unlock()
	if i.stock < qty {
		return false // sem estoque
	}
	i.stock -= qty // confirma a venda
	return true
}

func (i *Inventory) Remaining() int {
	i.mu.Lock()
	defer i.mu.Unlock()
	return i.stock
}

func main() {
	inv := NewInventory(1) // so 1 unidade
	var wg sync.WaitGroup

	// 2 compradores simultaneos
	for _, nome := range []string{"comprador A", "comprador B"} {
		wg.Add(1)
		go func(nome string) {
			defer wg.Done()
			if inv.TryBuy(1) {
				fmt.Println(nome + ": comprou")
			} else {
				fmt.Println(nome + ": sem estoque")
			}
		}(nome)
	}
	wg.Wait()
	fmt.Println("estoque restante:", inv.Remaining())
}
```

```python
# Python 3.14 — Transacao: vender o ultimo item sem oversell.
import threading
from dataclasses import dataclass


@dataclass
class Inventory:
    stock: int
    _lock: threading.Lock = threading.Lock()

    def try_buy(self, qty: int) -> bool:
        # "Transacao": verifica + decrementa de forma atomica
        with self._lock:
            if self.stock < qty:
                return False  # sem estoque
            self.stock -= qty  # confirma a venda
            return True

    def remaining(self) -> int:
        with self._lock:
            return self.stock


if __name__ == "__main__":
    inv = Inventory(stock=1)  # so 1 unidade

    # 2 compradores simultaneos
    results: list[str] = []
    threads = [
        threading.Thread(target=lambda: results.append(
            "comprador A: " + ("comprou" if inv.try_buy(1) else "sem estoque"))),
        threading.Thread(target=lambda: results.append(
            "comprador B: " + ("comprou" if inv.try_buy(1) else "sem estoque"))),
    ]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    for r in results:
        print(r)
    print("estoque restante:", inv.remaining())
```

### Cache com TTL (hit/miss + invalidação)

```java
// Java 26 — Cache com TTL e expiracao
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

final class TtlCache {
    record Entry(String value, long expiresAt) {}

    private final Map<String, Entry> cache = new ConcurrentHashMap<>();
    private final long ttlMs; // tempo de vida

    TtlCache(long ttlMs) { this.ttlMs = ttlMs; }

    String get(String key) {
        Entry e = cache.get(key);
        if (e == null) return null;                 // cache miss
        if (System.currentTimeMillis() > e.expiresAt()) {
            cache.remove(key);                       // dado velho: invalida
            return null;
        }
        return e.value();                            // cache hit
    }

    void put(String key, String value) {
        cache.put(key, new Entry(value, System.currentTimeMillis() + ttlMs));
    }

    int size() { return cache.size(); }
}

public class CacheDemo {
    public static void main(String[] args) throws Exception {
        var cache = new TtlCache(100); // 100 ms de TTL
        cache.put("produto:42", "{\"nome\":\"Teclado\"}");

        System.out.println("hit: " + cache.get("produto:42"));
        Thread.sleep(150); // deixa expirar
        System.out.println("apos TTL (miss): " + cache.get("produto:42"));
        System.out.println("tamanho: " + cache.size());
    }
}
```

```go
// Go 1.26 — Cache com TTL e expiracao
package main

import (
	"fmt"
	"sync"
	"time"
)

type Cache struct {
	mu    sync.RWMutex
	items map[string]item
	ttl   time.Duration
}

type item struct {
	value     string
	expiresAt time.Time
}

func NewCache(ttl time.Duration) *Cache {
	return &Cache{items: make(map[string]item), ttl: ttl}
}

func (c *Cache) Get(key string) (string, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	it, ok := c.items[key]
	if !ok {
		return "", false // cache miss
	}
	if time.Now().After(it.expiresAt) {
		delete(c.items, key) // dado velho: invalida
		return "", false
	}
	return it.value, true // cache hit
}

func (c *Cache) Put(key, value string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.items[key] = item{value: value, expiresAt: time.Now().Add(c.ttl)}
}

func main() {
	cache := NewCache(100 * time.Millisecond)
	cache.Put("produto:42", `{"nome":"Teclado"}`)

	v, hit := cache.Get("produto:42")
	fmt.Println("hit:", hit, v)
	time.Sleep(150 * time.Millisecond) // deixa expirar
	v, hit = cache.Get("produto:42")
	fmt.Println("apos TTL (miss):", hit, v)
	fmt.Println("tamanho:", len(cache.items))
}
```

```python
# Python 3.14 — Cache com TTL e expiracao (thread-safe).
import threading
import time
from dataclasses import dataclass


@dataclass
class Item:
    value: str
    expires_at: float


class TtlCache:
    def __init__(self, ttl_ms: int) -> None:
        self._ttl_s = ttl_ms / 1000
        self._items: dict[str, Item] = {}
        self._lock = threading.Lock()

    def get(self, key: str) -> str | None:
        with self._lock:
            it = self._items.get(key)
            if it is None:
                return None  # cache miss
            if time.monotonic() > it.expires_at:
                del self._items[key]  # dado velho: invalida
                return None
            return it.value  # cache hit

    def put(self, key: str, value: str) -> None:
        with self._lock:
            self._items[key] = Item(value, time.monotonic() + self._ttl_s)

    def size(self) -> int:
        with self._lock:
            return len(self._items)


if __name__ == "__main__":
    cache = TtlCache(ttl_ms=100)
    cache.put("produto:42", '{"nome":"Teclado"}')

    print("hit:", cache.get("produto:42"))
    time.sleep(0.15)  # deixa expirar
    print("apos TTL (miss):", cache.get("produto:42"))
    print("tamanho:", cache.size())
```

---

## Mapa mental (os 10 em uma linha)

1. **Requisição/resposta** — o idioma básico (método, rota, headers, body, status)
2. **Contrato de API** — quem pede e quem responde combinam o formato
3. **Validação + regra de negócio** — nunca confiar no cliente; camadas controller/service/banco
4. **AuthN + AuthZ** — quem é você ≠ o que você pode fazer
5. **Banco + modelagem** — mundo real vira estrutura; índices = performance
6. **Transações + consistência** — ou tudo acontece, ou nada; protege concorrência
7. **Cache** — resposta perto de onde é usada; saber invalidar (TTL)
8. **Filas + workers** — o que não precisa travar a resposta; retry/idempotência/ordem
9. **Escala + disponibilidade** — vertical vs horizontal; stateless com estado compartilhado
10. **Observabilidade** — logs (o quê), métricas (crescimento), traces (onde gasta tempo)