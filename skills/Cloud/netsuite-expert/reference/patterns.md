# NetSuite Expert — Padrões de Código (SuiteScript 2.1)

## Índice

1. User Event Script — Padrão de Produção
2. Map/Reduce Script — Processamento em Massa
3. RESTlet — Endpoint Customizado
4. Scheduled Script
5. Client Script
6. SuiteQL — Queries Avançadas via N/query
7. N/search — Com Paginação
8. SuiteTalk REST API — Integração Externa (Node.js + OAuth 2.0)
9. SDF — Custom Record Type XML
10. Workflow Action Script
- Anti-patterns (com exemplos de código)

## 1. User Event Script — Padrão de Produção

```javascript
/**
 * @NApiVersion 2.1
 * @NScriptType UserEventScript
 * @NModuleScope SameAccount
 */
define(['N/record', 'N/log', 'N/runtime', 'N/email'], (record, log, runtime, email) => {

  // Parâmetros configuráveis no Script Deployment
  const getParams = () => {
    const script = runtime.getCurrentScript();
    return {
      approverEmployeeId: script.getParameter({ name: 'custscript_approver_emp_id' }),
      notificationEmail: script.getParameter({ name: 'custscript_notif_email' }),
    };
  };

  /**
   * Antes de salvar: validações e enriquecimento de dados
   */
  const beforeSubmit = (context) => {
    // Ignorar execuções não-interativas (CSV import, web services)
    if (runtime.executionContext === runtime.ContextType.CSV_IMPORT) return;
    if (runtime.executionContext === runtime.ContextType.WEBSERVICES) return;

    // Só executar em CREATE e EDIT
    const { UserEventType } = context;
    if (![UserEventType.CREATE, UserEventType.EDIT].includes(context.type)) return;

    try {
      const rec = context.newRecord;
      const total = rec.getValue({ fieldId: 'total' });

      // Validação de negócio
      if (total > 50000) {
        const params = getParams();
        if (!params.approverEmployeeId) {
          throw new Error('Pedidos acima de R$50.000 exigem aprovador configurado no deployment.');
        }
        rec.setValue({ fieldId: 'custbody_requires_approval', value: true });
        rec.setValue({ fieldId: 'custbody_approver', value: params.approverEmployeeId });
      }
    } catch (e) {
      log.error({
        title: `beforeSubmit error — ${e.name}`,
        details: JSON.stringify({ message: e.message, stack: e.stack }),
      });
      throw e; // re-throw: impede o save e mostra erro ao usuário
    }
  };

  /**
   * Após salvar: ações que não precisam bloquear o save do usuário
   */
  const afterSubmit = (context) => {
    // Evitar loop: não executar em contexto de web service interno
    if (context.type === context.UserEventType.DELETE) return;

    try {
      const rec = context.newRecord;
      const requiresApproval = rec.getValue({ fieldId: 'custbody_requires_approval' });

      if (requiresApproval && context.type === context.UserEventType.CREATE) {
        const params = getParams();
        email.send({
          author: runtime.getCurrentUser().id,
          recipients: [params.notificationEmail],
          subject: `Aprovação necessária — Pedido ${rec.getValue({ fieldId: 'tranid' })}`,
          body: `Pedido ${rec.id} criado e aguardando aprovação.`,
        });
        log.audit({
          title: 'Email de aprovação enviado',
          details: `Record ID: ${rec.id}`,
        });
      }
    } catch (e) {
      // afterSubmit: logar mas NÃO re-throw (o save já aconteceu)
      log.error({
        title: `afterSubmit error — ${e.name}`,
        details: JSON.stringify({ message: e.message, id: context.newRecord.id }),
      });
    }
  };

  const beforeLoad = (context) => {
    // Customizar view apenas para usuários normais (não admin)
    if (runtime.getCurrentUser().roleId === 'administrator') return;
    if (context.type !== context.UserEventType.VIEW) return;

    try {
      context.form.addButton({
        id: 'custpage_btn_approve',
        label: 'Aprovar Pedido',
        functionName: 'approveOrder', // função no Client Script associado
      });
    } catch (e) {
      log.error({ title: 'beforeLoad error', details: e.message });
    }
  };

  return { beforeLoad, beforeSubmit, afterSubmit };
});
```

---

## 2. Map/Reduce Script — Processamento em Massa

```javascript
/**
 * @NApiVersion 2.1
 * @NScriptType MapReduceScript
 * @NModuleScope SameAccount
 */
define(['N/search', 'N/record', 'N/log', 'N/runtime'], (search, record, log, runtime) => {

  /**
   * ESTÁGIO 1: retorna os dados a processar.
   * Pode retornar: Search | Query | File | Object | Array | Iterator
   */
  const getInputData = (inputContext) => {
    log.audit({ title: 'getInputData iniciado', details: new Date().toISOString() });

    // Retornar uma search: Map/Reduce itera automaticamente com yield
    return search.create({
      type: search.Type.SALES_ORDER,
      filters: [
        ['status', search.Operator.ANYOF, 'SalesOrd:B'],         // Pending Fulfillment
        'AND',
        ['custbody_processed', search.Operator.IS, false],
      ],
      columns: [
        search.createColumn({ name: 'tranid' }),
        search.createColumn({ name: 'entity' }),
        search.createColumn({ name: 'total' }),
        search.createColumn({ name: 'custbody_external_ref' }),
      ],
    });
  };

  /**
   * ESTÁGIO 2: processa cada resultado individualmente.
   * key = ID interno do registro; value = objeto do resultado
   */
  const map = (mapContext) => {
    const data = JSON.parse(mapContext.value);
    const recordId = data.id;
    const tranid = data.values.tranid;

    try {
      // Transformar ou enriquecer dados
      const processedValue = {
        id: recordId,
        tranid,
        externalRef: data.values.custbody_external_ref,
      };

      // Emitir para o reduce agrupado por chave (ex: por entity)
      const entityId = data.values.entity?.value;
      mapContext.write({ key: entityId || 'no_entity', value: JSON.stringify(processedValue) });

    } catch (e) {
      log.error({
        title: `map error — record ${recordId}`,
        details: JSON.stringify({ message: e.message }),
      });
      // Não re-throw no map: outros registros continuam sendo processados
    }
  };

  /**
   * ESTÁGIO 3: agrega todos os valores emitidos para a mesma chave.
   */
  const reduce = (reduceContext) => {
    const entityId = reduceContext.key;
    const orders = reduceContext.values.map(v => JSON.parse(v));

    log.audit({
      title: `Processando entity ${entityId}`,
      details: `${orders.length} pedidos`,
    });

    orders.forEach(order => {
      try {
        // Atualizar registro: mais eficiente que record.load + setValue + save
        record.submitFields({
          type: record.Type.SALES_ORDER,
          id: order.id,
          values: {
            custbody_processed: true,
            custbody_process_date: new Date(),
          },
          options: { enableSourcing: false, ignoreMandatoryFields: true },
        });
        log.audit({ title: 'Pedido processado', details: `ID: ${order.id}, tranid: ${order.tranid}` });
      } catch (e) {
        log.error({
          title: `reduce error — record ${order.id}`,
          details: e.message,
        });
        reduceContext.write({ key: order.id, value: `ERROR: ${e.message}` });
      }
    });
  };

  /**
   * ESTÁGIO 4: sumário — reportar resultados, enviar notificações.
   * Sempre executa, mesmo se map/reduce tiveram erros.
   */
  const summarize = (summaryContext) => {
    const script = runtime.getCurrentScript();
    let errCount = 0;

    // Log de erros do map
    summaryContext.mapSummary.errors.iterator().each((key, error) => {
      log.error({ title: `Map error — key ${key}`, details: error });
      errCount++;
      return true;
    });

    // Log de erros do reduce
    summaryContext.reduceSummary.errors.iterator().each((key, error) => {
      log.error({ title: `Reduce error — key ${key}`, details: error });
      errCount++;
      return true;
    });

    log.audit({
      title: 'Map/Reduce concluído',
      details: JSON.stringify({
        erros: errCount,
        usageRemaining: script.getRemainingUsage(),
        inputStageCompleted: summaryContext.inputSummary.dateCreated,
      }),
    });
  };

  return { getInputData, map, reduce, summarize };
});
```

---

## 3. RESTlet — Endpoint Customizado

```javascript
/**
 * @NApiVersion 2.1
 * @NScriptType Restlet
 * @NModuleScope SameAccount
 */
define(['N/record', 'N/search', 'N/query', 'N/log', 'N/runtime'], (record, search, query, log, runtime) => {

  /**
   * GET: busca dados
   * URL: https://<account>.restlets.api.netsuite.com/app/site/hosting/restlet.nl
   *      ?script=<scriptId>&deploy=<deployId>&recordId=123
   */
  const get = (requestParams) => {
    log.debug({ title: 'RESTlet GET', details: JSON.stringify(requestParams) });

    try {
      const { recordId, type } = requestParams;

      if (recordId) {
        const rec = record.load({
          type: type || record.Type.SALES_ORDER,
          id: Number(recordId),
          isDynamic: false,
        });
        return {
          success: true,
          data: {
            id: rec.id,
            tranid: rec.getValue({ fieldId: 'tranid' }),
            status: rec.getValue({ fieldId: 'status' }),
            total: rec.getValue({ fieldId: 'total' }),
          },
        };
      }

      // SuiteQL para listagem
      const results = query.runSuiteQL({
        query: `
          SELECT id, tranid, status, total
          FROM transaction
          WHERE type = 'SalesOrd'
            AND status IN ('SalesOrd:B', 'SalesOrd:D')
          ORDER BY lastmodifieddate DESC
        `,
      });

      return { success: true, data: results.asMappedResults() };

    } catch (e) {
      log.error({ title: 'RESTlet GET error', details: e.message });
      return { success: false, error: e.message, code: e.name };
    }
  };

  /**
   * POST: cria ou processa dados
   */
  const post = (requestBody) => {
    log.debug({ title: 'RESTlet POST', details: JSON.stringify(requestBody) });

    try {
      const { orderData } = requestBody;

      const rec = record.create({
        type: record.Type.SALES_ORDER,
        isDynamic: true,
      });

      rec.setValue({ fieldId: 'entity', value: orderData.customerId });
      rec.setValue({ fieldId: 'trandate', value: new Date(orderData.date) });
      rec.setValue({ fieldId: 'custbody_external_ref', value: orderData.externalId });

      // Linhas do pedido
      orderData.items?.forEach(item => {
        rec.selectNewLine({ sublistId: 'item' });
        rec.setCurrentSublistValue({ sublistId: 'item', fieldId: 'item', value: item.itemId });
        rec.setCurrentSublistValue({ sublistId: 'item', fieldId: 'quantity', value: item.qty });
        rec.setCurrentSublistValue({ sublistId: 'item', fieldId: 'rate', value: item.rate });
        rec.commitLine({ sublistId: 'item' });
      });

      const id = rec.save({ enableSourcing: true, ignoreMandatoryFields: false });
      log.audit({ title: 'Sales Order criado via RESTlet', details: `ID: ${id}` });

      return { success: true, id, message: 'Sales Order criado com sucesso.' };

    } catch (e) {
      log.error({ title: 'RESTlet POST error', details: `${e.name}: ${e.message}` });
      return { success: false, error: e.message, code: e.name };
    }
  };

  /**
   * PUT: atualiza registro existente
   */
  const put = (requestBody) => {
    try {
      const { id, fields } = requestBody;
      record.submitFields({
        type: record.Type.SALES_ORDER,
        id: Number(id),
        values: fields,
        options: { enableSourcing: false, ignoreMandatoryFields: true },
      });
      return { success: true, id };
    } catch (e) {
      log.error({ title: 'RESTlet PUT error', details: e.message });
      return { success: false, error: e.message };
    }
  };

  /**
   * DELETE: remove registro
   */
  const doDelete = (requestParams) => {
    try {
      const { id, type } = requestParams;
      record.delete({ type: type || record.Type.SALES_ORDER, id: Number(id) });
      return { success: true };
    } catch (e) {
      log.error({ title: 'RESTlet DELETE error', details: e.message });
      return { success: false, error: e.message };
    }
  };

  return { get, post, put, delete: doDelete };
});
```

---

## 4. Scheduled Script

```javascript
/**
 * @NApiVersion 2.1
 * @NScriptType ScheduledScript
 * @NModuleScope SameAccount
 */
define(['N/search', 'N/record', 'N/log', 'N/runtime', 'N/task'], (search, record, log, runtime, task) => {

  const execute = (scriptContext) => {
    const script = runtime.getCurrentScript();
    const daysBack = script.getParameter({ name: 'custscript_days_back' }) || 7;

    log.audit({ title: 'Scheduled script iniciado', details: `Janela: ${daysBack} dias` });

    try {
      // Para volumes pequenos (< 500 registros): processa inline
      // Para volumes grandes: delega para Map/Reduce
      const countSearch = search.create({
        type: search.Type.SALES_ORDER,
        filters: [
          ['trandate', search.Operator.ONORAFTER, `${daysBack} days ago`],
          'AND', ['status', search.Operator.ANYOF, 'SalesOrd:A'],
        ],
      });

      const count = countSearch.runPaged({ pageSize: 1 }).count;
      log.audit({ title: 'Registros encontrados', details: count });

      if (count > 500) {
        // Delegar para Map/Reduce
        const mrTask = task.create({
          taskType: task.TaskType.MAP_REDUCE,
          scriptId: 'customscript_mr_process_orders',
          deploymentId: 'customdeploy_mr_process_orders',
          params: { custscript_mr_days_back: daysBack },
        });
        const taskId = mrTask.submit();
        log.audit({ title: 'Map/Reduce agendado', details: `Task ID: ${taskId}` });
        return;
      }

      // Processar inline (volume pequeno)
      let processed = 0;
      countSearch.run().each(result => {
        // Verificar governance antes de continuar
        if (script.getRemainingUsage() < 500) {
          log.error({ title: 'Governance insuficiente', details: `Processados: ${processed}` });
          return false; // interrompe o each
        }

        try {
          record.submitFields({
            type: record.Type.SALES_ORDER,
            id: result.id,
            values: { custbody_scheduled_processed: true },
            options: { enableSourcing: false, ignoreMandatoryFields: true },
          });
          processed++;
        } catch (e) {
          log.error({ title: `Erro no registro ${result.id}`, details: e.message });
        }
        return true;
      });

      log.audit({ title: 'Script concluído', details: `Processados: ${processed}` });

    } catch (e) {
      log.error({ title: 'Scheduled script error', details: `${e.name}: ${e.message}` });
      throw e;
    }
  };

  return { execute };
});
```

---

## 5. Client Script

```javascript
/**
 * @NApiVersion 2.1
 * @NScriptType ClientScript
 * @NModuleScope SameAccount
 */
define(['N/currentRecord', 'N/log', 'N/url', 'N/http'], (currentRecord, log, url, http) => {

  /**
   * Executado quando a página carrega (equivalente ao DOMContentLoaded)
   */
  const pageInit = (scriptContext) => {
    if (scriptContext.mode !== 'create') return;
    const rec = scriptContext.currentRecord;
    // Definir valor padrão em novos registros
    rec.setValue({ fieldId: 'custbody_source', value: 'WEB', ignoreFieldChange: true });
  };

  /**
   * Executado quando qualquer campo muda de valor
   */
  const fieldChanged = (scriptContext) => {
    const { fieldId, currentRecord: rec } = scriptContext;

    if (fieldId === 'entity') {
      const customerId = rec.getValue({ fieldId: 'entity' });
      if (!customerId) return;

      // Buscar limite de crédito via RESTlet (async não bloqueante)
      const restletUrl = url.resolveScript({
        scriptId: 'customscript_rl_credit_check',
        deploymentId: 'customdeploy_rl_credit_check',
        returnExternalUrl: false,
      });

      http.get({ url: `${restletUrl}&customerId=${customerId}` })
        .then(response => {
          const data = JSON.parse(response.body);
          rec.setValue({ fieldId: 'custbody_credit_limit', value: data.limit });
          log.debug({ title: 'Limite de crédito carregado', details: data.limit });
        })
        .catch(e => log.error({ title: 'Erro ao buscar crédito', details: e.message }));
    }
  };

  /**
   * Executado antes do usuário submeter o formulário
   * Retornar false bloqueia o save
   */
  const saveRecord = (scriptContext) => {
    const rec = scriptContext.currentRecord;
    const total = rec.getValue({ fieldId: 'total' });
    const creditLimit = rec.getValue({ fieldId: 'custbody_credit_limit' });

    if (creditLimit && total > creditLimit) {
      alert(`Pedido (${total}) excede limite de crédito (${creditLimit}). Obtenha aprovação.`);
      return false; // bloqueia o save
    }
    return true;
  };

  /**
   * Executado após um sublist ser alterado
   */
  const sublistChanged = (scriptContext) => {
    if (scriptContext.sublistId !== 'item') return;
    // Recalcular totais customizados ao alterar linhas
    log.debug({ title: 'Sublist alterada', details: scriptContext.sublistId });
  };

  return { pageInit, fieldChanged, saveRecord, sublistChanged };
});
```

---

## 6. SuiteQL — Queries Avançadas via N/query

```javascript
/**
 * @NApiVersion 2.1
 * @NScriptType Restlet
 * @NModuleScope SameAccount
 */
define(['N/query', 'N/log'], (query, log) => {

  const get = (params) => {
    try {
      // Query básica com parâmetros bindados (evita SQL injection)
      const salesOrders = query.runSuiteQL({
        query: `
          SELECT
            t.id,
            t.tranid,
            t.trandate,
            t.status,
            t.total,
            BUILTIN.DF(t.entity) AS customer_name,
            BUILTIN.DF(t.status)  AS status_label
          FROM transaction t
          WHERE t.type = 'SalesOrd'
            AND t.trandate >= ?
            AND t.total > ?
          ORDER BY t.trandate DESC
        `,
        params: [params.startDate, params.minTotal || 0],
      });

      // Paginação manual com SuiteQL
      const pageSize = 100;
      const offset = (params.page - 1) * pageSize;

      const pagedResults = query.runSuiteQL({
        query: `
          SELECT id, tranid, total FROM transaction
          WHERE type = 'SalesOrd'
          ORDER BY id
          LIMIT ${pageSize} OFFSET ${offset}
        `,
      });

      // Joins e subqueries
      const orderLines = query.runSuiteQL({
        query: `
          SELECT
            tl.transaction,
            tl.id          AS line_id,
            tl.item,
            BUILTIN.DF(tl.item)  AS item_name,
            tl.quantity,
            tl.rate,
            tl.amount
          FROM transactionLine tl
          INNER JOIN transaction t ON t.id = tl.transaction
          WHERE t.type = 'SalesOrd'
            AND t.status = 'SalesOrd:B'
            AND NVL(tl.mainline, 'F') = 'F'  -- excluir linha principal (header)
            AND NVL(tl.taxline, 'F') = 'F'   -- excluir linha de imposto
        `,
      });

      return {
        orders: salesOrders.asMappedResults(),
        lines: orderLines.asMappedResults(),
      };

    } catch (e) {
      log.error({ title: 'SuiteQL error', details: e.message });
      return { error: e.message };
    }
  };

  return { get };
});
```

---

## 7. N/search — Com Paginação

```javascript
/**
 * N/search com paginação para grandes volumes
 */
define(['N/search', 'N/log'], (search, log) => {

  const processLargeSearch = () => {
    const salesSearch = search.create({
      type: search.Type.SALES_ORDER,
      filters: [
        ['status', search.Operator.ANYOF, 'SalesOrd:B', 'SalesOrd:D'],
        'AND',
        ['trandate', search.Operator.ONORAFTER, '01/01/2025'],
      ],
      columns: [
        search.createColumn({ name: 'tranid' }),
        search.createColumn({ name: 'entity', label: 'Customer' }),
        search.createColumn({ name: 'total' }),
        search.createColumn({ name: 'trandate', sort: search.Sort.DESC }),
        // Campos de join via column join
        search.createColumn({ name: 'entityid', join: 'customer' }),
      ],
    });

    // runPaged: processa em blocos de até 1000 resultados
    const pagedData = salesSearch.runPaged({ pageSize: 200 });

    log.audit({ title: 'Total de resultados', details: pagedData.count });

    pagedData.pageRanges.forEach(pageRange => {
      const page = pagedData.fetch({ index: pageRange.index });

      page.data.forEach(result => {
        const id = result.id;
        const tranid = result.getValue({ name: 'tranid' });
        const customerName = result.getValue({ name: 'entityid', join: 'customer' });
        log.debug({ title: 'Pedido', details: `${tranid} — ${customerName}` });
      });
    });
  };

  // lookupFields: buscar campos de um registro sem record.load (econômico)
  const lookupExample = () => {
    const fields = search.lookupFields({
      type: search.Type.CUSTOMER,
      id: 12345,
      columns: ['entityid', 'email', 'phone', 'custentity_tier'],
    });
    log.debug({ title: 'Customer fields', details: JSON.stringify(fields) });
    return fields;
  };

  return { processLargeSearch, lookupExample };
});
```

---

## 8. SuiteTalk REST API — Integração Externa (Node.js + OAuth 2.0)

```javascript
// integração-netsuite/netsuite-client.js
// Autenticação OAuth 2.0 Client Credentials (M2M) + chamadas REST

const axios = require('axios');
const jwt = require('jsonwebtoken');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

class NetSuiteClient {
  constructor({ accountId, clientId, privateKeyPath }) {
    this.accountId = accountId.replace('-', '_').toLowerCase();
    this.clientId = clientId;
    this.privateKey = fs.readFileSync(privateKeyPath, 'utf8');
    this.accessToken = null;
    this.tokenExpiry = 0;
    this.baseUrl = `https://${this.accountId}.suitetalk.api.netsuite.com/services/rest`;
  }

  /**
   * Gerar JWT para client credentials flow
   */
  _generateClientAssertion() {
    const now = Math.floor(Date.now() / 1000);
    const payload = {
      iss: this.clientId,
      scope: ['rest_webservices', 'restlets'],
      iat: now,
      exp: now + 3600,
      aud: `https://${this.accountId}.suitetalk.api.netsuite.com/services/rest/auth/oauth2/v1/token`,
    };
    return jwt.sign(payload, this.privateKey, { algorithm: 'RS256', keyid: uuidv4() });
  }

  /**
   * Obter access token (com cache)
   */
  async getAccessToken() {
    if (this.accessToken && Date.now() < this.tokenExpiry) return this.accessToken;

    const response = await axios.post(
      `https://${this.accountId}.suitetalk.api.netsuite.com/services/rest/auth/oauth2/v1/token`,
      new URLSearchParams({
        grant_type: 'client_credentials',
        client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
        client_assertion: this._generateClientAssertion(),
      }),
      { headers: { 'Content-Type': 'application/x-www-form-urlencoded' } }
    );

    this.accessToken = response.data.access_token;
    this.tokenExpiry = Date.now() + (response.data.expires_in - 60) * 1000; // 60s buffer
    return this.accessToken;
  }

  /**
   * Executar query SuiteQL
   */
  async runSuiteQL(query, { limit = 100, offset = 0 } = {}) {
    const token = await this.getAccessToken();
    const response = await axios.post(
      `${this.baseUrl}/query/v1/suiteql?limit=${limit}&offset=${offset}`,
      { q: query },
      {
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
          Prefer: 'transient',
        },
      }
    );
    return response.data; // { items: [...], totalResults, hasMore, offset }
  }

  /**
   * CRUD de registro via REST API
   */
  async createRecord(recordType, data) {
    const token = await this.getAccessToken();
    const response = await axios.post(
      `${this.baseUrl}/record/v1/${recordType}`,
      data,
      {
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      }
    );
    // Location header contém a URL do novo registro
    const location = response.headers.location;
    const id = location.split('/').pop();
    return { id, location };
  }

  async getRecord(recordType, id, { expandSubResources = false } = {}) {
    const token = await this.getAccessToken();
    const params = expandSubResources ? '?expandSubResources=true' : '';
    const response = await axios.get(
      `${this.baseUrl}/record/v1/${recordType}/${id}${params}`,
      { headers: { Authorization: `Bearer ${token}` } }
    );
    return response.data;
  }

  async patchRecord(recordType, id, data) {
    const token = await this.getAccessToken();
    await axios.patch(
      `${this.baseUrl}/record/v1/${recordType}/${id}`,
      data,
      {
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      }
    );
  }
}

// Uso:
// const ns = new NetSuiteClient({
//   accountId: process.env.NS_ACCOUNT_ID,
//   clientId: process.env.NS_CLIENT_ID,
//   privateKeyPath: process.env.NS_PRIVATE_KEY_PATH,
// });
//
// const orders = await ns.runSuiteQL(
//   "SELECT id, tranid, status FROM transaction WHERE type = 'SalesOrd' LIMIT 50"
// );

module.exports = NetSuiteClient;
```

---

## 9. SDF — Custom Record Type XML

```xml
<!-- Objects/customrecord_integration_log.xml -->
<customrecordtype scriptid="customrecord_integration_log">
  <allowattachments>F</allowattachments>
  <allowinlinedetaching>F</allowinlinedetaching>
  <allowquickadd>F</allowquickadd>
  <enabledle>F</enabledle>
  <enablekeywords>F</enablekeywords>
  <enableoptimisticlocking>T</enableoptimisticlocking>
  <enablesystemnotes>T</enablesystemnotes>
  <iconbuiltin>T</iconbuiltin>
  <includeinsearchmenu>T</includeinsearchmenu>
  <includename>T</includename>
  <recordname>Integration Log</recordname>
  <customrecordcustomfields>

    <customrecordcustomfield scriptid="custrecord_log_status">
      <accesslevel>2</accesslevel>
      <displaytype>NORMAL</displaytype>
      <fieldtype>LIST</fieldtype>
      <label>Status</label>
      <selectrecordtype>[scriptid=customlist_integration_status]</selectrecordtype>
      <searchlevel>2</searchlevel>
      <storevalue>T</storevalue>
    </customrecordcustomfield>

    <customrecordcustomfield scriptid="custrecord_log_source">
      <accesslevel>2</accesslevel>
      <displaytype>NORMAL</displaytype>
      <fieldtype>TEXT</fieldtype>
      <label>Fonte</label>
      <maxlength>100</maxlength>
      <searchlevel>2</searchlevel>
      <storevalue>T</storevalue>
    </customrecordcustomfield>

    <customrecordcustomfield scriptid="custrecord_log_payload">
      <accesslevel>2</accesslevel>
      <displaytype>NORMAL</displaytype>
      <fieldtype>LONGTEXT</fieldtype>
      <label>Payload</label>
      <searchlevel>1</searchlevel>
      <storevalue>T</storevalue>
    </customrecordcustomfield>

    <customrecordcustomfield scriptid="custrecord_log_ref_id">
      <accesslevel>2</accesslevel>
      <displaytype>NORMAL</displaytype>
      <fieldtype>TEXT</fieldtype>
      <label>Referência Externa</label>
      <maxlength>255</maxlength>
      <searchlevel>2</searchlevel>
      <storevalue>T</storevalue>
    </customrecordcustomfield>

  </customrecordcustomfields>
</customrecordtype>
```

---

## 10. Workflow Action Script

```javascript
/**
 * @NApiVersion 2.1
 * @NScriptType WorkflowActionScript
 * @NModuleScope SameAccount
 */
define(['N/record', 'N/log', 'N/email', 'N/runtime'], (record, log, email, runtime) => {

  /**
   * Executado quando o SuiteFlow invoca esta ação customizada
   */
  const onAction = (scriptContext) => {
    const { newRecord, oldRecord, workflowId } = scriptContext;

    log.debug({
      title: 'Workflow Action executado',
      details: `workflowId: ${workflowId}, record: ${newRecord.id}`,
    });

    try {
      const status = newRecord.getValue({ fieldId: 'custbody_approval_status' });

      if (status === 'APPROVED') {
        // Transformar Sales Order em Invoice automaticamente
        const invoice = record.transform({
          fromType: record.Type.SALES_ORDER,
          fromId: newRecord.id,
          toType: record.Type.INVOICE,
          isDynamic: false,
          defaultValues: { custbody_auto_generated: true },
        });

        const invoiceId = invoice.save({ enableSourcing: true });
        log.audit({
          title: 'Invoice gerada pelo workflow',
          details: `SO: ${newRecord.id} → Invoice: ${invoiceId}`,
        });

        // Retornar valor para o workflow usar em condições subsequentes
        return invoiceId;
      }

    } catch (e) {
      log.error({ title: 'WorkflowAction error', details: e.message });
      throw e;
    }
  };

  return { onAction };
});
```

---

## Anti-patterns

### ❌ `record.load` em loop iterando resultados de search
**Problema:** Carregar registro completo para cada resultado de uma busca quando só precisa de alguns campos.
**Por quê evitar:** `record.load` custa 10 unidades de governance. Em 100 registros = 1.000u só de load, mais o processamento. User Events estouram em 100 registros, Scheduled em 1.000. Em Map/Reduce funciona, mas é desnecessariamente lento.
**Solução:**
```javascript
// ❌ NUNCA
search.create({ type: 'salesorder', filters: [...] }).run().each(result => {
  const rec = record.load({ type: 'salesorder', id: result.id }); // 10u por registro!
  const val = rec.getValue({ fieldId: 'custbody_flag' });
  return true;
});

// ✅ Colunas adicionais na search (1 busca total, sem governance por linha)
search.create({
  type: 'salesorder',
  filters: [...],
  columns: [
    'tranid',
    'custbody_flag',  // campo direto na coluna
    search.createColumn({ name: 'entityid', join: 'customer' }), // campo de join
  ]
}).run().each(result => {
  const val = result.getValue({ name: 'custbody_flag' }); // sem load!
  return true;
});

// ✅ Ou record.submitFields para atualizar sem load completo
record.submitFields({
  type: 'salesorder',
  id: result.id,
  values: { custbody_flag: true },
  options: { enableSourcing: false }
});
```

---

### ❌ `record.save` em `afterSubmit` sem verificar contexto — loop infinito
**Problema:** Fazer `record.load` + `record.save` dentro de um `afterSubmit` sem checar se já está num contexto de re-execução.
**Por quê evitar:** `afterSubmit` dispara após qualquer save. Se o script faz `save` novamente, dispara `afterSubmit` de novo → loop infinito → centenas de registros criados ou erros em cascata até estourar governance.
**Solução:**
```javascript
// ❌ LOOP INFINITO
const afterSubmit = (context) => {
  const rec = record.load({ type: 'salesorder', id: context.newRecord.id });
  rec.setValue({ fieldId: 'custbody_processed', value: true });
  rec.save(); // ← dispara afterSubmit novamente!
};

// ✅ Use record.submitFields em vez de load + save
const afterSubmit = (context) => {
  // Verificar se já processado para evitar re-execução
  if (context.newRecord.getValue({ fieldId: 'custbody_processed' })) return;

  record.submitFields({
    type: context.newRecord.type,
    id: context.newRecord.id,
    values: { custbody_processed: true },
    options: { enableSourcing: false, ignoreMandatoryFields: true }
  });
  // submitFields em afterSubmit: ainda dispara afterSubmit, mas a verificação acima bloqueia
};
```

---

### ❌ IDs de campos e registros hardcoded
**Problema:** Usar IDs numéricos internos literais no código (ex: `entity: 12345`, `location: 3`).
**Por quê evitar:** IDs internos mudam entre ambientes (Sandbox ≠ Production). Um script que funciona em sandbox quebra em produção com valores errados. Dificulta manutenção e torna o código não-portável.
**Solução:**
```javascript
// ❌ NUNCA
rec.setValue({ fieldId: 'entity', value: 12345 });
rec.setValue({ fieldId: 'location', value: 3 });

// ✅ Parâmetros de script configuráveis por deployment
const script = runtime.getCurrentScript();
const defaultCustomer = script.getParameter({ name: 'custscript_default_customer_id' });
const defaultLocation = script.getParameter({ name: 'custscript_default_location_id' });

rec.setValue({ fieldId: 'entity', value: defaultCustomer });
rec.setValue({ fieldId: 'location', value: defaultLocation });
// → Configure os valores diferentes em cada deployment (Sandbox vs Production)
```

---

### ❌ `search.run().each()` sem controle de governance em scripts síncronos
**Problema:** Usar `run().each()` em User Event ou Suitelet sem verificar governance restante, processando todos os resultados de uma vez.
**Por quê evitar:** `each()` não para automaticamente ao atingir o limite de governance. O script é interrompido abruptamente no meio do processamento, causando estado inconsistente.
**Solução:**
```javascript
// ❌ Sem controle de governance
mySearch.run().each(result => {
  record.submitFields({ ... }); // pode estoura governance no meio
  return true;
});

// ✅ Verificar governance em cada iteração
const script = runtime.getCurrentScript();
mySearch.run().each(result => {
  if (script.getRemainingUsage() < 200) { // margem de segurança
    log.error({ title: 'Governance insuficiente — interrompendo', details: result.id });
    return false; // para o each
  }
  record.submitFields({ ... });
  return true;
});
```

---

### ❌ NLAuth ou user/password em integrações externas
**Problema:** Usar NLAuth (email+password+accountId no header) ou credenciais de usuário humano para autenticar chamadas de sistema.
**Por quê evitar:** NLAuth está descontinuado e bloqueado por default em contas criadas após 2020. Usar credenciais humanas em integrações cria dependência de pessoa, risco de segurança quando o funcionário sai, e falha quando a senha expira.
**Solução:**
```
// ✅ Para novas integrações: OAuth 2.0 Client Credentials (M2M)
Setup > Integration > Manage Integrations
  → Criar Integration Record com "Client Credentials (M2M) Grant"
Setup > Integration > Manage Authentication > OAuth 2.0 Client Credentials (M2M) Setup
  → Mapear Integration + Role de serviço + certificado público

// ✅ Legado tolerado: TBA (Token-Based Authentication / OAuth 1.0)
Setup > My Account > Access Tokens > New Access Token
  → Role de serviço com permissões mínimas (não Administrator)
```

---

### ❌ Lógica pesada em Client Scripts
**Problema:** Colocar queries, cálculos complexos ou chamadas HTTP síncronas em `fieldChanged` ou `saveRecord`.
**Por quê evitar:** Client Scripts executam no browser do usuário. Operações lentas bloqueiam a UI, criam experiência ruim e têm limite de 1.000 unidades de governance (a contagem inclui chamadas N/http).
**Solução:**
```javascript
// ❌ Chamada síncrona bloqueante no fieldChanged
const fieldChanged = (context) => {
  if (context.fieldId !== 'entity') return;
  // Faz chamada HTTP síncrona — congela o browser
  const result = https.get({ url: '...' }); // N/https não existe em Client Script!
};

// ✅ Operação assíncrona via Promise (N/http, não N/https)
const fieldChanged = (context) => {
  if (context.fieldId !== 'entity') return;
  const customerId = context.currentRecord.getValue({ fieldId: 'entity' });

  http.get({ url: `/app/site/hosting/restlet.nl?script=xxx&customerId=${customerId}` })
    .then(response => {
      context.currentRecord.setValue({ fieldId: 'custbody_credit', value: response.data.limit });
    })
    .catch(e => log.error({ title: 'Erro', details: e.message }));
    // Promise retorna imediatamente — UI não congela
};
```

---

### ❌ Usar `@NApiVersion 2.0` com módulos compartilhados em 2.1
**Problema:** Criar um módulo auxiliar com `@NApiVersion 2.0` e `require()` dentro de um script 2.1 que usa `define()`.
**Por quê evitar:** SuiteScript 2.0 usa `require()` (CommonJS-like), 2.1 usa `define()` (AMD). Misturar versões causa erros de carregamento de módulo em runtime que são difíceis de debugar.
**Solução:**
```javascript
// ❌ Módulo helper em 2.0 (usa require)
// helper.js com @NApiVersion 2.0
define(['N/log'], log => {
  function doSomething() { require(['N/record'], record => { ... }); } // ERRADO
  return { doSomething };
});

// ✅ Todos os módulos em 2.1 com define consistente
/**
 * @NApiVersion 2.1
 * @NModuleScope SameAccount
 */
define(['N/record', 'N/log'], (record, log) => {
  const doSomething = (id) => {
    return record.load({ type: 'salesorder', id });
  };
  return { doSomething };
});
// Importar no script principal:
// define(['N/record', './lib/helper'], (record, helper) => { ... });
```
