# NetSuite Expert — Stack e Referência Técnica

## Índice

- Versões SuiteScript
- Governance — Custos por Operação (Referência Completa)
- Módulos SuiteScript — Referência Completa
- REST API (SuiteTalk REST) — URL Patterns
- Autenticação — Setup Completo (OAuth 2.0 M2M, TBA)
- Estrutura de Projeto SDF
- Convenções de Nomenclatura (Script IDs)
- Logging — Níveis e Boas Práticas
- SuiteFlow — Conceitos Chave

## Versões SuiteScript

| Versão | Status | Características |
|--------|--------|----------------|
| SuiteScript 1.0 | **Descontinuado** | API global, sem módulos, legado |
| SuiteScript 2.0 | Mantido | AMD `define`, módulos N/, ES5 |
| SuiteScript **2.1** | **✅ Atual — usar sempre** | 2.0 + ES2019+ (arrow functions, `const`/`let`, `async/await`, desestruturação, template literals, `Promise`) |

> **Regra**: todo script novo usa `@NApiVersion 2.1`. Scripts 2.0 são mantidos, não criados.

---

## Governance — Custos por Operação (Referência Completa)

### Limites por Script Type

| Script Type | Limite Total | Comportamento ao Estourar |
|-------------|-------------|--------------------------|
| Client Script | 1.000 u | Script interrompido, erro no browser |
| User Event | 1.000 u | Operação falha, rollback da transação |
| RESTlet | 5.000 u | HTTP 429 retornado ao caller |
| Suitelet | 1.000 u | Página de erro ao usuário |
| Scheduled Script | 10.000 u | Script interrompido (pode re-agendar) |
| Map/Reduce | 10.000 u/estágio | Auto-yield entre chaves/estágios |
| Mass Update | 1.000 u/registro | Registro pulado com erro |
| Workflow Action | 1.000 u | Ação falha no workflow |

### Custo por Operação (aproximado)

| Operação | Custo (unidades) |
|----------|-----------------|
| `record.load()` | 10 |
| `record.save()` | 20 |
| `record.create()` + `.save()` | 20 |
| `record.delete()` | 20 |
| `record.copy()` | 10 |
| `record.transform()` | 10 |
| `search.create().run()` | 5 |
| Cada 1.000 resultados de search | 1 |
| `query.runSuiteQL()` | 10 |
| `https.get()` / `.post()` | 10 |
| `file.load()` | 10 |
| `email.send()` | 10 |

> **Exemplo perigoso**: 500 registros × (`record.load` 10u + `record.save` 20u) = 15.000u
> → estoura qualquer script síncrono. **Use Map/Reduce**.

---

## Módulos SuiteScript — Referência Completa

### Módulos Essenciais

| Módulo | Import string | Principais métodos |
|--------|--------------|-------------------|
| N/record | `'N/record'` | `load`, `create`, `copy`, `delete`, `transform`, `save`, `getValue`, `setValue`, `getSublistValue`, `setSublistValue` |
| N/search | `'N/search'` | `create`, `load`, `run`, `runPaged`, `lookupFields` |
| N/query | `'N/query'` | `runSuiteQL`, `create`, `load` |
| N/currentRecord | `'N/currentRecord'` | `get`, `getValue`, `setValue` (client-side) |
| N/log | `'N/log'` | `debug`, `audit`, `error`, `emergency` |
| N/runtime | `'N/runtime'` | `getCurrentScript`, `getCurrentUser`, `getSession`, `executionContext` |
| N/https | `'N/https'` | `get`, `post`, `put`, `delete`, `request` (server-side) |
| N/http | `'N/http'` | `get`, `post`, `put`, `delete` (client-side) |
| N/url | `'N/url'` | `resolveRecord`, `resolveScript`, `format` |
| N/file | `'N/file'` | `load`, `create`, `delete`, `findUsage` |
| N/email | `'N/email'` | `send`, `sendBulk` |
| N/format | `'N/format'` | `format`, `parse` com `Type.*` |
| N/redirect | `'N/redirect'` | `toRecord`, `toSuitelet`, `toURL` |
| N/render | `'N/render'` | `create`, `transaction`, `bom`, `pickingTicket` |
| N/ui/serverWidget | `'N/ui/serverWidget'` | `createForm`, `createList`, `createAssistant` |
| N/cache | `'N/cache'` | `getCache` → `.get`, `.put`, `.remove` |
| N/sftp | `'N/sftp'` | `createConnection`, `download`, `upload` |
| N/crypto/certificate | `'N/crypto/certificate'` | `createSigner`, `sign` |
| N/task | `'N/task'` | `create` (para agendar Map/Reduce de outro script) |

### Tipos de Record Nativos (N/record.Type)

```javascript
record.Type.SALES_ORDER          // 'salesorder'
record.Type.PURCHASE_ORDER       // 'purchaseorder'
record.Type.INVOICE              // 'invoice'
record.Type.VENDOR_BILL          // 'vendorbill'
record.Type.CUSTOMER             // 'customer'
record.Type.VENDOR               // 'vendor'
record.Type.EMPLOYEE             // 'employee'
record.Type.ITEM_FULFILLMENT     // 'itemfulfillment'
record.Type.ITEM_RECEIPT         // 'itemreceipt'
record.Type.CREDIT_MEMO          // 'creditmemo'
record.Type.CASH_SALE            // 'cashsale'
record.Type.ESTIMATE             // 'estimate'
record.Type.OPPORTUNITY          // 'opportunity'
record.Type.CONTACT              // 'contact'
record.Type.JOURNAL_ENTRY        // 'journalentry'
// Custom records: string direta 'customrecord_xxx'
```

---

## REST API (SuiteTalk REST) — URL Patterns

### Base URL

```
https://<account_id>.suitetalk.api.netsuite.com/services/rest/
```

> `account_id`: encontrado em Setup > Company > Company Information > Account ID.
> Formato: `1234567` ou `1234567_SB1` (sandbox). Hifens viram underscores na URL.

### Endpoints de Record

```http
# Listar todos os tipos disponíveis
GET /record/v1/

# Criar registro
POST /record/v1/{recordType}
Content-Type: application/json

# Ler registro
GET /record/v1/{recordType}/{id}

# Atualizar (patch parcial)
PATCH /record/v1/{recordType}/{id}
Content-Type: application/json

# Substituir (put total)
PUT /record/v1/{recordType}/{id}
Content-Type: application/json

# Deletar
DELETE /record/v1/{recordType}/{id}

# Listar com filtro
GET /record/v1/{recordType}?q=status IS "Pending Fulfillment"

# Sublist
GET /record/v1/{recordType}/{id}/item
POST /record/v1/{recordType}/{id}/item
PATCH /record/v1/{recordType}/{id}/item/{lineId}

# Transformar record (ex: Sales Order → Invoice)
POST /record/v1/{recordType}/{id}/!transform/{targetType}
```

### Endpoint SuiteQL

```http
POST /query/v1/suiteql
Content-Type: application/json

{
  "q": "SELECT id, tranid, entity, status FROM transaction WHERE type = 'SalesOrd' LIMIT 100"
}

# Com paginação
POST /query/v1/suiteql?limit=100&offset=0
```

### Endpoint de Metadata

```http
# Metadata de um record type
GET /record/v1/{recordType}/metadata-catalog

# Metadata de um campo específico
GET /record/v1/{recordType}/metadata-catalog/{fieldId}
```

---

## Autenticação — Setup Completo

### OAuth 2.0 Client Credentials (M2M) — Recomendado

**Setup no NetSuite:**
```
1. Habilitar: Setup > Company > Enable Features > SuiteCloud > OAuth 2.0
2. Criar Integration Record: Setup > Integration > Manage Integrations
   - Marcar: "Client Credentials (Machine to Machine) Grant"
   - Anotar Client ID
3. Criar par de chaves:
   openssl genrsa -out private.pem 2048
   openssl rsa -in private.pem -pubout -out public.pem
4. Mapear certificado: Setup > Integration > Manage Authentication >
   OAuth 2.0 Client Credentials (M2M) Setup
   - Entity: usuário/role de serviço
   - Application: Integration Record criada
   - Upload: public.pem
5. Token endpoint:
   POST https://<account_id>.suitetalk.api.netsuite.com/services/rest/auth/oauth2/v1/token
```

**Campos necessários:**
- `client_id`: do Integration Record
- `grant_type`: `client_credentials`
- `client_assertion_type`: `urn:ietf:params:oauth:client-assertion-type:jwt-bearer`
- `client_assertion`: JWT assinado com chave privada

### TBA (Token-Based Authentication / OAuth 1.0) — Legado

```
Setup > Integration > Manage Integrations > (criar com TBA habilitado)
Setup > My Account > Access Tokens > New Access Token
   - Application: Integration Record
   - Role: role de serviço com permissões mínimas
```

Credenciais: Account ID, Consumer Key, Consumer Secret, Token ID, Token Secret.

---

## Estrutura de Projeto SDF

```
my-sdf-project/
├── src/
│   ├── FileCabinet/
│   │   └── SuiteScripts/
│   │       └── <feature>/
│   │           ├── ue_feature.js       # User Event Script
│   │           ├── mr_feature.js       # Map/Reduce Script
│   │           ├── rl_feature.js       # RESTlet
│   │           └── lib/
│   │               └── helper.js       # módulo auxiliar
│   └── Objects/
│       ├── customrecord_feature.xml    # Custom Record Type
│       ├── custscript_ue_feature.xml   # Script Object
│       └── customrole_sdf_dev.xml      # Custom Role
├── manifest.xml
├── deploy.xml                          # objetos a implantar
└── suitecloud.config.js
```

### Comandos SuiteCloud CLI

```bash
# Instalar CLI
npm install --global @oracle/suitecloud-cli

# Criar projeto
suitecloud project:create -i

# Criar arquivo de script
suitecloud object:import --scriptid custscript_xxx --type script

# Validar projeto
suitecloud project:validate

# Deploy para conta
suitecloud project:deploy

# Deploy com override
suitecloud project:deploy --account sandbox123
```

---

## Convenções de Nomenclatura (Script IDs)

| Tipo | Prefixo | Exemplo |
|------|---------|---------|
| Custom Script | `custscript_` | `custscript_ue_validate_order` |
| Custom Field (body) | `custbody_` | `custbody_approval_status` |
| Custom Field (entity) | `custentity_` | `custentity_tier` |
| Custom Field (item) | `custitem_` | `custitem_lead_time_days` |
| Custom Field (column/line) | `custcol_` | `custcol_po_line_ref` |
| Custom Record | `customrecord_` | `customrecord_integration_log` |
| Custom List | `customlist_` | `customlist_approval_levels` |
| Custom Role | `customrole_` | `customrole_integration_service` |
| Custom Segment | `cseg_` | `cseg_department` |
| Deployment | `customdeploy_` | `customdeploy_ue_validate_order` |

---

## Logging — Níveis e Boas Práticas

| Nível | Quando usar | Visível em |
|-------|-------------|-----------|
| `log.debug` | Desenvolvimento e diagnóstico | Script Log (filtrado por usuário) |
| `log.audit` | Eventos de negócio (record criado, enviado, etc.) | Script Log (sempre) |
| `log.error` | Erros tratados, falhas de integração | Script Log + alertas |
| `log.emergency` | Erros críticos que param o processo | Script Log + notifica administrador |

> **Produção**: use apenas `audit` e `error`. `debug` gera volume excessivo e pode ser
> desabilitado pelo NetSuite em contas com alto volume.

Consultar logs: Setup > Scripting > Script Execution Log (ou no Script Deployment record).

---

## SuiteFlow — Conceitos Chave

| Conceito | Descrição |
|----------|-----------|
| Workflow | Container de estados, ações e transições |
| State | Estado do registro dentro do workflow |
| Transition | Condição de mudança entre estados |
| Action | O que acontece (campo set, email, custom action script) |
| Trigger | Quando o workflow executa (Create, Edit, View, Scheduled, web services) |
| Initiation | Before User Submit / After User Submit / Scheduled |
| Release | Liberar versão do workflow (Draft → Testing → Released) |

Workflow Action Script: usado quando a ação nativa do SuiteFlow não cobre o caso de uso.
Entry point: `onAction(context)` — acessa `context.newRecord` e `context.oldRecord`.
