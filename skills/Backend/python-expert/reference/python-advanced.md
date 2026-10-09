# Python Avançado — Tipagem, Async e Stdlib

Fundamentos transversais de Python moderno (independem de framework). Condensado do que agrega valor real além do CRUD FastAPI/Django. Leia ao modelar tipos ricos, concorrência estruturada ou ao usar a stdlib com propriedade.

## Índice

1. [Type system](#1-type-system)
2. [Async patterns](#2-async-patterns)
3. [Stdlib de alto valor](#3-stdlib-de-alto-valor)

---

## 1. Type system

Regra EVEO: type hints em tudo, `mypy --strict` no CI, `X | None` (não `Optional[X]`), `list[str]` (não `List[str]`), `collections.abc` para parâmetros (`Sequence`/`Mapping` em vez de `list`/`dict` quando só se lê).

### Generics e Protocol (structural typing)

```python
from typing import Generic, TypeVar, Protocol, runtime_checkable
from collections.abc import Sequence

T = TypeVar("T")
K = TypeVar("K")
V = TypeVar("V")

def first(items: Sequence[T]) -> T | None:
    return items[0] if items else None

class Cache(Generic[K, V]):
    def __init__(self) -> None:
        self._data: dict[K, V] = {}
    def get(self, key: K) -> V | None:
        return self._data.get(key)

# Protocol: interface sem herança (duck typing checado estaticamente).
# Preferir a ABC quando o contrato é implementado por classes que você não controla.
class SupportsClose(Protocol):
    def close(self) -> None: ...

@runtime_checkable  # permite isinstance() em runtime — use com parcimônia
class Drawable(Protocol):
    def draw(self) -> str: ...
```

### Literal, TypeAlias, TypedDict, Self, overload

```python
from typing import Literal, TypeAlias, TypedDict, NotRequired, Self, overload
from typing import Any

Mode = Literal["read", "write", "append"]   # valores fixos, checados
JsonDict: TypeAlias = dict[str, Any]

class UserDict(TypedDict):
    id: int
    name: str
    age: NotRequired[int]   # campo opcional

class QueryBuilder:
    def where(self, cond: str) -> Self:   # Self habilita method chaining tipado
        ...
        return self

@overload
def parse(v: str) -> str: ...
@overload
def parse(v: int) -> int: ...
def parse(v: str | int) -> str | int:
    return v.upper() if isinstance(v, str) else v * 2
```

### Type narrowing e exaustividade

```python
from typing import assert_never

def handle(mode: Literal["read", "write"]) -> str:
    if mode == "read":
        return "Reading"
    if mode == "write":
        return "Writing"
    assert_never(mode)   # mypy erra se um caso novo do Literal não for tratado
```

### ParamSpec (decorators que preservam a assinatura)

```python
from collections.abc import Callable
from typing import ParamSpec, TypeVar
import functools

P = ParamSpec("P")
R = TypeVar("R")

def logged(func: Callable[P, R]) -> Callable[P, R]:
    @functools.wraps(func)
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
        return func(*args, **kwargs)
    return wrapper

# Concatenate: injeta o 1º parâmetro e some com ele na assinatura exposta
from typing import Concatenate

def with_conn(func: Callable[Concatenate[Conn, P], R]) -> Callable[P, R]:
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
        return func(get_conn(), *args, **kwargs)   # conn some p/ o chamador
    return wrapper
```

> Config de `mypy --strict` (o gate de tipos da EVEO) e `ruff` estão em `packaging.md`.

### Result pattern (erros como valor, sem exceção no caminho feliz)

```python
from dataclasses import dataclass
from typing import Generic, TypeVar

T = TypeVar("T")

@dataclass(frozen=True)
class Ok(Generic[T]):
    value: T

@dataclass(frozen=True)
class Err:
    message: str

Result = Ok[T] | Err

def divide(a: int, b: int) -> Result[float]:
    return Err("divisão por zero") if b == 0 else Ok(a / b)
```

---

## 2. Async patterns

Regra EVEO: todo I/O em FastAPI é `async def`; nunca bloquear o event loop; I/O síncrono inevitável vai para `run_in_executor`.

### TaskGroup (concorrência estruturada, Python 3.11+) — preferir a `gather`

```python
from asyncio import TaskGroup

async def process_batch(items: list[int]) -> list[int]:
    async with TaskGroup() as tg:          # cancela irmãs se uma falhar
        tasks = [tg.create_task(work(i)) for i in items]
    return [t.result() for t in tasks]     # todas concluídas aqui

# Falhas viram ExceptionGroup — trate com except*
try:
    async with TaskGroup() as tg:
        for it in items:
            tg.create_task(work(it))
except* ValueError as eg:
    for exc in eg.exceptions:
        log.warning("falha", error=str(exc))
```

### Async context manager (recurso com commit/rollback)

```python
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

@asynccontextmanager
async def db_session() -> AsyncIterator[Session]:
    session = await create_session()
    try:
        yield session
        await session.commit()
    except Exception:
        await session.rollback()
        raise
    finally:
        await session.close()
```

### Timeout e primitivas de sincronização

```python
import asyncio

async def fetch_timeout(url: str, timeout: float) -> dict | None:
    try:
        async with asyncio.timeout(timeout):   # 3.11+
            return await fetch(url)
    except TimeoutError:
        return None

sem = asyncio.Semaphore(10)     # limita concorrência (rate limit interno)
async def guarded(x: str) -> str:
    async with sem:
        return await expensive(x)
```

### Rodar código síncrono sem travar o loop

```python
import asyncio, functools
from collections.abc import Callable
from typing import Any, TypeVar

T = TypeVar("T")

async def to_thread(func: Callable[..., T], *args: Any, **kwargs: Any) -> T:
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, functools.partial(func, *args, **kwargs))
    # Python 3.9+: prefira asyncio.to_thread(func, *args) diretamente
```

### Producer/consumer com Queue (backpressure)

`Queue(maxsize=N)` dá backpressure: o producer bloqueia no `put` quando cheia, evitando estourar memória. Ideal para ingestão em lote (consumir de um stream e persistir com N workers).

```python
from asyncio import Queue, TaskGroup

async def producer(q: Queue[Item], source: AsyncIterator[Item]) -> None:
    async for item in source:
        await q.put(item)          # bloqueia se a fila estiver cheia (backpressure)

async def consumer(q: Queue[Item]) -> None:
    while True:
        item = await q.get()
        try:
            await persist(item)
        finally:
            q.task_done()          # sinaliza p/ join()

async def pipeline(source: AsyncIterator[Item], workers: int = 4) -> None:
    q: Queue[Item] = Queue(maxsize=100)
    async with TaskGroup() as tg:
        tg.create_task(producer(q, source))
        consumers = [tg.create_task(consumer(q)) for _ in range(workers)]
        await q.join()             # espera drenar tudo
        for c in consumers:
            c.cancel()             # encerra os workers ociosos
```

### Background tasks fire-and-forget (sem perder a referência)

Task criada e não referenciada pode ser coletada pelo GC no meio da execução. Guarde num `set` e limpe no callback. (Em rota FastAPI, prefira `BackgroundTasks` do próprio framework; use isto em consumers/workers de longa duração.)

```python
_bg: set[asyncio.Task[None]] = set()

def spawn(coro: Coroutine[Any, Any, None]) -> None:
    task = asyncio.create_task(coro)
    _bg.add(task)                       # mantém referência forte
    task.add_done_callback(_bg.discard) # libera ao concluir
```

### Async generator para streaming (SSE, export grande)

Streaming evita materializar o resultado inteiro em memória — o consumidor recebe página a página. Base para respostas SSE/`StreamingResponse` no FastAPI.

```python
from collections.abc import AsyncIterator

async def stream_rows(repo: Repo, page_size: int = 500) -> AsyncIterator[Row]:
    offset = 0
    while True:
        rows = await repo.page(offset, page_size)
        if not rows:
            return
        for row in rows:
            yield row
        offset += page_size
```

---

## 3. Stdlib de alto valor

Preferir a stdlib a dependências externas quando resolve o problema.

### functools

```python
from functools import cache, lru_cache, cached_property, singledispatch

@cache                       # memoização ilimitada (3.9+); cuidado com vazamento
def fib(n: int) -> int: ...

class Stats:
    @cached_property         # computa uma vez por instância
    def mean(self) -> float: ...

@singledispatch              # dispatch por tipo do 1º argumento
def render(x: object) -> str: return str(x)
@render.register
def _(x: int) -> str: return f"int:{x}"
```

### contextlib

```python
from contextlib import suppress, ExitStack

with suppress(FileNotFoundError):        # ignora exceção específica sem try/except
    path.unlink()

with ExitStack() as stack:               # N context managers dinâmicos
    files = [stack.enter_context(open(f)) for f in filenames]
```

### collections

```python
from collections import defaultdict, Counter, deque, ChainMap

idx: defaultdict[str, list[int]] = defaultdict(list)
top = Counter(words).most_common(3)
buf: deque[int] = deque(maxlen=100)       # ring buffer O(1) nas pontas
cfg = ChainMap(env_overrides, defaults)   # config em camadas
```

### pathlib e enum

```python
from pathlib import Path
from enum import Enum, IntEnum, Flag, auto

root = Path(__file__).resolve().parent
py_files = list(root.rglob("*.py"))       # nunca os.path para paths novos

class Status(Enum):
    PENDING = "pending"
    APPROVED = "approved"

class Perm(Flag):                          # bit flags combináveis
    READ = auto(); WRITE = auto(); EXEC = auto()
```
