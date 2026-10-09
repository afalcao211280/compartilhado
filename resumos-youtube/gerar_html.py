#!/usr/bin/env python3
"""Gera HTML de resumo a partir do MD validado (blocos de codigo identicos, grid 3 colunas)."""
import re
import sys
from html import escape

# ---------------- lexer de highlighting (funciona em texto PURO, nao em HTML) ----
def hl(code, lang):
    """Coloriza codigo fonte (texto puro) -> HTML com spans. Nunca corrompe strings."""
    KEYWORDS = {
        "py": set("def return if else elif for while in import from class with as try except raise lambda not and or is None True False pass break continue yield global nonlocal match case print".split()),
        "go": set("package import func var const type struct interface map chan go defer return if else for range switch case default break continue select fallthrough goto nil true false make new len cap append string int int32 int64 uint uint32 uint64 float32 float64 bool byte rune error any".split()),
        "java": set("public private protected static final class interface enum record sealed permits extends implements new return if else for while do switch case default break continue try catch finally throw throws void int double float long short byte boolean char var import package this super null true false instanceof abstract native synchronized transient volatile strictfp assert List ArrayList Map HashMap Set HashSet StringBuilder Optional Stream Collectors Math System Integer Long Double Object Collection".split()),
        "rust": set("fn let mut const static impl trait enum struct match if else for while loop return pub use mod crate self super where as ref move borrow dyn in break continue type option result some none main println format vec string".split()),
        "js": set("const let var function return if else for while of in new class extends import from export default try catch finally throw typeof instanceof switch case break continue null undefined true false this async await yield delete void do".split()),
    }
    kw = KEYWORDS.get(lang, set())
    out = []
    i = 0
    n = len(code)
    # estados
    while i < n:
        ch = code[i]
        # comentario de linha
        if (lang == "py" and code.startswith("#", i)) or (lang in ("go", "java", "rust") and code.startswith("//", i)):
            j = code.find("\n", i)
            if j == -1: j = n
            out.append(f'<span class="c">{escape(code[i:j])}</span>')
            i = j
            continue
        # string
        if ch in ('"', "'"):
            quote = ch
            j = i + 1
            while j < n:
                if code[j] == "\\":
                    j += 2; continue
                if code[j] == quote:
                    j += 1; break
                j += 1
            out.append(f'<span class="s">{escape(code[i:j])}</span>')
            i = j
            continue
        # palavra (keyword/tipo)
        if ch.isalpha() or ch == "_":
            j = i
            while j < n and (code[j].isalnum() or code[j] == "_"):
                j += 1
            word = code[i:j]
            if word in kw:
                out.append(f'<span class="k">{escape(word)}</span>')
            else:
                out.append(escape(word))
            i = j
            continue
        out.append(escape(ch))
        i += 1
    return "".join(out)

def md_to_html(txt):
    """Converte um trecho MD (sem blocos de codigo) para HTML simples."""
    lines = txt.split("\n")
    outl = []
    for ln in lines:
        if ln.startswith("### "):
            outl.append(f"<h3>{escape(ln[4:])}</h3>")
        elif ln.startswith("## "):
            outl.append(f"<h2>{escape(ln[3:])}</h2>")
        elif ln.startswith("# "):
            outl.append(f"<h1>{escape(ln[2:])}</h1>")
        elif ln.strip() == "":
            outl.append("")
        elif ln.strip().startswith("- "):
            outl.append(f"<li>{escape(ln.strip()[2:])}</li>")
        else:
            outl.append(f"<p>{escape(ln)}</p>")
    # agrupa <li> em <ul>
    res = []
    i = 0
    while i < len(outl):
        if outl[i].startswith("<li>"):
            buf = ["<ul style='padding-left:1.3rem'>"]
            while i < len(outl) and outl[i].startswith("<li>"):
                buf.append(outl[i]); i += 1
            buf.append("</ul>")
            res.append("\n".join(buf))
        else:
            res.append(outl[i]); i += 1
    return "\n".join(res)

def main():
    md_path, title, src_url, duration, out_path = sys.argv[1:6]
    md = open(md_path, encoding="utf-8").read()

    # tokens do MD
    tokens = []
    last = 0
    for m in re.finditer(r"```(python|java|go|rust|js|bash|yaml|dockerfile)\n(.*?)```", md, re.S):
        if m.start() > last:
            tokens.append(("text", md[last:m.start()]))
        lang = {"python": "py"}.get(m.group(1), m.group(1))
        tokens.append(("code", lang, m.group(2).rstrip("\n")))
        last = m.end()
    if last < len(md):
        tokens.append(("text", md[last:]))

    css = """
  :root { --bg:#0d1117; --bg2:#161b22; --fg:#e6edf3; --muted:#8b949e;
    --accent:#58a6ff; --accent2:#f0883e; --code-bg:#0a0e14; --border:#30363d; }
  * { box-sizing: border-box; }
  body { margin:0; background:var(--bg); color:var(--fg);
    font-family:system-ui,-apple-system,'Segoe UI',Roboto,sans-serif; line-height:1.6; }
  .wrap { max-width:100%; padding:2rem 2.5rem; margin:0 auto; }
  h1 { font-size:1.7rem; color:var(--accent); }
  h2 { font-size:1.25rem; color:var(--accent); margin-top:2rem;
    border-bottom:1px solid var(--border); padding-bottom:.3rem; }
  h3 { font-size:1.05rem; color:var(--accent2); }
  a { color:var(--accent); }
  .meta { color:var(--muted); font-size:.9rem; }
  .combo { background:var(--bg2); border:1px solid var(--border);
    border-radius:8px; padding:1rem 1.25rem; margin:1rem 0; }
  .code2col { display:grid; grid-template-columns:1fr 1fr 1fr; gap:1rem; margin:1rem 0; }
  @media (max-width:1100px){ .code2col{ grid-template-columns:1fr 1fr; } }
  @media (max-width:900px){ .code2col{ grid-template-columns:1fr; } }
  .src { background:var(--code-bg); border:1px solid var(--border);
    border-radius:8px; padding:.9rem 1rem; overflow-x:auto;
    font-family:'JetBrains Mono','Fira Code',Consolas,monospace;
    font-size:.82rem; line-height:1.5; margin:0; }
  .k { color:#ff7b72; } .t { color:#79c0ff; } .s { color:#a5d6ff; }
  .c { color:#8b949e; font-style:italic; }
  footer { margin-top:3rem; padding-top:1rem; border-top:1px solid var(--border);
    color:var(--muted); font-size:.85rem; }
"""
    out = [f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{escape(title)}</title>
<style>{css}</style>
</head>
<body>
<div class="wrap">
  <h1>{escape(title)}</h1>
  <p class="meta">Fonte: <a href="{escape(src_url)}">{escape(src_url)}</a> · pt-BR · {escape(duration)} · 30/08/2026</p>
"""]

    code_tokens = [(l, c) for tok in tokens if tok[0] == "code" for l, c in [tok[1:]]]
    ci = 0
    for tok in tokens:
        if tok[0] == "text":
            out.append(md_to_html(tok[1]))
        else:
            trio = code_tokens[ci:ci+3]
            ci += 3
            pres = [f'<pre class="src">{hl(c, l)}</pre>' for l, c in trio]
            out.append('<div class="code2col">' + "\n".join(pres) + '</div>')

    out.append(f"""
  <footer>
    Resumo: 30/08/2026. Fonte: <a href="{escape(src_url)}">{escape(title)}</a> ({escape(duration)}).
    Código validado por execução real (mesmos blocos do MD). Linguagens: Java 26, Go 1.26, Python 3.14, Node 24.
  </footer>
</div>
</body>
</html>""")

    html_out = "\n".join(out)
    open(out_path, "w", encoding="utf-8").write(html_out)
    print(f"OK {out_path} ({len(html_out)} chars, {len(code_tokens)} blocos de codigo)")

if __name__ == "__main__":
    main()