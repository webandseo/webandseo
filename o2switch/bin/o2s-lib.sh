#!/usr/bin/env bash
# o2s-lib.sh — fonctions communes aux outils de migration inter-lunes o2switch.
# Ce fichier est sourcé par les autres scripts, il ne s'exécute pas seul.

O2S_VERSION="1.0.0"

# ---------------------------------------------------------------- affichage --
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  C_RST=$(tput sgr0); C_R=$(tput setaf 1); C_G=$(tput setaf 2)
  C_Y=$(tput setaf 3); C_B=$(tput setaf 6); C_D=$(tput bold)
else
  C_RST=""; C_R=""; C_G=""; C_Y=""; C_B=""; C_D=""
fi

log()   { printf '%s[.]%s %s\n' "$C_B" "$C_RST" "$*"; }
ok()    { printf '%s[ok]%s %s\n' "$C_G" "$C_RST" "$*"; }
warn()  { printf '%s[!]%s %s\n' "$C_Y" "$C_RST" "$*" >&2; }
err()   { printf '%s[X]%s %s\n' "$C_R" "$C_RST" "$*" >&2; }
die()   { err "$*"; exit 1; }
title() { printf '\n%s=== %s ===%s\n' "$C_D" "$*" "$C_RST"; }

# ------------------------------------------------------- simulation / exec --
# O2S_GO=1 exécute réellement. Par défaut on ne fait qu'afficher.
O2S_GO="${O2S_GO:-0}"

run() {   # exécution d'une commande passée en argv (pas de pipe / redirection)
  if [ "$O2S_GO" = "1" ]; then
    printf '%s  $ %s%s\n' "$C_D" "$*" "$C_RST"
    "$@"
  else
    printf '%s  [simulation] %s%s\n' "$C_Y" "$*" "$C_RST"
    return 0
  fi
}

run_sh() { # exécution d'une ligne de shell complète (pipes, redirections...)
  if [ "$O2S_GO" = "1" ]; then
    printf '%s  $ %s%s\n' "$C_D" "$1" "$C_RST"
    bash -o pipefail -c "$1"
  else
    printf '%s  [simulation] %s%s\n' "$C_Y" "$1" "$C_RST"
    return 0
  fi
}

need() { command -v "$1" >/dev/null 2>&1 || die "commande absente : $1"; }

confirm() {
  [ "${O2S_YES:-0}" = "1" ] && return 0
  printf '%s%s [o/N] %s' "$C_Y" "$1" "$C_RST"
  read -r _r </dev/tty || return 1
  case "$_r" in [oO]|[oO][uU][iI]|[yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

# ------------------------------------------------------------------ cPanel --
o2s_user()  { id -un; }
o2s_home()  { echo "${HOME:-/home/$(id -un)}"; }

# Appelle une fonction UAPI et renvoie le JSON brut sur stdout.
# Usage : uapi_json DomainInfo domains_data format=hash
uapi_json() {
  command -v uapi >/dev/null 2>&1 || { echo '{}'; return 1; }
  uapi --output=json "$@" 2>/dev/null || echo '{}'
}

# Extraction JSON : s'appuie sur o2s-json.php (PHP est toujours présent
# sur un compte cPanel) et retombe sur jq si PHP manque.
O2S_BIN_DIR="${O2S_BIN_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"

o2s_json() { # $1 = mode (domains|databases|pops|keys) ; JSON sur stdin ; TSV sur stdout
  local mode="$1"
  if command -v php >/dev/null 2>&1 && [ -f "$O2S_BIN_DIR/o2s-json.php" ]; then
    php "$O2S_BIN_DIR/o2s-json.php" "$mode"
  elif command -v jq >/dev/null 2>&1; then
    case "$mode" in
      domains)   jq -r '[paths(type=="object")] as $p | .. | objects | select(has("domain") and has("documentroot")) | [.domain, .documentroot, (.phpversion // "")] | @tsv' ;;
      databases) jq -r '.. | objects | select(has("database")) | [.database, (.disk_usage // "")] | @tsv' ;;
      pops)      jq -r '.. | objects | select(has("email")) | [.email, (.diskused // "")] | @tsv' ;;
      *)         cat ;;
    esac
  else
    warn "ni php ni jq : impossible de lire le JSON cPanel"
    return 1
  fi
}

# ------------------------------------------------------------- wp-config -----
wpcfg_const() { # $1 = nom de la constante, $2 = chemin wp-config.php
  [ -r "$2" ] || return 1
  if command -v php >/dev/null 2>&1 && [ -f "$O2S_BIN_DIR/o2s-wpcfg.php" ]; then
    php "$O2S_BIN_DIR/o2s-wpcfg.php" "$2" const "$1" 2>/dev/null && return 0
  fi
  # Repli si PHP manque : correct tant que la valeur ne contient ni apostrophe
  # ni contre-oblique.
  sed -n "s/^[[:space:]]*define([[:space:]]*['\"]$1['\"][[:space:]]*,[[:space:]]*['\"]\(.*\)['\"][[:space:]]*)[[:space:]]*;.*/\1/p" "$2" | head -n1
}

wpcfg_prefix() { # $1 = chemin wp-config.php
  [ -r "$1" ] || return 1
  if command -v php >/dev/null 2>&1 && [ -f "$O2S_BIN_DIR/o2s-wpcfg.php" ]; then
    php "$O2S_BIN_DIR/o2s-wpcfg.php" "$1" prefix 2>/dev/null && return 0
  fi
  sed -n "s/^[[:space:]]*\\\$table_prefix[[:space:]]*=[[:space:]]*['\"]\([^'\"]*\)['\"].*/\1/p" "$1" | head -n1
}

# ------------------------------------------------------------------ divers --
o2s_slug() { # normalise un domaine en identifiant court pour nom de base
  printf '%s' "$1" | tr 'A-Z' 'a-z' | sed -e 's/^www\.//' -e 's/[^a-z0-9]/_/g' | cut -c1-16
}

o2s_pass() { # mot de passe robuste, sans caractères pénibles à échapper
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 48 | tr -d '\n/+=:@\\"'"'" | cut -c1-28
  else
    head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n' | cut -c1-28
  fi
}

o2s_ts() { date +%Y%m%d-%H%M%S; }

# Écrit / relit un fichier d'état clé=valeur (droits 600).
state_set() { # $1 = fichier, $2 = clé, $3 = valeur
  local f="$1" k="$2" v="$3"
  touch "$f"; chmod 600 "$f"
  if grep -q "^$k=" "$f" 2>/dev/null; then
    sed -i "s|^$k=.*|$k=$v|" "$f"
  else
    printf '%s=%s\n' "$k" "$v" >> "$f"
  fi
}
state_get() { # $1 = fichier, $2 = clé
  [ -r "$1" ] || return 1
  sed -n "s|^$2=||p" "$1" | head -n1
}
