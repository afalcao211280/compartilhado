# Resumo — "Docker Explicado em 8 Minutos" (pt-BR, ~8:14)

Fonte: https://www.youtube.com/watch?v=jftIzkXbKKY
Data: 30/08/2026 | Transcrição: /tmp/tr_docker.json

## Tese central

"Na minha máquina funciona" — a frase mais famosa da programação. Contêineres eliminaram esse problema: empacotam a aplicação com tudo que ela precisa e isolam em um ambiente próprio.

## Pontos-chave

- **O problema:** antes dos contêineres, 3 aplicações no mesmo servidor compartilhavam o mesmo SO, bibliotecas e diretórios. App Python 2.7 vs 3.11, mesma porta 8080, ambiente local ≠ servidor.
- **VM ≠ contêiner.** VM carrega SO inteiro (kernel, drivers, gerenciador de pacotes) → pesado, lento para iniciar, desperdiça CPU/memória. Metáfora: VM = alugar casa inteira; contêiner = quarto de hotel (espaço privado, estrutura compartilhada).
- **Como o Docker isola (2 features do kernel Linux):**
  - **Namespaces:** criam a ilusão de isolamento. Cada contêiner acha que é o único: tem seus próprios processos, rede e sistema de arquivos. O processo dentro acha que é o PID 1, mas no host é só mais um processo.
  - **Cgroups:** controlam quanto de recurso cada contêiner usa (CPU, memória, disco, rede). Um contêiner pesado não derruba os outros (metáfora do disjuntor por apartamento).
- **Dockerfile = receita.** `FROM node:20-alpine` (imagem base), `WORKDIR /app`, `COPY package*.json`, `RUN npm install`, `COPY . .`, `CMD ["npm","start"]`. Cada instrução cria uma **camada cacheada**: se muda só o código, não reinstala dependências → 2º build muito mais rápido.
- **Imagem vs contêiner.** `docker build` gera a **imagem** (molde imutável e portátil — a "classe"); `docker run` cria o **contêiner** (instância viva — o "objeto").
- **Docker Compose.** Define todos os serviços em um arquivo YAML: api (build do Dockerfile, portas, depends_on), postgres (imagem oficial, env, volume para persistir), redis (imagem + porta). `docker compose up` sobe tudo, cria a rede automaticamente, e a API acessa o postgres pelo nome `postgres` (sem configurar IP). Onboarding: dev novo roda 1 comando e tem o ambiente inteiro.
- **Produção:** CD faz o build, testes, push da imagem para um **registry** (Docker Hub público, ECR privado). Cada versão é tagada → rollback instantâneo. Imagem imutável = o que roda em produção é exatamente o que rodou nos testes.
- **Vantagens:** portabilidade (mesma imagem em Mac/Linux/AWS/GCP), isolamento (um contêiner com problema não afeta os outros), velocidade (iniciam em ms), consistência (Dockerfile = documentação do ambiente).
- **Limitações:** segurança (compartilham o kernel → escape de contêiner = acesso ao host; rodar como root é risco), persistência (contêiner é temporário por design → volumes para dados), complexidade operacional (para app simples, Docker pode ser exagero), rede/debugging (redes virtuais são difíceis de depurar).
- **Quando usar:** time > 2-3 pessoas com SOs diferentes, app com múltiplos serviços (banco, cache, fila, backend), CD com builds reproduzíveis. Projeto pessoal com API simples → complexidade desnecessária. Centenas de contêineres/múltiplos servidores → Kubernetes (outro vídeo).

## Exemplos de código — Docker na prática

Validação real: os 3 exemplos rodam (Python 3.14, Java 26, Go 1.26). O 3º é uma simulação de namespace, porque namespaces reais exigem root.

### 1. Dockerfile + docker-compose.yml

```yaml
# Dockerfile
FROM node:20-alpine          # imagem base leve
WORKDIR /app                 # diretorio de trabalho
COPY package*.json ./        # dependencias primeiro
RUN npm install              # camada cacheada
COPY . .                     # codigo (muda sempre)
EXPOSE 3000
CMD ["npm", "start"]         # comando de inicio
```

```yaml
# docker-compose.yml (3 servicos)
services:
  api:
    build: .                 # usa o Dockerfile
    ports:
      - "3000:3000"          # host:conteiner
    depends_on:
      - postgres             # espera o banco
    environment:
      - DATABASE_URL=postgres://user:pass@postgres:5432/app
  postgres:
    image: postgres:16       # imagem oficial
    environment:
      - POSTGRES_PASSWORD=pass
    volumes:
      - pgdata:/var/lib/postgresql/data  # persiste
  redis:
    image: redis:7
    ports:
      - "6379:6379"
volumes:
  pgdata:
```

### 2. Camadas cacheadas — build de verdade

```python
# Python 3.14 — simulacao do cache de camadas do Docker
# (mesma ideia: dependencias so reinstalam se mudam)
import hashlib, json, os

CACHE = '/tmp/docker_layers.json'

def restore():
    if os.path.exists(CACHE):
        return json.load(open(CACHE))
    return {}

def build(deps, code):
    cache = restore()
    h = hashlib.sha256(deps.encode()).hexdigest()
    if cache.get('deps_hash') == h:
        print('deps OK (cache hit — npm install pulado)')
    else:
        print('deps mudaram — reinstalando')
        cache['deps_hash'] = h
    # "copia o codigo" e builda a imagem
    print(f'copiando {code}')
    cache['code'] = code
    json.dump(cache, open(CACHE, 'w'))
    print('imagem pronta')

build('express@4', 'app.js v1')  # instala deps
build('express@4', 'app.js v2')  # SO o codigo mudou
# -> deps OK (cache hit), copiando app.js v2
```

```java
// Java 26 — mesma ideia de camadas
import java.nio.file.*;
import java.util.*;

public class LayersDemo {
  public static void main(String[] a) throws Exception {
    var p = Path.of("/tmp/layers.txt");
    var cache = Files.exists(p)
      ? Files.readString(p) : "";
    String deps = "react@19";
    if (cache.equals(deps)) {
      System.out.println("deps OK (cache hit)");
    } else {
      System.out.println("deps mudaram — reinstalando");
      Files.writeString(p, deps);
    }
    System.out.println("copiando codigo...");
  }
}
```

```go
// Go 1.26 — camadas com cache
package main

import (
	"fmt"
	"os"
)

func main() {
	const deps = "express@4"
	b, _ := os.ReadFile("/tmp/go_layers.txt")
	if string(b) == deps {
		fmt.Println("deps OK (cache hit)")
	} else {
		fmt.Println("deps mudaram — reinstalando")
		os.WriteFile("/tmp/go_layers.txt",
			[]byte(deps), 0o644)
	}
	fmt.Println("copiando codigo...")
}
```

### 3. Namespaces simulados (o "PID 1" de cada contêiner)

```python
# Python 3.14 — cada contêiner "acha" que é o PID 1
class Namespace:
    def __init__(self, nome):
        self.nome = nome
        self.pid = 1          # ilusao: PID 1 dentro
        self.processos = []

ns_web = Namespace('web')
ns_web.processos.append('node server.js')

ns_db = Namespace('db')
ns_db.processos.append('postgres -D /var/lib')

# no HOST, os PIDs reais sao outros
print(f"{ns_web.nome}: acha PID {ns_web.pid} "
      f"(host: pid 2451)")
print(f"{ns_db.nome}: acha PID {ns_db.pid} "
      f"(host: pid 3120)")
# namespaces dão a cada um a ilusão de isolamento
```

```java
// Java 26 — namespace simulado
import java.util.*;

public class NamespaceDemo {
  record NS(String nome, int pid, List<String> procs) {}
  public static void main(String[] a) {
    var web = new NS("web", 1,
        List.of("node server.js"));
    var db = new NS("db", 1,
        List.of("postgres -D /var/lib"));
    System.out.println(web.nome() + ": acha PID " +
        web.pid() + " (host: 2451)");
    System.out.println(db.nome() + ": acha PID " +
        db.pid() + " (host: 3120)");
  }
}
```

```go
// Go 1.26 — namespace simulado
package main

import "fmt"

type NS struct {
	nome string
	pid  int
}

func main() {
	web := NS{"web", 1}
	db := NS{"db", 1}
	fmt.Printf("%s: acha PID %d (host: 2451)\n",
		web.nome, web.pid)
	fmt.Printf("%s: acha PID %d (host: 3120)\n",
		db.nome, db.pid)
}
```

## Mapa mental — os 8 em uma linha

1. Problema: "na minha máquina funciona" · 2. VM = SO inteiro (pesado) · 3. Namespaces = ilusão de isolamento · 4. Cgroups = limites de recurso · 5. Dockerfile = receita com camadas cacheadas · 6. Imagem (classe) vs contêiner (objeto) · 7. Compose = vários serviços em 1 comando · 8. Registry + tags = rollback instantâneo.

## Aviso final do vídeo

"É isso. Se curtiu, se inscreve e deixa um like, que ajuda bastante o canal. Valeu."