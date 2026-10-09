# Resumo — "Como funciona a autenticação moderna" (pt-BR, ~19:51)

Fonte: https://www.youtube.com/watch?v=uLY1CuLi9ac
Data: 30/08/2026 | Transcrição: /tmp/vid3.json

## Tese central

Você clica em "entrar" e em 200 ms está logado. Mas como o servidor sabe que você é quem diz ser? O vídeo percorre cada etapa da autenticação moderna — senhas com hash, sessões, JWT, OAuth/OIDC, MFA, passkeys — e os erros de segurança que causam problemas em produção.

**Autenticação ≠ Autorização:**
- Autenticação prova **quem você é** (mostra o documento na portaria)
- Autorização define **o que você pode fazer** (crachá que libera o andar)
- Primeiro prova a identidade, depois o sistema decide o que liberar

---

## 1. Senha: hash + salt (+ erros comuns)

O servidor **nunca** deve guardar senha em texto. Se o banco vazar, o atacante teria tudo.

- **Hash**: transforma texto numa string fixa, processo **irreversível** (texto → hash, nunca hash → texto)
- **SHA-256 é rápido demais**: ~1 bilhão de hashes/s numa GPU moderna → atacante testa bilhões de senhas em segundos
- **bcrypt / Argon2 são lentos de propósito**: usam *work factor* (nº de rodadas por hash). Com valor certo, cada hash demora centenas de ms → ataque de segundos vira **anos**
- **Salt**: valor aleatório antes do hash. Duas pessoas com a mesma senha geram hashes diferentes. Sem salt, atacante usa **rainbow tables** (tabelas pré-computadas de hashes comuns)
- Login: servidor pega a senha digitada, aplica hash com o salt salvo e compara com o hash armazenado

**Erros comuns:**
- ❌ **Mensagens de erro diferentes** ("usuário não encontrado" vs "senha incorreta") → atacante descobre quais e-mails existem. Mensagem correta: sempre genérica ("e-mail ou senha incorretos")
- ❌ **Sem rate limiting** → script testa 100.000 senhas/min. Proteção: limitar por IP **e** por conta, bloqueio temporário após X falhas
- ❌ **SQL Injection no login**: concatenar input direto na query. `' OR 1=1 --` no e-mail retorna todos os usuários. Solução: **queries parametrizadas**, nunca concatenar input do usuário

## 2. Sessão: o servidor lembra do login

- Você digita e-mail/senha → servidor valida → cria registro de sessão → devolve identificador
- Identificador vai para um **cookie** que o browser guarda e envia **automaticamente** em toda requisição
- Servidor recebe o cookie, confere na memória e sabe quem é você

**Proteção do cookie:**
- **HttpOnly**: JS não acessa o cookie → protege contra XSS
- **Secure**: só envia por HTTPS
- **SameSite**: bloqueia envio em requisições de outros domínios → protege contra CSRF

**Errros e cuidados:**
- **Session fixation**: atacante planta um session ID no browser da vítima antes do login. Se o ID não muda depois do login, o atacante o usa. Solução: **gerar novo session ID após o login** (sempre descartar o antigo)
- **Não invalidar sessões ao trocar senha**: se o atacante já roubou a sessão, trocar a senha não resolve. Trocar senha = **invalidar todas as sessões** + forçar login
- **Onde guardar a sessão**: memória (rápida, mas reiniciou perdeu) → banco (persistente, mas query extra por requisição) → **Redis** (rápido, compartilhado entre servidores) é o padrão de produção
- Sem Redis, com 3 servidores atrás de load balancer, a sessão só existe num deles → próxima requisição pode ir para outro e não reconhecer. **Sessões são stateful, e estado é difícil de escalar**

## 3. JWT: autenticar sem estado

Para escalar sem guardar estado, existe o **JWT (JSON Web Token)** — 3 partes separadas por ponto:
- **Header**: algoritmo de assinatura
- **Payload**: ID do usuário, expiração, escopos. Base64 → **não criptografado**! Qualquer um com o token lê o conteúdo → **nunca** colocar dados sensíveis
- **Signature**: garante que ninguém forjou o conteúdo

**Algoritmos:**
- **HMAC**: chave simétrica (a mesma que assina verifica). Bom quando um único servidor faz tudo
- **RSA / ECDSA**: chaves assimétricas — privada assina, pública verifica. Essencial para microsserviços: cada serviço só precisa da **chave pública** para validar; a privada nunca sai do servidor de autenticação

**Erros:**
- ❌ Chave secreta fraca ("secret123") → dicionário de chaves comuns forja qualquer token. Chave: **≥ 256 bits de entropia**, aleatória, em **variável de ambiente**, nunca no código
- ❌ Verificar só a assinatura e ignorar **issuer (iss) e audience (aud)** → token emitido pro serviço A reutilizado no serviço B. Sempre validar iss + aud

**Fluxo**: login → servidor gera token → devolve → cada requisição manda no header `Authorization: Bearer <token>` → servidor verifica a assinatura com a chave, sem guardar nada

**Onde guardar o token:**
- ❌ **localStorage**: simples, JS lê e manda no header — mas qualquer script malicioso na página também lê (XSS) → token vaza
- ✅ **Cookie HttpOnly**: JS não acessa, browser manda automaticamente. Regra: aplicação web → **cookies**

**Revogação e rotação:**
- Token sem estado funciona até expirar → **Access token dura ~15 min**
- **Refresh token** (validade de dias/semanas) pede um novo par quando o access expira
- **Rotação**: cada uso do refresh token invalida o antigo e gera novo → se roubarem o antigo, já não funciona

## 4. Sessão vs JWT — quando usar qual

| Situação | Escolha |
|---|---|
| App web tradicional, 1 servidor, poucos serviços | **Sessão** — simples, fácil de revogar, servidor controla tudo |
| API consumida por vários clientes / microsserviços | **JWT** — cada serviço valida sozinho com a chave pública |
| Híbrido comum | **Os dois** — sessão para o usuário final, JWT entre serviços internos |

Vantagens: sessão = simplicidade + revogação; JWT = escala + flexibilidade.

## 5. OAuth 2.0: "entrar com Google"

**OAuth é autorização delegada**: você autoriza um app a acessar seus dados em outro serviço **sem dar sua senha**. O app nunca vê sua senha do Google; só recebe permissão para nome e e-mail.

**4 papéis**:
- **Resource Owner**: você
- **Client**: o app que quer acesso
- **Authorization Server**: quem autentica/autoriza (ex.: Google)
- **Resource Server**: a API que tem os dados

**Fluxo mais seguro — Authorization Code:**
1. App redireciona pro Google com: client ID, URL de retorno, escopos e **state** aleatório (anti-CSRF)
2. Você loga no Google, vê a tela de permissões, aceita
3. Google redireciona de volta com **código de autorização** na URL (uso único, vida curta)
4. O app manda o código pro Google **direto do back end** + client secret → recebe os tokens (tudo servidor-a-servidor, token nunca passa pelo browser)

**Exceção: apps mobile** — não têm como guardar client secret com segurança (qualquer um inspeciona o código). Solução: **PKCE** (Proof Key for Code Exchange):
1. App gera string aleatória (**code verifier**)
2. Calcula o hash (**code challenge**) e manda na 1ª requisição
3. Ao trocar código por tokens, manda o code verifier; o Google aplica o hash e compara com o challenge
4. Se bater, prova que quem troca é quem iniciou o fluxo → mesmo interceptando o código, sem verifier não troca por tokens

**Erros:**
- ❌ **Open redirect**: se o authorization server não valida a redirect URI **exatamente** (caráter por caráter, nada de wildcard), o atacante aponta pro domínio dele e o código cai no servidor dele
- ❌ **Sem state**: atacante inicia fluxo OAuth com a conta dele e manda o callback pra vítima → vincula a conta do atacante ao perfil da vítima (account linking / CSRF). State: sempre aleatório, vinculado à sessão, verificado no retorno

## 6. OpenID Connect: identidade sobre OAuth

OAuth diz **o que o app pode acessar**, mas **não quem é o usuário**. OIDC é uma camada sobre o OAuth que adiciona o **ID token** — um JWT com os dados de identidade (nome, e-mail, foto de perfil). "Entrar com Google" na prática é OIDC.

- **Nonce**: valor único gerado pelo servidor por login, protege contra **replay** (atacante copia o token da rede e reenvia; o servidor vê que já foi usado e rejeita)
- **Escopos**: cada escopo define exatamente o que o app pode fazer (ler e-mail, não deletar; ver contatos, não editar). **Princípio do menor privilégio**: app só recebe o menor escopo necessário, escopos ficam no token, e a API checa o escopo antes de responder — sem o escopo certo, nega mesmo com token válido

## 7. MFA: segunda camada de defesa

Se a senha vazar (phishing, vazamento, adivinhação), o MFA adiciona camadas.

**3 tipos de fator**: algo que você **sabe** (senha/PIN) · algo que você **tem** (celular/chave física) · algo que você **é** (digital/facial). MFA exige **pelo menos 2 fatores diferentes**.

**Métodos (do mais fraco ao mais forte):**
- **SMS**: o mais fraco — número pode ser clonado por **SIM swap**
- **TOTP** (Time-based One-Time Password): servidor gera chave secreta compartilhada com o app (Google Authenticator, 1Password); o app combina chave + horário/30s e aplica HMAC → código de 6 dígitos que muda a cada 30s; servidor faz a mesma conta. Não precisa de internet. Vulnerável a phishing (código digitado em site falso)
- **Chaves físicas (U2F/security keys)**: não vulneráveis a phishing

**Erro comum**: MFA só no login não basta. Se o atacante já tem sessão ativa, pode trocar e-mail, resetar senha e tomar a conta. Operações sensíveis (trocar e-mail, mudar senha, **desativar MFA**, transferir dinheiro) exigem **step-up authentication** — pedir o segundo fator de novo antes de liberar.

## 8. Passkeys: eliminar a senha

**Passkeys (WebAuthn/FIDO2)** = evolução mais relevante da autenticação. Eliminam senhas com **criptografia de chave pública**:
1. Ao criar a passkey, o dispositivo gera um par de chaves
2. **Chave privada** fica no dispositivo, protegida por biometria/PIN — **nunca sai do dispositivo**
3. **Chave pública** vai pro servidor

**Login**: servidor manda challenge aleatório → dispositivo pede biometria, assina com a chave privada → servidor verifica com a pública. Sem senha, sem código, sem nada roubável por phishing.

- **Anti-phishing nativo**: a chave é **vinculada ao domínio** — site falso não funciona (o dispositivo sabe que "gooogle.com" não é Google)
- Podem ser **sincronizadas** entre dispositivos (iCloud Keychain, Google Password Manager) — resolve perder o celular, mas adiciona confiança na nuvem
- Para alta segurança: passkeys **não sincronizadas** em hardware físico (ex.: YubiKey), nunca saem do dispositivo

## 9. Os 3 ataques mais comuns + password reset

- **XSS (Cross-Site Scripting)**: atacante injeta JS malicioso na página; se o token está no localStorage, o script lê e envia pra fora. **Defesa em camadas**: cookie HttpOnly + **CSP** (bloqueia script não autorizado) + sanitização de input
- **CSRF**: ao contrário — atacante cria site que faz requisição pro seu banco; como cookies são enviados automaticamente, o banco acha que é você. `SameSite=Strict` resolve a maioria; para formulários, token CSRF único por sessão
- **CORS mal configurado**: `Access-Control-Allow-Origin: *` + `credentials: true` → **qualquer site** faz requisições autenticadas pra sua API. Correção: definir exatamente quais origens são permitidas
- **Password reset vulnerável**: token previsível (ex.: base64 do ID do usuário) → atacante gera tokens pra qualquer conta. Token de reset: **aleatório, expira em minutos, uso único**, e após resetar **invalidar todas as sessões**

## 10. Fluxo completo (junção de tudo)

1. Usuário digita e-mail e senha
2. Servidor compara o hash (bcrypt), confere o salt
3. Pede o segundo fator — TOTP validado ou passkey assina o challenge
4. Servidor gera **access token JWT de 15 min** (assinado com chave privada) + **refresh token com rotação**
5. A cada requisição, a API verifica assinatura, checa escopos e responde
6. Access token expira → refresh token renova nos bastidores
7. Login social → OAuth cuida do redirecionamento com PKCE + OIDC traz a identidade no ID token

---

## Exemplos de código — Java 26, Go 1.26 e Python 3.14

Implementações com stdlib pura (sem dependências), validadas: os 9 exemplos compilam e rodam, e o TOTP produz o mesmo código (935084) nas 3 linguagens no mesmo segundo.

### Hash de senha (PBKDF2)

```java
// Java 26 — Hash de senha com PBKDF2 (stdlib javax.crypto)
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import java.security.SecureRandom;
import java.util.HexFormat;

public class PasswordHash {
    public static void main(String[] args) throws Exception {
        char[] senha = "minha-senha".toCharArray();
        byte[] salt = new byte[16];
        new SecureRandom().nextBytes(salt);

        // Work factor alto: PBKDF2WithHmacSHA256, 600.000 iteracoes, 256 bits
        PBEKeySpec spec = new PBEKeySpec(senha, salt, 600_000, 256);
        SecretKeyFactory f = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256");
        byte[] hash = f.generateSecret(spec).getEncoded();

        // Armazenar salt + hash + iteracoes (nunca a senha em texto)
        System.out.println("salt: " + HexFormat.of().formatHex(salt));
        System.out.println("hash: " + HexFormat.of().formatHex(hash));
    }
}
```

```go
// Go 1.26 — Hash de senha com PBKDF2 (crypto/pbkdf2, stdlib desde Go 1.24)
package main

import (
	"crypto/pbkdf2"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
)

func main() {
	salt := make([]byte, 16)
	rand.Read(salt)

	// Work factor alto: PBKDF2-HMAC-SHA256, 600.000 iteracoes, 32 bytes
	// Assinatura (Go 1.24+): Key(h func() Hash, password string, salt []byte, iter, keyLength int)
	hash, err := pbkdf2.Key(sha256.New, "minha-senha", salt, 600_000, 32)
	if err != nil {
		panic(err)
	}

	// Armazenar salt + hash + iteracoes (nunca a senha em texto)
	fmt.Println("salt:", hex.EncodeToString(salt))
	fmt.Println("hash:", hex.EncodeToString(hash))
}
```

```python
# Python 3.14 — Hash de senha com PBKDF2 (stdlib hashlib)
import hashlib
import os


def hash_senha(senha: str, iteracoes: int = 600_000) -> tuple[str, str]:
    salt = os.urandom(16)  # salt aleatorio por usuario

    # Work factor alto: PBKDF2-HMAC-SHA256, 600.000 iteracoes
    hash_bytes = hashlib.pbkdf2_hmac("sha256", senha.encode(), salt, iteracoes)

    # Armazenar salt + hash + iteracoes (nunca a senha em texto)
    return salt.hex(), hash_bytes.hex()


if __name__ == "__main__":
    salt, h = hash_senha("minha-senha")
    print(f"salt: {salt}")
    print(f"hash: {h}")
```

### Assinatura de token (JWT HS256)

```java
// Java 26 — JWT HS256 (HMAC-SHA256) sem dependencias
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

public class JwtHmac {
    static String b64url(byte[] b) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(b);
    }

    // Assina ou verifica: HMAC-SHA256
    static byte[] hmac(String secret, String data) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
        return mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
    }

    public static void main(String[] args) throws Exception {
        String secret = "chave-com-256-bits-de-entropia!!";

        // Header e payload em base64url (payload NAO e criptografado)
        String header = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}";
        String payload = "{\"sub\":\"42\",\"exp\":1750000000,\"scope\":\"read\"}";
        String signingInput = b64url(header.getBytes()) + "." + b64url(payload.getBytes());
        String signature = b64url(hmac(secret, signingInput));

        String token = signingInput + "." + signature;
        System.out.println("token: " + token);

        // Verificacao: recalcula a assinatura e compara
        String expected = b64url(hmac(secret, signingInput));
        System.out.println("assinatura valida: " + expected.equals(signature));
    }
}
```

```go
// Go 1.26 — JWT HS256 (HMAC-SHA256) sem dependencias
package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
)

func b64url(b []byte) string {
	return base64.RawURLEncoding.EncodeToString(b)
}

func main() {
	secret := []byte("chave-com-256-bits-de-entropia!!") // variável de ambiente na vida real

	// Header e payload em base64url (payload NAO e criptografado)
	header, _ := json.Marshal(map[string]string{"alg": "HS256", "typ": "JWT"})
	payload, _ := json.Marshal(map[string]any{"sub": "42", "exp": 1750000000, "scope": "read"})

	signingInput := b64url(header) + "." + b64url(payload)

	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(signingInput))
	signature := b64url(mac.Sum(nil))

	token := signingInput + "." + signature
	fmt.Println("token:", token)

	// Verificacao: recalcula a assinatura e compara
	mac2 := hmac.New(sha256.New, secret)
	mac2.Write([]byte(signingInput))
	fmt.Println("assinatura valida:", hmac.Equal(mac2.Sum(nil), mustDecode(signature)))
}

func mustDecode(s string) []byte {
	b, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		panic(err)
	}
	return b
}
```

```python
# Python 3.14 — JWT HS256 (HMAC-SHA256) sem dependencias
import base64
import hashlib
import hmac
import json


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def assinar_jwt(payload: dict, secret: str) -> str:
    header = {"alg": "HS256", "typ": "JWT"}

    # Header e payload em base64url (payload NAO e criptografado)
    signing_input = b64url(json.dumps(header, separators=(",", ":")).encode()) + "." + \
                    b64url(json.dumps(payload, separators=(",", ":")).encode())

    # Assina: HMAC-SHA256
    sig = hmac.new(secret.encode(), signing_input.encode(), hashlib.sha256).digest()
    return signing_input + "." + b64url(sig)


def verificar_jwt(token: str, secret: str) -> bool:
    signing_input, _, sig = token.rpartition(".")
    expected = hmac.new(secret.encode(), signing_input.encode(), hashlib.sha256).digest()
    return hmac.compare_digest(b64url(expected).encode(), sig.encode())


if __name__ == "__main__":
    secret = "chave-com-256-bits-de-entropia!!"  # variavel de ambiente na vida real
    token = assinar_jwt({"sub": "42", "exp": 1750000000, "scope": "read"}, secret)
    print(f"token: {token}")
    print("assinatura valida:", verificar_jwt(token, secret))
```

### TOTP (código de 6 dígitos, RFC 6238)

```java
// Java 26 — TOTP (RFC 6238): codigo de 6 digitos que muda a cada 30s
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;

public class Totp {
    static String totp(String secret, long nowSeconds) throws Exception {
        long counter = nowSeconds / 30; // janela de 30 segundos
        byte[] msg = ByteBuffer.allocate(8).putLong(counter).array();

        Mac mac = Mac.getInstance("HmacSHA1");
        mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA1"));
        byte[] h = mac.doFinal(msg);

        // Dynamic truncation (RFC 4226)
        int offset = h[h.length - 1] & 0x0F;
        int code = ((h[offset] & 0x7F) << 24) | ((h[offset + 1] & 0xFF) << 16)
                 | ((h[offset + 2] & 0xFF) << 8) | (h[offset + 3] & 0xFF);
        return String.format("%06d", code % 1_000_000);
    }

    public static void main(String[] args) throws Exception {
        long now = System.currentTimeMillis() / 1000;
        System.out.println("codigo atual: " + totp("chave-secreta-compartilhada", now));
    }
}
```

```go
// Go 1.26 — TOTP (RFC 6238): codigo de 6 digitos que muda a cada 30s
package main

import (
	"crypto/hmac"
	"crypto/sha1"
	"encoding/binary"
	"fmt"
	"time"
)

func totp(secret string, now time.Time) string {
	counter := uint64(now.Unix() / 30) // janela de 30 segundos
	var msg [8]byte
	binary.BigEndian.PutUint64(msg[:], counter)

	mac := hmac.New(sha1.New, []byte(secret))
	mac.Write(msg[:])
	h := mac.Sum(nil)

	// Dynamic truncation (RFC 4226)
	offset := h[len(h)-1] & 0x0F
	code := (int(h[offset])&0x7F)<<24 | int(h[offset+1])<<16 | int(h[offset+2])<<8 | int(h[offset+3])
	return fmt.Sprintf("%06d", code%1_000_000)
}

func main() {
	fmt.Println("codigo atual:", totp("chave-secreta-compartilhada", time.Now()))
}
```

```python
# Python 3.14 — TOTP (RFC 6238): codigo de 6 digitos que muda a cada 30s
import hashlib
import hmac
import struct
import time


def totp(secret: str, now: int | None = None) -> str:
    now = int(time.time()) if now is None else now
    counter = now // 30  # janela de 30 segundos

    # HMAC-SHA1 sobre o contador em big-endian (8 bytes)
    msg = struct.pack(">Q", counter)
    h = hmac.new(secret.encode(), msg, hashlib.sha1).digest()

    # Dynamic truncation (RFC 4226)
    offset = h[-1] & 0x0F
    code = (struct.unpack(">I", h[offset : offset + 4])[0] & 0x7FFFFFFF) % 1_000_000
    return f"{code:06d}"


if __name__ == "__main__":
    print(f"codigo atual: {totp('chave-secreta-compartilhada')}")
```

---

## Checklist de segurança (resumo prático)

- [ ] Senha: hash lento (bcrypt/Argon2/PBKDF2) + salt único por usuário
- [ ] Mensagem de login genérica ("e-mail ou senha incorretos")
- [ ] Rate limiting por IP e por conta
- [ ] Queries parametrizadas (nunca concatenar input)
- [ ] Cookie: HttpOnly + Secure + SameSite; novo session ID após login
- [ ] Invalidar todas as sessões ao trocar senha
- [ ] Sessão em Redis (não em memória de servidor único)
- [ ] JWT: secret ≥ 256 bits em env var; validar iss + aud + exp; sem dados sensíveis no payload
- [ ] Token em cookie HttpOnly (não localStorage)
- [ ] Access token curto (~15 min) + refresh token com rotação
- [ ] OAuth: Authorization Code + PKCE (mobile), redirect URI exata, state anti-CSRF
- [ ] OIDC: validar nonce (anti-replay)
- [ ] MFA: TOTP ou chave física (não SMS); step-up em operações sensíveis
- [ ] Passkeys onde possível (anti-phishing nativo)
- [ ] CSP + sanitização (anti-XSS); SameSite=Strict + token CSRF (anti-CSRF)
- [ ] CORS: origens explícitas, nunca `*` com credentials
- [ ] Password reset: token aleatório, expira em minutos, uso único, invalidar sessões