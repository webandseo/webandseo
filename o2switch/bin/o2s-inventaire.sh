#!/usr/bin/env bash
#
# o2s-inventaire.sh — dresse l'inventaire complet d'un compte cPanel o2switch
# (compte principal ou lune). À lancer en SSH sur le compte à inventorier.
#
#   ./o2s-inventaire.sh [--out RÉPERTOIRE]
#
# Ne modifie rien. Produit un dossier avec :
#   sites.tsv     tableau consolidé : domaine, docroot, PHP, CMS, base, tailles
#   domaines.tsv  domaines et racines web déclarés dans cPanel
#   bases.tsv     bases de données et leur poids
#   emails.tsv    comptes email
#   crontab.txt   tâches planifiées
#   raw/          réponses brutes de l'API cPanel (utile pour un contrôle a posteriori)
#
set -uo pipefail
cd -- "$(dirname -- "$0")" || exit 1
. ./o2s-lib.sh

OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) die "option inconnue : $1" ;;
  esac
done

USER_CP="$(o2s_user)"
HOME_CP="$(o2s_home)"
OUT="${OUT:-$HOME_CP/o2s-inventaire/$USER_CP-$(o2s_ts)}"
mkdir -p "$OUT/raw" || die "impossible de créer $OUT"

title "Inventaire du compte $USER_CP  ($HOME_CP)"
log "Sortie : $OUT"

# ------------------------------------------------------------- domaines -----
log "Domaines et racines web…"
uapi_json DomainInfo domains_data format=hash > "$OUT/raw/domains_data.json"
o2s_json domains < "$OUT/raw/domains_data.json" | sort -u > "$OUT/domaines.tsv"

if [ ! -s "$OUT/domaines.tsv" ]; then
  warn "API cPanel muette : repli sur une détection par le système de fichiers"
  find "$HOME_CP" -maxdepth 3 -name wp-config.php -printf '%h\n' 2>/dev/null \
    | sed "s|^|?\t|" > "$OUT/domaines.tsv"
fi
ok "$(wc -l < "$OUT/domaines.tsv") entrée(s) de domaine"

# ------------------------------------------------------------- bases --------
log "Bases de données…"
uapi_json Mysql list_databases > "$OUT/raw/list_databases.json"
o2s_json databases < "$OUT/raw/list_databases.json" | sort -u > "$OUT/bases.tsv"
ok "$(wc -l < "$OUT/bases.tsv") base(s)"

# ------------------------------------------------------------- emails -------
log "Comptes email…"
uapi_json Email list_pops > "$OUT/raw/list_pops.json"
o2s_json pops < "$OUT/raw/list_pops.json" | sort -u > "$OUT/emails.tsv"
ok "$(wc -l < "$OUT/emails.tsv") compte(s) email"

# ------------------------------------------------------------- crontab ------
log "Tâches planifiées…"
crontab -l > "$OUT/crontab.txt" 2>/dev/null || : > "$OUT/crontab.txt"
ok "$(grep -cvE '^[[:space:]]*(#|$)' "$OUT/crontab.txt" 2>/dev/null || true) tâche(s) cron"

# ------------------------------------------------- tableau consolidé --------
log "Consolidation…"
printf 'domaine\tdocroot\tphp\tcms\tbase\tuser_bd\tprefixe\ttaille_fichiers_mo\ttaille_bd_mo\n' > "$OUT/sites.tsv"

while IFS=$'\t' read -r domain docroot php dtype; do
  [ -n "${docroot:-}" ] || continue
  [ -d "$docroot" ] || { warn "racine absente pour $domain : $docroot"; continue; }

  cms="?" db="" dbuser="" dbpass="" prefix="" dbsize=""
  if [ -r "$docroot/wp-config.php" ]; then
    cms="wordpress"
    db="$(wpcfg_const DB_NAME     "$docroot/wp-config.php")"
    dbuser="$(wpcfg_const DB_USER "$docroot/wp-config.php")"
    dbpass="$(wpcfg_const DB_PASSWORD "$docroot/wp-config.php")"
    prefix="$(wpcfg_prefix "$docroot/wp-config.php")"
  elif [ -r "$docroot/configuration.php" ]; then cms="joomla"
  elif [ -r "$docroot/app/etc/env.php" ];    then cms="magento"
  elif [ -r "$docroot/config/settings.inc.php" ]; then cms="prestashop"
  elif [ -r "$docroot/index.php" ];          then cms="php"
  elif [ -r "$docroot/index.html" ];         then cms="statique"
  fi

  size="$(du -sm "$docroot" 2>/dev/null | cut -f1)"

  if [ -n "$db" ] && [ -n "$dbuser" ] && [ -n "$dbpass" ] && command -v mysql >/dev/null 2>&1; then
    dbsize="$(MYSQL_PWD="$dbpass" mysql -u "$dbuser" -N -B -e \
      "SELECT ROUND(SUM(data_length+index_length)/1048576) FROM information_schema.tables WHERE table_schema='$db';" \
      2>/dev/null | head -n1)"
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$domain" "$docroot" "${php:-}" "$cms" "$db" "$dbuser" "$prefix" "${size:-}" "${dbsize:-}" \
    >> "$OUT/sites.tsv"
done < "$OUT/domaines.tsv"

chmod -R go-rwx "$OUT"

title "Résumé"
if command -v column >/dev/null 2>&1; then
  column -t -s$'\t' "$OUT/sites.tsv"
else
  cat "$OUT/sites.tsv"
fi

echo
tot_files=$(awk -F'\t' 'NR>1 {s+=$8} END {print s+0}' "$OUT/sites.tsv")
tot_db=$(awk    -F'\t' 'NR>1 {s+=$9} END {print s+0}' "$OUT/sites.tsv")
log "Total : $((  $(wc -l < "$OUT/sites.tsv") - 1 )) site(s), ${tot_files} Mo de fichiers, ${tot_db} Mo de bases"
ok  "Inventaire disponible dans $OUT"
echo
log "Récupération sur votre poste :"
echo "    rsync -av $USER_CP@canard.o2switch.net:${OUT#"$HOME_CP"/} ./"
