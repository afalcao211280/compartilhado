# Resumo — "Idempotência em Pagamentos" (pt-BR, ~9:18)

Fonte: https://www.youtube.com/watch?v=RdCrN69IKGQ
Data: 30/08/2026 | Transcrição: /tmp/tr_pag.json

## Tese central

> Você clica em pagar uma vez, o celular manda a requisição, a resposta se perde e o app tenta de novo. Se o backend processar as duas tentativas, **R$ 500 viram R$ 1.000 cobrados**. O mecanismo que evita essa cobrança duplicada chama-se **idempotência**: repetir a mesma operação deixa o sistema com o mesmo efeito de negócio da primeira execução.

## O problema: retries são inevitáveis

- Um **timeout** só diz que o cliente não recebeu resposta a tempo. A cobrança pode ter falhado antes de chegar ao servidor, pode estar em andamento, ou pode ter sido aprovada com a resposta perdida.
- O app **não consegue diferenciar** esses casos olhando o relógio → ele tenta de novo.
- Retries fazem parte de sistemas distribuídos (conexões caem, processos reiniciam). **Filas também podem entregar a mesma mensagem duas vezes.**
- Repetir a entrega pode repetir a cobrança → é exatamente quando a repetição é necessária que o sistema precisa garantir que o **efeito não se repita**.

## Idempotência na prática

Quando uma operação é idempotente, **três tentativas com a mesma identidade representam uma única cobrança**:
- Os detalhes técnicos não precisam ser idênticos (uma tentativa pode responder 201, outra devolve a resposta salva — o **saldo e o número de cobranças** continuam iguais).

### Quem carrega o identificador

- **GET** e **DELETE** já têm semântica idempotente (ler não cria efeito; deletar repetido continua removendo). Mas produtos financeiros criam recursos com **POST** — e o POST ganha idempotência quando o contrato inclui uma **identidade estável para a intenção**: a **idempotency key**.
- O **cliente** conhece a intenção: cria um **identificador único** antes de iniciar as tentativas e manda **a mesma chave** em todas. Se gerasse uma chave nova por tentativa, o servidor veria três operações.
- **Duas ações intencionais = duas chaves**: duas transferências de R$ 100 para a mesma conta são válidas. Deduplicar pelo conteúdo apagaria uma operação legítima.

## O armazenamento (compartilhado e atômico)

O backend guarda a chave em **armazenamento compartilhado por todas as instâncias** (senão um retry que cai em outra instância passaria batido). A linha de idempotência contém:
- **Chave** (idempotency key), escopada à conta autenticada — evita que a chave de um cliente bloqueie outro;
- **Request hash** — conteúdo relevante da requisição; detecta a mesma chave reutilizada com outro valor/destinatário;
- **Status** — processando ou concluído;
- **Resposta salva** — devolve o mesmo pagamento sem reexecutar a regra de negócio.

Regras:
- Chave e hash iguais + operação concluída → devolve o **resultado salvo**.
- Chave igual + conteúdo mudou → **rejeita** (aquela identidade pertence a outra intenção).
- Primeira tentativa ainda rodando → espera um pouco ou informa que continua processando.

### A brecha: check-then-act

Comparar e depois inserir em duas etapas soltas deixa brecha: duas requisições consultam ao mesmo tempo, descobrem que a chave não existe e **começam duas cobranças**. A disputa pela chave precisa ser **atômica**:

- **Chave primária**: o banco escolhe uma vencedora. Se o `INSERT` criou a linha, aquela requisição "ganhou" o direito de processar; se nenhuma linha foi criada, outra tentativa já registrou a intenção — consulte o estado existente.
- **Transação + lock**: quando o efeito financeiro mora no mesmo banco, o lançamento e a mudança para `completed` confirmam **na mesma transação**. O banco não deixa uma chave concluída sem lançamento, nem lançamento com a chave aberta.

## Transação ≠ idempotência

- **Transação**: impede que a transferência fique pela metade.
- **Idempotência**: impede que a transferência inteira aconteça duas vezes.
- Produtos financeiros precisam **das duas** no mesmo fluxo.

## Webhooks: a duplicação vem de fora

Provedores e filas podem entregar o mesmo evento mais de uma vez (o receptor processa, mas a confirmação se perde; o provedor vê pendente e reentrega). O consumidor também precisa ser idempotente:

- **Inbox persistente**: guarda a combinação provedor+evento. O primeiro evento cria o registro e aplica a mudança; entregas seguintes encontram o registro, **não aplicam outro crédito** e respondem sucesso para encerrar o retry.
- Importante em baixa de boleto, liquidação de cartão, recarga de carteira, conciliação.

## Cruzando fronteiras: o caso mais difícil

Quando a operação cruza mais de um sistema e o processo cai no meio: o processador aprovou a cobrança, mas a API caiu antes de salvar a resposta local. O registro `processing` sozinho **não prova** se o efeito externo aconteceu.

- A mesma identidade precisa **atravessar a fronteira** sempre que o serviço seguinte aceitar uma chave idempotente (backend envia `pagamento 842`, processador responde com a cobrança que já aprovou).
- Se o serviço externo não oferece proteção, guarde uma **referência estável** para consultar e reconciliar antes de tentar criar outro efeito.
- **Outbox** publica o trabalho nascido numa transação local; **inbox** ajuda o próximo serviço a consumir mensagens repetidas. Cada fronteira mantém a identidade da operação mesmo com entrega "pelo menos uma vez".

## Identidades de negócio reais

| Produto | Identidade | Protege |
|---|---|---|
| Carteira digital | `saque_id` | mesmo pedido de saque não debita duas vezes |
| Boleto | `emissao_id` | devolve o título já criado, não gera outro documento |
| Empréstimo | `credito_id` | liga o contrato ao único crédito que entra na conta |
| Corretora | `client_order_id` | recupera a ordem já enviada à mesa de execução (cancelar/substituir = nova intenção, nova identidade) |

O **tempo de retenção** da chave depende do produto: apagar cedo demais deixa um retry tardio repetir o efeito; guardar para sempre custa caro e complica a operação. A janela precisa cobrir o tempo real de retry, processamento, webhooks e conciliação.

## Testes que valem a pena

- Desabilitar o botão melhora UX, mas **não protege o backend** (o usuário abre duas abas, a biblioteca repete a chamada, um worker reinicia após o efeito).
- A garantia mora **perto da regra de negócio e do armazenamento**.
- Teste útil: **cortar a resposta depois do efeito e antes da confirmação**; disparar duas requisições ao mesmo tempo; duplicar o webhook; reiniciar o worker no ponto crítico.
- Em produção: monitore taxa de chaves repetidas, conflitos de payload, operações presas em `processing`, reconciliações pendentes.

## Conclusão

> Sistemas confiáveis assumem que a tentativa vai acontecer de novo e dão uma **identidade estável** para o efeito que só pode acontecer uma vez.

## Exemplo de código — idempotency key com insert atômico (Python 3.14)

```python
# Python 3.14 — chave primaria decide a "vencedora" (race-free)
class Pagamentos:
    def __init__(self):
        self.tabela = {}          # chave -> {hash, status, resposta}
        self.saida = []           # efeitos de negocio aplicados

    def cobrar(self, idem_key, valor, destinatario):
        request_hash = f"{valor}-{destinatario}"   # conteudo relevante
        if idem_key in self.tabela:
            reg = self.tabela[idem_key]
            if reg["hash"] != request_hash:
                return "REJEITADO: chave reutilizada com outro conteudo"
            return reg["resposta"]                 # devolve salvo, sem reexecutar
        # INSERT atomico (na vida real: UNIQUE + catch de conflito)
        self.tabela[idem_key] = {"hash": request_hash,
                                 "status": "completed",
                                 "resposta": "cobranca aprovada"}
        self.saida.append(valor)                  # efeito unico
        return "cobranca aprovada"

p = Pagamentos()
chave = "9e1c-42"                                 # mesma chave em todos os retries
print(p.cobrar(chave, 500, "loja"))      # 1a tentativa: processa
print(p.cobrar(chave, 500, "loja"))      # retry: devolve salvo, SEM debitar 2x
print(p.cobrar(chave, 999, "outra"))     # mesma chave, conteudo mudou -> rejeita
print("total cobrado:", sum(p.saida))    # 500, nao 1000
# cobranca aprovada
# cobranca aprovada
# REJEITADO: chave reutilizada com outro conteudo
# total cobrado: 500
```

O ponto central: com a chave como **identidade atômica**, o retry não reexecuta a regra de negócio — devolve a resposta salva — e a chave reutilizada com conteúdo diferente é rejeitada. No banco real é a **chave primária/UNIQUE** que garante essa atomicidade contra requisições simultâneas.