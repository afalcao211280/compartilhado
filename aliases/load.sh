#!/usr/bin/env bash

if [[ -n "${BASH_VERSION:-}" ]]; then
  _shell="bash"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
  _shell="zsh"
else
  _shell="$(basename "${SHELL:-/bin/sh}")"
fi

ALIASES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" && pwd)"
_loaded=0

for f in "${ALIASES_DIR}"/[0-9]*.sh; do
  if [[ -f "$f" ]]; then
    source "$f"
    _loaded=$((_loaded + 1))
  fi
done

unset _shell f _loaded