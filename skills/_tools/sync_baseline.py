#!/usr/bin/env python3
"""Propaga o security baseline para dentro de cada skill (self-contained).

Fonte unica: _shared/security/baseline.md
Alvo: reference/security-baseline.md de cada skill com superficie de seguranca
      (detectada por referenciar o baseline no SKILL.md).

Uso:
  python sync_baseline.py [--check]

  (sem args)  copia a fonte para cada reference/security-baseline.md dos alvos.
  --check     nao escreve; lista alvos com drift (cópia != fonte) e sai 1 se houver.
"""
import sys
import re
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
SOURCE = ROOT / "_shared" / "security" / "baseline.md"

# Detecta ponteiro de baseline (antes do swap: ../../_shared; depois: reference/)
POINTER_RE = re.compile(r"_shared/security/baseline\.md|reference/security-baseline\.md")


def targets():
    out = []
    for sk in sorted(ROOT.rglob("SKILL.md")):
        if "_shared" in sk.parts or "_tools" in sk.parts:
            continue
        if POINTER_RE.search(sk.read_text(encoding="utf-8")):
            out.append(sk.parent)
    return out


def main():
    check = "--check" in sys.argv[1:]
    if not SOURCE.exists():
        print(f"ERRO: fonte ausente: {SOURCE}")
        sys.exit(2)
    src = SOURCE.read_text(encoding="utf-8")

    drift, written = [], 0
    for skill_dir in targets():
        dst = skill_dir / "reference" / "security-baseline.md"
        current = dst.read_text(encoding="utf-8") if dst.exists() else None
        if current == src:
            continue
        if check:
            drift.append(skill_dir.relative_to(ROOT))
        else:
            dst.parent.mkdir(exist_ok=True)
            dst.write_text(src, encoding="utf-8")
            written += 1

    n = len(targets())
    if check:
        for d in drift:
            print(f"DRIFT {d}")
        print(f"\n{n} alvo(s) · {len(drift)} com drift")
        sys.exit(1 if drift else 0)
    print(f"{n} alvo(s) · {written} atualizado(s) a partir de {SOURCE.name}")


if __name__ == "__main__":
    main()
