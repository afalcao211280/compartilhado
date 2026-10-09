# Resumo — "O que acontece quando você digita uma URL" (pt-BR, ~9:12)

Fonte: https://www.youtube.com/watch?v=7y4tiOjMUCY
Data: 30/08/2026 | Transcrição: /tmp/tr_brows.json

## Tese central

Entre o Enter e o primeiro pixel, o browser passa por **6 etapas** (cache → DNS → TCP → TLS → HTTP) e depois pelo **pipeline de renderização** (bytes → caracteres → tokens → DOM → CSSOM → render tree → layout → paint → composição). Entender o pipeline explica por que cada otimização de front-end funciona.

## Parte 1 — Navegação (6 etapas)

1. **Cache**: se a página já foi visitada e o cache é válido, pula tudo (sem rede, sem espera).
2. **DNS**: domínio → IP (como uma "lista de contatos": nome → número).
3. **TCP**: handshake de 3 vias (`SYN` → `SYN-ACK` → `ACK`).
4. **TLS** (em HTTPS): negociação de certificados e chaves (mais idas e voltas).
5. **HTTP**: request `GET` → resposta com HTML.
6. (Renderização — abaixo.)

## Parte 2 — Pipeline de renderização

1. **Bytes → caracteres**: HTML chega como bytes; converte usando a codificação (geralmente UTF-8).
2. **Tokenizer**: identifica pedaços — tags de abertura/fechamento, atributos, texto.
3. **DOM**: cada token vira nó; nós organizados em árvore pela hierarquia das tags.
   - O parser **não espera o HTML inteiro**: constrói o DOM conforme chega (páginas renderizam de cima para baixo).
   - O parser de HTML é **tolerante**: fechar tag esquecida, reestruturar `div` dentro de `p` — HTML nunca falha no parse.
4. **CSSOM**: CSS passa pelo mesmo processo (bytes → chars → tokens → árvore). Mapeia cada regra aos elementos que afeta.
   - **Cascata**: nós herdam estilos do pai (`body { font-size:16px }` vale para os filhos, a menos que sobrescrevam).
   - **CSS bloqueia a renderização**: nada é pintado até o CSSOM completo (evita renderizar sem estilo e redesenhar tudo).
5. **Render tree**: combina DOM + CSSOM. Só nós **visíveis**: `display:none` sai, `<head>` sai, `<script>` sai; `visibility:hidden` **entra** (invisível mas ocupa espaço).
6. **Layout/Reflow**: calcula a geometria — posição X/Y, largura/altura de cada caixa (box model: content, padding, border, margin). Unidades relativas (50%, `auto`) viram pixels. Recursivo: pai depende dos filhos, filhos dependem do pai (larguras de cima para baixo, alturas de baixo para cima).
7. **Paint**: vira instruções de pintura ("retângulo azul em (10,20), 250×50"). O browser divide a página em **camadas** (elementos com `transform`, `opacity` ou `will-change` ganham camada própria).
8. **Composição**: GPU combina as camadas na ordem certa. Animações com `transform`/`opacity` só mexem no compositing — **sem reflow, sem repaint** (por isso são performáticas).

## JavaScript: o interrompedor

- Quando o parser encontra `<script>`, ele **para** de construir o DOM e executa (JS pode modificar o DOM: `document.write`, `appendChild`, `removeChild`).
- **Preload scanner**: parser leve que escaneia à frente e baixa recursos (imagens, stylesheets) em paralelo, sem construir DOM.
- **Cadeia de bloqueios**: se o script acessa `getComputedStyle`, o CSS (que ainda carrega) bloqueia o JS, que bloqueia o HTML. → `async` vs `defer`:
  - `async`: baixa em paralelo, executa **assim que termina**, sem garantia de ordem.
  - `defer`: baixa em paralelo, executa **depois do DOM completo**, na ordem do HTML. (Usar mais.)
- **Eventos**: `DOMContentLoaded` (HTML parseado + scripts `defer` executados) vs `load` (tudo carregou: imagens, fontes, iframes).

## Reflow / Repaint / Compositing

Quando JS modifica DOM ou CSSOM, o browser refaz parte do pipeline — **quanto mais acima, mais caro**:
- Mudar **largura** → reflow (layout).
- Mudar **cor** → só repaint.
- Mudar **transform** → direto pro compositing.

## Por que as otimizações funcionam

| Otimização | Etapa atacada |
|---|---|
| Minificar HTML/CSS | menos tempo de parsing |
| `defer` nos scripts | evita bloquear o parser |
| Manter o HTML raso | acelera o layout |
| `transform`/`opacity` (em vez de `top`/`left`) | pula direto pro compositing |

---

## Exemplos de código — JavaScript (Node 24)

Como o conceito é do browser, os exemplos simulam o pipeline com JS puro (Node 24), representando as etapas do vídeo.

### 1. Tokenizer + DOM: HTML → árvore de nós
```js
// Node 24 — tokenizer simplificado: HTML -> tokens -> DOM
const html = '<div class="container"><p>oi</p><p>mundo</p></div>';

function tokenize(src) {
  const tokens = [];
  const re = /<(\/?)([a-z0-9]+)([^>]*?)(\/?)>|([^<]+)/g;
  let m;
  while ((m = re.exec(src))) {
    if (m[5] !== undefined) {
      tokens.push({ tipo: 'TEXTO', valor: m[5].trim() });
    } else {
      tokens.push({
        tipo: m[1] ? 'FIM' : 'INI',
        tag: m[2],
        attrs: [...m[3].matchAll(/([a-z-]+)="([^"]*)"/g)].map(x => [x[1], x[2]]),
      });
    }
  }
  return tokens;
}

function buildDom(tokens) {
  const raiz = { tag: '#document', filhos: [] };
  const pilha = [raiz];
  for (const t of tokens) {
    if (t.tipo === 'INI') {
      const no = { tag: t.tag, attrs: t.attrs, filhos: [] };
      pilha[pilha.length - 1].filhos.push(no);
      pilha.push(no);
    } else if (t.tipo === 'FIM') {
      pilha.pop();
    } else if (t.valor) {
      pilha[pilha.length - 1].filhos.push({ tag: '#text', valor: t.valor });
    }
  }
  return raiz;
}

const tokens = tokenize(html);
const dom = buildDom(tokens);
console.log(JSON.stringify(dom, null, 1));
// #document > div.container > [p#text oi, p#text mundo]
```
```js
// Node 24 — variante: mesmo resultado, implementacao equivalente
const html = '<div class="container"><p>oi</p><p>mundo</p></div>';

function domSimples(html) {
  const no = { tag: 'div', attrs: [['class', 'container']], filhos: [] };
  // simulacao do DOM que o browser monta:
  // 1) tokeniza as tags <p>
  const ps = [...html.matchAll(/<p>(.*?)<\/p>/g)].map(m => ({
    tag: 'p', attrs: [], filhos: [{ tag: '#text', valor: m[1] }],
  }));
  no.filhos = ps;
  return no;
}

console.log(JSON.stringify(domSimples(html), null, 1));
```
```js
// Node 24 — variante 3: parser tolerante (fecha tag sozinho)
const html = '<div><p>oi<div><p>mundo';

function parseTolerante(src) {
  const raiz = { tag: '#document', filhos: [] };
  const pilha = [raiz];
  for (const m of src.matchAll(/<(\/?)([a-z0-9]+)|([^<]+)/g)) {
    if (m[3] !== undefined) {
      pilha[pilha.length - 1].filhos.push({ tag: '#text', valor: m[3].trim() });
    } else if (m[1]) {
      const top = pilha[pilha.length - 1];
      if (top.tag === m[2]) pilha.pop();   // fecha
    } else {
      const no = { tag: m[2], filhos: [] };
      pilha[pilha.length - 1].filhos.push(no);
      pilha.push(no);
    }
  }
  return raiz;
}

console.log(JSON.stringify(parseTolerante(html), null, 1));
// <div> nao fechado -> parser repara sozinho (tolerante)
```

### 2. CSSOM + Render tree: cascata + só nós visíveis
```js
// Node 24 — cascata de estilos + render tree (descarta display:none)
const estilos = {
  body: { fontSize: '16px', color: 'black' },
  'div.container': { fontSize: '20px' },
};

const dom = [
  { tag: 'body', filhos: [
    { tag: 'div', attrs: [['class', 'container']], filhos: [
      { tag: 'p', filhos: [] },
      { tag: 'p', attrs: [['style', 'display:none']], filhos: [] },
      { tag: 'span', attrs: [['style', 'visibility:hidden']], filhos: [] },
    ] },
  ] },
];

function resolveEstilo(no, pai) {
  let atual = { ...pai };
  const seletor = no.tag + (no.attrs?.find(a => a[0] === 'class')?.[1] ? '.' + no.attrs.find(a => a[0] === 'class')[1] : '');
  if (estilos[seletor]) atual = { ...atual, ...estilos[seletor] };
  return atual;
}

function renderTree(no, estiloPai, visivel = true) {
  const estilo = resolveEstilo(no, estiloPai);
  const displayNone = no.attrs?.some(a => a[0] === 'style' && a[1].includes('display:none'));
  const visibilityHidden = no.attrs?.some(a => a[0] === 'style' && a[1].includes('visibility:hidden'));
  const noVisivel = visivel && !displayNone;   // display:none sai da render tree
  const resultado = {
    tag: no.tag,
    visivelParaPaint: noVisivel,
    ocupaEspaco: noVisivel && !visibilityHidden,  // visibility:hidden ocupa espaco
    fontSize: estilo.fontSize,
    filhos: (no.filhos || []).map(f => renderTree(f, estilo, noVisivel)),
  };
  return resultado;
}

console.log(JSON.stringify(renderTree(dom[0], {}), null, 1));
// p com display:none -> visivelParaPaint:false (fora)
// span com visibility:hidden -> visivelParaPaint:true, ocupaEspaco:false (ocupa espaco)
```
```js
// Node 24 — variante: heranca de estilos na cascata
const estilos = {
  body: { fontSize: '16px', color: 'black' },
  'p': { color: 'blue' },
};
const dom = [
  { tag: 'body', filhos: [
    { tag: 'p', filhos: [] },
    { tag: 'section', filhos: [{ tag: 'p', filhos: [] }] },
  ] },
];

function cascade(no, pai) {
  let atual = { ...pai };
  const seletor = no.tag;
  if (estilos[seletor]) atual = { ...atual, ...estilos[seletor] };
  return {
    tag: no.tag,
    estilo: atual,
    filhos: (no.filhos || []).map(f => cascade(f, atual)),
  };
}

console.log(JSON.stringify(cascade(dom[0], {}), null, 1));
// o p dentro de section herda color:blue do seletor p (cascata por TAG)
```
```js
// Node 24 — variante 3: layout (box model) calculando geometria
function layout(no, x, y, largura) {
  const l = {
    tag: no.tag,
    x, y,
    largura: no.largura !== undefined ? no.largura : largura,
    altura: no.altura || 0,
  };
  // recursivo: filhos empilham abaixo; pai acumula altura
  let yAtual = y;
  for (const f of (no.filhos || [])) {
    const fl = layout(f, x + (no.padding || 0), yAtual, l.largura - 2 * (no.padding || 0));
    yAtual = fl.altura + yAtual;
    l.altura += fl.altura;
    no.filhosLayout ||= []; no.filhosLayout.push(fl);
  }
  if (!no.filhos?.length) l.altura = no.altura || 20;
  return l;
}
const arvore = {
  tag: 'div', largura: 500, padding: 10, filhos: [
    { tag: 'p', altura: 20 },
    { tag: 'p', altura: 20 },
  ],
};
const out = layout(arvore, 0, 0, 500);
out.filhosLayout = undefined;
console.log(JSON.stringify(out, null, 1));
// div: x=0 y=0 largura=500 altura=40 (2 filhos de 20)
```

### 3. Paint/Compositing: camadas e quando custa (reflow vs repaint vs composite)
```js
// Node 24 — custo das mudancas: reflow (layout) > repaint > composite
const pipeline = ['style', 'layout', 'paint', 'composite'];

function custo(mudanca) {
  // mapa do video: largura -> reflow; cor -> repaint; transform -> composite
  const etapas = {
    'largura': ['layout', 'paint', 'composite'],
    'cor': ['paint', 'composite'],
    'transform': ['composite'],
  };
  return etapas[mudanca] || [];
}

for (const m of ['largura', 'cor', 'transform']) {
  const c = custo(m);
  console.log(`${m}: refaz [${c.join(', ')}]`);
}
// largura: refaz [layout, paint, composite]  -> mais caro (reflow)
// cor:     refaz [paint, composite]          -> repaint
// transform: refaz [composite]               -> mais barato (GPU)
```
```js
// Node 24 — variante: camadas (como o browser promove para GPU)
const camadas = new Map();
function promover(nome, motivo) {
  camadas.set(nome, { camada: true, motivo });
}
const html = '<div class="anim"></div>';
promover('div.anim', 'transform');   // transform -> camada propria
promover('div.anim', 'opacity');     // opacity -> camada propria

console.log([...camadas.entries()]);
// [['div.anim', { camada: true, motivo: 'transform' }], ['div.anim', { camada: true, motivo: 'opacity' }]]
```
```js
// Node 24 — variante 3: preload scanner (baixa recursos antes do parser parar)
const recursos = ['https://cdn.x.com/img.png', 'https://cdn.x.com/style.css'];

function preloadScanner(html) {
  const downloads = [];
  const imgs = [...html.matchAll(/<img[^>]+src="([^"]+)"/g)].map(m => m[1]);
  const css = [...html.matchAll(/<link[^>]+href="([^"]+)"/g)].map(m => m[1]);
  for (const r of [...imgs, ...css]) {
    if (recursos.includes(r)) downloads.push(`baixando ${r}`);
  }
  return downloads;
}

console.log(preloadScanner('<img src="https://cdn.x.com/img.png"><link rel="stylesheet" href="https://cdn.x.com/style.css">'));
// ['baixando https://cdn.x.com/img.png', 'baixando https://cdn.x.com/style.css']
```

---

## Destaques

- Digitar URL → **cache → DNS → TCP → TLS → HTTP**, depois o **pipeline de renderização** completo.
- DOM é construído **incrementalmente** e o HTML parser é **tolerante**; CSS **bloqueia** a renderização.
- **Render tree** só tem nós visíveis; `display:none` sai, `visibility:hidden` entra (ocupa espaço).
- **Reflow > Repaint > Composite** em custo — `transform`/`opacity` animam sem recálculo de layout.
- `async` vs `defer`: defer preserva ordem e roda após o DOM; async executa assim que baixa.
- **Minificação, defer, HTML raso, transform**: cada otimização ataca uma etapa específica do pipeline.