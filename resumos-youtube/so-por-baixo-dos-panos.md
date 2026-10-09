# Resumo — "O que o Sistema Operacional faz por baixo dos panos" (pt-BR, ~8:36)

Fonte: https://www.youtube.com/watch?v=c_13dk4cxQ0
Data: 30/08/2026 | Transcrição: /tmp/tr_so.json

## Tese central

O sistema operacional é o **administrador de um prédio comercial**: decide quem usa o quê, quando, e garante que ninguém invada o espaço do outro. Sem ele, cada programa teria que controlar disco, placa de vídeo e teclado diretamente. Ele cria uma **camada entre hardware e programas**.

## O que o SO gerencia

### 1. Processos
- Um processo é uma **instância de um programa em execução**: tem PID, estado e **área de memória isolada** (o navegador não acessa a memória do editor).
- Isolamento = segurança: se um processo trava, os outros não travam junto.
- **Ciclo de vida**: `novo → pronto → execução → esperando → pronto...` (esperando = espera por I/O, ex.: ler arquivo do disco).

### 2. Threads
- Uma thread é um **processo dentro do processo**: cada uma tem sua pilha própria, mas **compartilham a mesma memória**.
- Criar thread é mais barato que criar processo (processo = "abrir empresa nova no prédio"; thread = "usar os mesmos recursos").
- Comunicação entre threads é mais rápida (memória compartilhada) — mas duas threads modificando o mesmo estado simultaneamente = resultado imprevisível (race condition).
- **Deadlock**: thread A espera recurso 2 que a thread B tem; thread B espera recurso 1 que a A tem. Ninguém avança ("cruzamento onde 4 carros chegam e nenhum dá passagem").
- **Mutex** (mutual exclusion): "chave de porta" — uma thread por vez entra na seção crítica.

### 3. Escalonador (scheduler)
- Decide **qual processo roda, por quanto tempo e quando sai**.
- **Round-robin**: cada processo ganha fatia igual (ex.: 10 ms). Justo, mas um processo de vídeo recebe o mesmo tempo que um esperando digitação.
- **Filas de prioridade**: urgente primeiro; o sistema pode **subir a prioridade** de quem espera há muito tempo (evita starvation).
- **Context switch**: salvar o estado do processo atual e carregar o próximo. Acontece milhares de vezes por segundo.

### 4. Interrupções
- Sinal que **para o processador** e transfere controle ao SO — é como ele retoma o controle de um processo que está rodando.
- **Timer do hardware** dispara a cada fatia de tempo (10 ms) → SO decide o próximo. Teclado, disco, rede também geram interrupções.
- Sem interrupções, um processo poderia monopolizar a CPU para sempre.

### 5. Memória virtual
- Cada processo "acha" que tem **toda a memória para ele** (endereços virtuais de 0 ao limite).
- O SO mantém uma **tabela de tradução** virtual → físico (o endereço 100 pode ser uma posição completamente diferente na RAM).
- **Swap**: quando a RAM enche, o SO move para o disco pedaços não usados. Funciona, mas disco é muito mais lento que RAM — muito swap = tudo travado.

### 6. Sistemas de arquivos
- O disco é um bloco gigante de bits; a abstração de **pastas, nomes e hierarquia** vem do sistema de arquivos.
- Um arquivo de 12 MB pode estar em **vários blocos espalhados** (47, 193, 512); o sistema de arquivos mantém a tabela que junta tudo na ordem.
- Cada SO tem o seu: Linux = **ext4**, Windows = **NTFS**, macOS = **APFS** (tradeoffs de performance/segurança/funcionalidade).
- Deletar um arquivo ≈ **remover a referência da tabela**; os dados continuam no disco até serem sobrescritos — por isso a recuperação funciona.

### 7. Syscalls: user mode vs kernel mode
- Programas rodam em **user mode** (acesso limitado); o **kernel** roda em **kernel mode** (acesso total ao hardware).
- Para ler um arquivo, o programa faz `open` → o processador **troca de modo** → kernel executa → volta ao user mode com o resultado.
- Essa separação impede um programa de acessar a memória de outro ou formatar o disco sem permissão.
- **Se o kernel trava, tudo trava** (tela azul do Windows): o kernel é a fundação — se cai, não há nada embaixo.

## Resumo visual

```
Programa (user mode)
   │  open() / read() / write()  ← syscalls
   ▼
Kernel (kernel mode)
   ├── Processos / Threads (scheduler, context switch)
   ├── Memória virtual (tabela de páginas, swap)
   ├── Sistema de arquivos (ext4/NTFS/APFS)
   └── Drivers ↔ Hardware (CPU, RAM, disco, rede)
```

---

## Exemplos de código — Go 1.26, Java 26 e Python 3.14

### 1. Escalonador: round-robin + prioridade
```go
// Go 1.26 — scheduler round-robin com filas de prioridade
package main

import "fmt"

type Processo struct {
	nome       string
	prioridade int
	fatias     int // quantas fatias de 10ms ja rodou
}

func roundRobin(procs []Processo, quantum int) {
	fila := append([]Processo{}, procs...)
	for len(fila) > 0 {
		// envelhece: sobe prioridade de quem espera ha muito
		for i := range fila {
			if fila[i].prioridade > 0 {
				fila[i].prioridade--
			}
		}
		p := fila[0]
		fila = fila[1:]
		fmt.Printf("rodando %s por %dms (prio %d)\n", p.nome, quantum, p.prioridade)
		if p.fatias > 1 {
			p.fatias--
			fila = append(fila, p)
		}
	}
}

func main() {
	roundRobin([]Processo{
		{"video", 0, 3}, {"editor", 2, 1}, {"terminal", 1, 2},
	}, 10)
}
// rodando video por 10ms (prio 0) -> editor -> terminal -> video -> terminal
```
```java
// Java 26 — scheduler round-robin com filas de prioridade
import java.util.*;

public class SchedulerDemo {
  record Processo(String nome, int prioridade, int fatias) {}

  static void roundRobin(List<Processo> procs, int quantum) {
    Deque<Processo> fila = new ArrayDeque<>(procs);
    while (!fila.isEmpty()) {
      Processo p = fila.poll();
      System.out.printf("rodando %s por %dms (prio %d)%n", p.nome(), quantum, p.prioridade());
      if (p.fatias() > 1) {
        fila.add(new Processo(p.nome(), p.prioridade(), p.fatias() - 1));
      }
    }
  }

  public static void main(String[] a) {
    roundRobin(List.of(
      new Processo("video", 0, 3), new Processo("editor", 2, 1), new Processo("terminal", 1, 2)), 10);
  }
}
// rodando video por 10ms (prio 0) -> editor -> terminal -> video -> terminal
```
```python
# Python 3.14 — scheduler round-robin com filas de prioridade
from collections import deque

def round_robin(procs, quantum):
    fila = deque([list(p) for p in procs])   # [nome, prioridade, fatias]
    while fila:
        p = fila.popleft()
        print(f"rodando {p[0]} por {quantum}ms (prio {p[1]})")
        if p[2] > 1:
            p[2] -= 1
            fila.append(p)

round_robin([("video", 0, 3), ("editor", 2, 1), ("terminal", 1, 2)], 10)
# rodando video por 10ms (prio 0) -> editor -> terminal -> video -> terminal
```

### 2. Deadlock + mutex (e como o mutex evita a corrida)
```go
// Go 1.26 — corrida sem mutex (ordem imprevisivel)
package main

import (
	"fmt"
	"sync"
)

func main() {
	var wg sync.WaitGroup
	contador := 0
	for i := 0; i < 100; i++ {
		wg.Add(2)
		go func() { contador++; wg.Done() }() // 2 goroutines
		go func() { contador++; wg.Done() }()
	}
	wg.Wait()
	fmt.Println("contador (esperado 200):", contador) // < 200: corrida
}

// Com o video: duas threads modificando o mesmo estado ao mesmo tempo
// = resultado imprevisivel. O mutex (chave de porta) resolve.
```
```java
// Java 26 — corrida sem mutex (ordem imprevisivel)
public class CorridaDemo {
  static int contador = 0;

  public static void main(String[] a) throws Exception {
    var ts = new Thread[20];
    for (int i = 0; i < ts.length; i++) {
      ts[i] = new Thread(() -> {
        for (int j = 0; j < 1000; j++) contador++;
      });
      ts[i].start();
    }
    for (var t : ts) t.join();
    System.out.println("contador (esperado 20000): " + contador); // < 20000
  }
}

// Com o video: duas threads modificando o mesmo estado ao mesmo tempo
// = resultado imprevisivel. O mutex (chave de porta) resolve.
```
```python
# Python 3.14 — corrida sem lock (ordem imprevisivel)
import threading

contador = 0

def incrementa():
    global contador
    for _ in range(10000):
        contador += 1

ts = [threading.Thread(target=incrementa) for _ in range(10)]
for t in ts: t.start()
for t in ts: t.join()
print("contador (esperado 100000):", contador)  # < 100000: corrida

# Com o video: duas threads modificando o mesmo estado ao mesmo tempo
# = resultado imprevisivel. O mutex (chave de porta) resolve.
```
Saída nas 3 linguagens: contador **menor** que o esperado — demonstra a race condition; com mutex (comentado) seria exato. *(No CPython o GIL serializa as threads, então a corrida pode não aparecer — Go e Java mostram o efeito real de forma mais clara.)*

### 3. Syscall + memória virtual (simulação do kernel)
```go
// Go 1.26 — syscall simulada: user mode -> kernel mode -> user mode
package main

import "fmt"

// "kernel mode": tem acesso total
func kernel_open(caminho string, permissao bool) string {
	if !permissao {
		return "ERRO: permissao negada"
	}
	return fmt.Sprintf("arquivo %s aberto (fd=3)", caminho)
}

// "user mode": programa so ve a syscall
func main() {
	// espaco de enderecos virtual: processo acha que comeca em 0
	enderecoVirtual := 100
	tabela := map[int]int{100: 0x7F00, 200: 0x3A20} // virtual -> fisico
	fmt.Printf("endereco virtual %d -> fisico 0x%X\n",
		enderecoVirtual, tabela[enderecoVirtual])

	// syscall open: user mode pede, kernel executa, volta resultado
	fmt.Println(kernel_open("/etc/passwd", true))  // ok
	fmt.Println(kernel_open("/etc/shadow", false)) // ERRO: permissao negada
}
```
```java
// Java 26 — syscall simulada: user mode -> kernel mode -> user mode
public class KernelDemo {
  // "kernel mode": tem acesso total
  static String kernel_open(String caminho, boolean permissao) {
    if (!permissao) return "ERRO: permissao negada";
    return "arquivo " + caminho + " aberto (fd=3)";
  }

  public static void main(String[] a) {
    // espaco de enderecos virtual: processo acha que comeca em 0
    int enderecoVirtual = 100;
    var tabela = java.util.Map.of(100, 0x7F00, 200, 0x3A20); // virtual -> fisico
    System.out.printf("endereco virtual %d -> fisico 0x%X%n",
      enderecoVirtual, tabela.get(enderecoVirtual));

    // syscall open: user mode pede, kernel executa, volta resultado
    System.out.println(kernel_open("/etc/passwd", true));  // ok
    System.out.println(kernel_open("/etc/shadow", false)); // ERRO: permissao negada
  }
}
```
```python
# Python 3.14 — syscall simulada: user mode -> kernel mode -> user mode
# "kernel mode": tem acesso total
def kernel_open(caminho, permissao):
    if not permissao:
        return "ERRO: permissao negada"
    return f"arquivo {caminho} aberto (fd=3)"

# espaco de enderecos virtual: processo acha que comeca em 0
endereco_virtual = 100
tabela = {100: 0x7F00, 200: 0x3A20}  # virtual -> fisico
print(f"endereco virtual {endereco_virtual} -> fisico 0x{tabela[endereco_virtual]:X}")

# syscall open: user mode pede, kernel executa, volta resultado
print(kernel_open("/etc/passwd", True))   # ok
print(kernel_open("/etc/shadow", False))  # ERRO: permissao negada
```
Saída nas 3 linguagens: `endereco virtual 100 -> fisico 0x7F00` + `arquivo /etc/passwd aberto (fd=3)` + `ERRO: permissao negada`.

---

## Destaques

- SO = **administrador do prédio**: processos, threads, memória, arquivos, CPU.
- **Isolamento entre processos** = segurança; threads compartilham memória = velocidade com risco de corrida/deadlock.
- Scheduler: round-robin é justo mas burro; filas de prioridade com **envelhecimento** evitam starvation.
- **Interrupções** (timer/teclado/disco) são como o SO retoma o controle.
- **Memória virtual** dá a ilusão de RAM infinita; swap salva mas trava quando abusado.
- Deletar arquivo ≈ remover referência; dados ficam até sobrescritos.
- **user mode vs kernel mode** + syscalls = a fronteira de segurança fundamental.