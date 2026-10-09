#!/usr/bin/env python3
"""Validador de skills EVEO.

Checa: frontmatter vs schema (jsonschema), orçamento de linhas do SKILL.md (<=500),
presença de AGENTS.md/CHANGELOG.md, índice em reference/*.md grandes (>300 linhas),
resolução de `requires`/cross-references contra o corpus, e drift do security-baseline
inline vs a fonte compartilhada.

Uso:
  python validate_skill.py <alvo> [corpus_root]

  <alvo>       diretório de uma skill (tem SKILL.md) OU raiz com várias skills.
  corpus_root  (opcional) raiz para resolver `requires`. Default: raiz do alvo.

Saída: linhas ERROR/WARN e código de saída 1 se houver erro.
"""
import sys
import re
import json
import pathlib

import yaml
from jsonschema import Draft7Validator

HERE = pathlib.Path(__file__).resolve().parent
SCHEMA_PATH = HERE.parent / "_shared" / "governance" / "schema.json"
SOURCE_BASELINE = HERE.parent / "_shared" / "security" / "baseline.md"
MAX_LINES = 500
REF_TOC_THRESHOLD = 300

SCHEMA = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
VALIDATOR = Draft7Validator(SCHEMA)

FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.S)


def parse_frontmatter(text):
    m = FRONTMATTER_RE.match(text)
    if not m:
        return None, "sem frontmatter YAML (--- ... ---)"
    try:
        return yaml.safe_load(m.group(1)), None
    except yaml.YAMLError as e:
        return None, f"YAML inválido: {e}"


def find_skill_dirs(root):
    return sorted({p.parent for p in root.rglob("SKILL.md")})


def collect_names(root):
    names = set()
    for sk in root.rglob("SKILL.md"):
        fm, _ = parse_frontmatter(sk.read_text(encoding="utf-8"))
        if fm and isinstance(fm, dict) and fm.get("name"):
            names.add(fm["name"])
    return names


def validate_skill(skill_dir, known_names):
    errors, warnings = [], []
    sk = skill_dir / "SKILL.md"
    if not sk.exists():
        return [f"{skill_dir}: SKILL.md ausente"], []

    text = sk.read_text(encoding="utf-8")
    fm, err = parse_frontmatter(text)
    if err:
        errors.append(f"{sk}: {err}")
    else:
        for e in sorted(VALIDATOR.iter_errors(fm), key=lambda x: x.path):
            loc = "/".join(str(p) for p in e.path) or "(raiz)"
            errors.append(f"{sk}: schema [{loc}]: {e.message}")
        for req in (fm.get("requires") or []):
            if req not in known_names:
                errors.append(f"{sk}: requires '{req}' não resolve no corpus")

    n_lines = text.count("\n") + 1
    if n_lines > MAX_LINES:
        errors.append(f"{sk}: SKILL.md com {n_lines} linhas (> {MAX_LINES})")

    for fname in ("AGENTS.md", "CHANGELOG.md"):
        if not (skill_dir / fname).exists():
            warnings.append(f"{skill_dir}: {fname} ausente")

    refdir = skill_dir / "reference"
    if refdir.is_dir():
        for ref in sorted(refdir.glob("*.md")):
            rtext = ref.read_text(encoding="utf-8")
            if rtext.count("\n") + 1 > REF_TOC_THRESHOLD and "## " not in rtext[:1200]:
                warnings.append(f"{ref}: > {REF_TOC_THRESHOLD} linhas sem índice (TOC)")

    # Drift do security-baseline inline vs fonte compartilhada (WARN, nao erro)
    inline_baseline = skill_dir / "reference" / "security-baseline.md"
    if inline_baseline.exists() and SOURCE_BASELINE.exists():
        if inline_baseline.read_text(encoding="utf-8") != SOURCE_BASELINE.read_text(encoding="utf-8"):
            warnings.append(
                f"{inline_baseline}: drift vs fonte _shared/security/baseline.md "
                f"(rode _tools/sync_baseline.py)"
            )

    return errors, warnings


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    target = pathlib.Path(sys.argv[1]).resolve()
    corpus = pathlib.Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else None

    if (target / "SKILL.md").exists():
        skill_dirs = [target]
        corpus_root = corpus or target.parent
    else:
        skill_dirs = find_skill_dirs(target)
        corpus_root = corpus or target

    known = collect_names(corpus_root)

    total_err = total_warn = 0
    for d in skill_dirs:
        errs, warns = validate_skill(d, known)
        for e in errs:
            print(f"ERROR {e}")
        for w in warns:
            print(f"WARN  {w}")
        total_err += len(errs)
        total_warn += len(warns)

    print(f"\n{len(skill_dirs)} skill(s) · {total_err} erro(s) · {total_warn} aviso(s)")
    sys.exit(1 if total_err else 0)


if __name__ == "__main__":
    main()
