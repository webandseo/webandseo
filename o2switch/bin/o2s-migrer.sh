#!/usr/bin/env bash
#
# o2s-migrer.sh — déplace un site d'une lune o2switch vers une autre.
#
# À lancer en SSH sur la lune SOURCE. Le transfert reste interne au serveur
# (les lunes cohabitent sur la même machine), il ne repasse jamais par votre
# connexion : c'est ce qui fait l'essentiel du gain de temps.
#
#   ./o2s-migrer.sh --domaine exemple.fr --dst-user lune2 --phase precopy
#   ./o2s-migrer.sh --domaine exemple.fr --dst-user lune2 --phase precopy --go
#
# Trois phases, dans cet ordre :
#
#   precopy    Copie complète pendant que le site tourne encore. Aucun impact
#              visible, aucune coupure. C'est l'étape longue (minutes à heures
#              selon le poids), à lancer la veille sans stress.
#
#   delta      Resynchronisation des seuls écarts, juste avant la bascule.
#              Quelques secondes. Avec --gel, le site source passe d'abord en
#              maintenance pour qu'aucune écriture ne soit perdue.
#
#   finaliser  Après avoir basculé le domaine dans cPanel : droits, réécriture
#              des chemins absolus, sortie de maintenance, contrôles.
#
# Entre `delta` et `finaliser`, une seule action manuelle dans cPanel :
# retirer le domaine de la lune source, l'ajouter sur la lune de destination.
# C'est la seule fenêtre de coupure, de l'ordre de la minute.
#
# Par défaut le script SIMULE et n'écrit rien. Ajoutez --go pour exécuter.
# Il ne supprime jamais rien sur la lune source.
#
set -uo pipefail
cd -- "$(dirname -- "$0")" || exit 1
. ./o2s-lib.sh

# ------------------------------------------------------------- arguments ----
DOMAIN="" DST_USER="" DST_HOST="localhost" DST_PORT="22" PHASE=""
SRC_DOCROOT="" DST_DOCROOT="" SRC_DB="" DST_DB="" DST_DBUSER="" DST_DBPASS=""
SRC_DBUSER="" SRC_DBPASS="" SRC_DBHOST="localhost" SRC_PREFIX="" DST_HOME="" WP_CONFIG=""
GEL=0 NO_WP=0 REECRIRE=0 SRC_USER_OPT=""
EXTRA_EXCLUDES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --domaine|--domain) DOMAIN="${2:-}";      shift 2 ;;
    --dst-user)         DST_USER="${2:-}";    shift 2 ;;
    --src-user)         SRC_USER_OPT="${2:-}"; shift 2 ;;
    --dst-host)         DST_HOST="${2:-}";    shift 2 ;;
    --dst-port)         DST_PORT="${2:-}";    shift 2 ;;
    --phase)            PHASE="${2:-}";       shift 2 ;;
    --src-docroot)      SRC_DOCROOT="${2:-}"; shift 2 ;;
    --dst-docroot)      DST_DOCROOT="${2:-}"; shift 2 ;;
    --db)               SRC_DB="${2:-}";      shift 2 ;;
    --dst-db)           DST_DB="${2:-}";      shift 2 ;;
    --dst-db-user)      DST_DBUSER="${2:-}";  shift 2 ;;
    --exclude)          EXTRA_EXCLUDES+=("${2:-}"); shift 2 ;;
    --gel)              GEL=1; shift ;;
    --no-wp)            NO_WP=1; shift ;;
    --reecrire-chemins) REECRIRE=1; shift ;;
    --go)               O2S_GO=1; shift ;;
    -h|--help)          sed -n '2,35p' "$0"; exit 0 ;;
    *) die "option inconnue : $1  (--help pour l'aide)" ;;
  esac
done

[ -n "$DOMAIN" ]   || die "--domaine est obligatoire"
[ -n "$DST_USER" ] || die "--dst-user est obligatoire"
case "$PHASE" in
  check|precopy|delta|finaliser) ;;
  *) die "--phase doit valoir check, precopy, delta ou finaliser" ;;
esac

SRC_USER="$(o2s_user)"
SRC_HOME="$(o2s_home)"
WORK="$SRC_HOME/o2s-migration/$DOMAIN"
STATE="$WORK/etat.env"
mkdir -p "$WORK" && chmod 700 "$SRC_HOME/o2s-migration" "$WORK" 2>/dev/null

SSH_OPTS="-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"

# ------------------------------------------------------- helpers distants ---
dst_run() { # commande sur la lune de destination, arguments protégés
  local cmd="" a
  for a in "$@"; do cmd+="$(printf '%q ' "$a")"; done
  # shellcheck disable=SC2086
  ssh $SSH_OPTS -p "$DST_PORT" "$DST_USER@$DST_HOST" "$cmd"
}

dst_script() { # script bash sur stdin, exécuté à distance, arguments en $1..$n
  # shellcheck disable=SC2086
  ssh $SSH_OPTS -p "$DST_PORT" "$DST_USER@$DST_HOST" bash -s -- "$@"
}

# ------------------------------------------------------------ résolutions ---
resolve_src_docroot() {
  [ -n "$SRC_DOCROOT" ] && return 0
  SRC_DOCROOT="$(uapi_json DomainInfo domains_data format=hash \
    | o2s_json domains | awk -F'\t' -v d="$DOMAIN" '$1==d {print $2; exit}')"
  if [ -z "$SRC_DOCROOT" ]; then
    for c in "$SRC_HOME/$DOMAIN" "$SRC_HOME/public_html/$DOMAIN" "$SRC_HOME/public_html"; do
      [ -d "$c" ] && { SRC_DOCROOT="$c"; break; }
    done
  fi
  [ -n "$SRC_DOCROOT" ] || die "racine web introuvable pour $DOMAIN — précisez --src-docroot"
}

read_wpconfig() {
  WP_CONFIG="$SRC_DOCROOT/wp-config.php"
  if [ "$NO_WP" = "1" ] || [ ! -r "$WP_CONFIG" ]; then
    NO_WP=1
    [ -n "$SRC_DB" ] || warn "pas de wp-config.php : aucune base ne sera transférée (utilisez --db)"
    return 0
  fi
  SRC_DB="${SRC_DB:-$(wpcfg_const DB_NAME "$WP_CONFIG")}"
  SRC_DBUSER="$(wpcfg_const DB_USER "$WP_CONFIG")"
  SRC_DBPASS="$(wpcfg_const DB_PASSWORD "$WP_CONFIG")"
  SRC_DBHOST="$(wpcfg_const DB_HOST "$WP_CONFIG")"; SRC_DBHOST="${SRC_DBHOST:-localhost}"
  SRC_PREFIX="$(wpcfg_prefix "$WP_CONFIG")"
  [ -n "$SRC_DB" ] || die "DB_NAME illisible dans $WP_CONFIG"
}

# --------------------------------------------------------------- contrôles --
phase_check() {
  title "Contrôles préalables — $DOMAIN"

  resolve_src_docroot
  ok "racine source : $SRC_DOCROOT"
  local sz; sz="$(du -sh "$SRC_DOCROOT" 2>/dev/null | cut -f1)"
  log "poids des fichiers : ${sz:-inconnu}"

  read_wpconfig
  if [ "$NO_WP" = "0" ]; then
    ok "WordPress détecté — base $SRC_DB (préfixe ${SRC_PREFIX:-?})"
  else
    warn "pas de WordPress détecté"
  fi

  log "Connexion SSH vers $DST_USER@$DST_HOST…"
  if DST_HOME="$(dst_run sh -c 'echo $HOME' 2>/dev/null)" && [ -n "$DST_HOME" ]; then
    ok "connexion établie — home de destination : $DST_HOME"
  else
    err "connexion SSH vers $DST_USER@$DST_HOST impossible"
    cat <<BOOTSTRAP

  À faire une seule fois, pour que la lune source puisse écrire sur la lune
  de destination sans mot de passe :

    1) Sur CETTE lune (source), créez une clé si elle n'existe pas :
         ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
         cat ~/.ssh/id_ed25519.pub

    2) Dans le cPanel de la lune « $DST_USER » :
         Sécurité > Accès SSH > Gérer les clés SSH > Importer une clé
         Collez la clé publique, puis « Autoriser » (Manage > Authorize).

    3) Vérifiez la liste blanche d'IP :
         Sécurité > Autorisation SSH, sur les DEUX lunes.

    4) Retestez :
         ./o2s-migrer.sh --domaine $DOMAIN --dst-user $DST_USER --phase check

BOOTSTRAP
    return 1
  fi

  DST_DOCROOT="${DST_DOCROOT:-$DST_HOME/$DOMAIN}"
  case "$DST_DOCROOT" in /*) ;; *) DST_DOCROOT="$DST_HOME/$DST_DOCROOT" ;; esac
  ok "racine de destination prévue : $DST_DOCROOT"

  local avail; avail="$(dst_run df -Pm "$DST_HOME" 2>/dev/null | awk 'NR==2{print $4}')"
  [ -n "$avail" ] && log "espace disponible côté destination : ${avail} Mo"

  log "Domaine déjà présent sur la destination ?"
  if dst_run uapi --output=json DomainInfo list_domains 2>/dev/null | grep -q "\"$DOMAIN\""; then
    warn "$DOMAIN semble déjà déclaré sur $DST_USER — vérifiez avant de continuer"
  else
    ok "non, la voie est libre"
  fi

  state_set "$STATE" SRC_USER    "$SRC_USER"
  state_set "$STATE" SRC_DOCROOT "$SRC_DOCROOT"
  state_set "$STATE" DST_USER    "$DST_USER"
  state_set "$STATE" DST_HOME    "$DST_HOME"
  state_set "$STATE" DST_DOCROOT "$DST_DOCROOT"
  state_set "$STATE" DOMAIN      "$DOMAIN"
}

# ------------------------------------------------------------ exclusions ----
build_excludes() {
  EXCL="$WORK/exclusions.txt"
  cat > "$EXCL" <<'EXC'
# Caches et sauvegardes : inutiles à transporter, et ils contiennent souvent
# des chemins absolus périmés qui casseraient le site après bascule.
wp-content/cache/
wp-content/litespeed/
wp-content/et-cache/
wp-content/wp-rocket-config/
wp-content/uploads/cache/
wp-content/uploads/wp-clone/
wp-content/ai1wm-backups/
wp-content/updraft/
wp-content/backups/
wp-content/backup*/
wp-content/advanced-cache.php
wp-content/object-cache.php
wp-content/debug.log
*.log
error_log
.well-known/acme-challenge/
.git/
node_modules/
.DS_Store
EXC
  local e
  for e in "${EXTRA_EXCLUDES[@]+"${EXTRA_EXCLUDES[@]}"}"; do printf '%s\n' "$e" >> "$EXCL"; done
}

# --------------------------------------------------------- fichiers / base --
sync_files() { # $1 = 1 pour activer --delete
  local del=""; [ "${1:-0}" = "1" ] && del="--delete"
  build_excludes
  local z=""; [ "$DST_HOST" != "localhost" ] && z="-z"
  log "Synchronisation des fichiers vers $DST_USER@$DST_HOST:$DST_DOCROOT/"
  run_sh "rsync -a $del $z --human-readable --info=stats2 \
    --exclude-from=$(printf '%q' "$EXCL") \
    -e $(printf '%q' "ssh $SSH_OPTS -p $DST_PORT") \
    $(printf '%q' "$SRC_DOCROOT/") \
    $(printf '%q' "$DST_USER@$DST_HOST:$DST_DOCROOT/")"
}

ensure_dst_db() {
  [ "$NO_WP" = "1" ] && [ -z "$SRC_DB" ] && return 0
  local slug; slug="$(o2s_slug "$DOMAIN")"
  DST_DB="${DST_DB:-$(state_get "$STATE" DST_DB)}"; DST_DB="${DST_DB:-${DST_USER}_${slug}}"
  DST_DBUSER="${DST_DBUSER:-$(state_get "$STATE" DST_DBUSER)}"; DST_DBUSER="${DST_DBUSER:-${DST_USER}_${slug}}"
  DST_DBPASS="$(state_get "$STATE" DST_DBPASS)"

  if [ -n "$DST_DBPASS" ]; then
    ok "base de destination déjà créée : $DST_DB"
    return 0
  fi

  DST_DBPASS="$(o2s_pass)"
  log "Création de la base $DST_DB et de l'utilisateur $DST_DBUSER sur $DST_USER"
  run dst_run uapi --output=json Mysql create_database "name=$DST_DB"
  run dst_run uapi --output=json Mysql create_user "name=$DST_DBUSER" "password=$DST_DBPASS"
  run dst_run uapi --output=json Mysql set_privileges_on_database \
      "user=$DST_DBUSER" "database=$DST_DB" "privileges=ALL PRIVILEGES"

  if [ "$O2S_GO" = "1" ]; then
    state_set "$STATE" DST_DB     "$DST_DB"
    state_set "$STATE" DST_DBUSER "$DST_DBUSER"
    state_set "$STATE" DST_DBPASS "$DST_DBPASS"
    ok "identifiants enregistrés dans $STATE (droits 600)"
  fi
}

transfer_db() {
  [ -n "${SRC_DB:-}" ] || { warn "aucune base à transférer"; return 0; }

  # Fichier d'options plutôt que mot de passe sur la ligne de commande.
  local mycnf="$WORK/my.cnf"
  if [ "$O2S_GO" = "1" ]; then
    umask 077
    printf '[client]\nuser=%s\npassword="%s"\nhost=%s\n' \
      "$SRC_DBUSER" "$SRC_DBPASS" "${SRC_DBHOST:-localhost}" > "$mycnf"
    chmod 600 "$mycnf"
  fi

  local dump="$WORK/$SRC_DB-$(o2s_ts).sql.gz"
  log "Export de la base $SRC_DB"
  run_sh "mysqldump --defaults-extra-file=$(printf '%q' "$mycnf") \
    --single-transaction --quick --lock-tables=false --no-tablespaces \
    --default-character-set=utf8mb4 --add-drop-table --routines --events \
    $(printf '%q' "$SRC_DB") | gzip -1 > $(printf '%q' "$dump")"

  if [ "$O2S_GO" = "1" ]; then
    ls -lh "$dump" 2>/dev/null | awk '{print "    export : " $5}'
    [ -s "$dump" ] || die "export vide — vérifiez les identifiants de $SRC_DB"
  fi

  log "Import dans $DST_DB sur la lune $DST_USER"
  if [ "$O2S_GO" = "1" ]; then
    # Le mot de passe transite par un fichier d'options à droits 600 côté
    # destination, jamais par la ligne de commande.
    local rcnf=".o2s-my-$$.cnf"
    dst_script "$rcnf" "$DST_DBUSER" "$DST_DBPASS" <<'REMOTE'
set -eu
umask 077
printf '[client]\nuser=%s\npassword="%s"\nhost=localhost\n' "$2" "$3" > "$1"
chmod 600 "$1"
REMOTE
    if gzip -dc "$dump" | dst_run mysql --defaults-extra-file="$rcnf" \
         --default-character-set=utf8mb4 "$DST_DB"; then
      dst_run rm -f "$rcnf"
      ok "base importée dans $DST_DB"
    else
      dst_run rm -f "$rcnf"
      die "échec de l'import — la base source reste intacte"
    fi
  else
    printf '%s  [simulation] gzip -dc %s | mysql (%s@%s) %s%s\n' \
      "$C_Y" "$dump" "$DST_DBUSER" "$DST_HOST" "$DST_DB" "$C_RST"
  fi
}

patch_wpconfig() {
  [ "$NO_WP" = "1" ] && return 0
  log "Mise à jour des identifiants de base dans le wp-config.php de destination"
  if [ "$O2S_GO" = "1" ]; then
    dst_script "$DST_DOCROOT/wp-config.php" "$DST_DB" "$DST_DBUSER" "$DST_DBPASS" <<'REMOTE'
set -eu
f="$1"; db="$2"; du="$3"; dp="$4"
[ -r "$f" ] || { echo "wp-config.php absent : $f" >&2; exit 1; }
cp -p "$f" "$f.avant-migration"
set_const() {
  php -r '
    $f=$argv[1]; $k=$argv[2]; $v=$argv[3];
    $s=file_get_contents($f);
    $p="/define\(\s*([\x27\"])".preg_quote($k,"/")."\\1\s*,\s*([\x27\"]).*?\\2\s*\)\s*;/s";
    $r="define( \x27".$k."\x27, ".var_export($v,true)." );";
    $s=preg_replace_callback($p,function()use($r){return $r;},$s,1,$n);
    if(!$n){ fwrite(STDERR,"constante $k introuvable\n"); exit(1); }
    file_put_contents($f,$s);
  ' "$1" "$2" "$3"
}
set_const "$f" DB_NAME     "$db"
set_const "$f" DB_USER     "$du"
set_const "$f" DB_PASSWORD "$dp"
echo "wp-config.php mis à jour (copie de sécurité : $f.avant-migration)"
REMOTE
  else
    printf '%s  [simulation] mise à jour DB_NAME/DB_USER/DB_PASSWORD dans %s%s\n' \
      "$C_Y" "$DST_DOCROOT/wp-config.php" "$C_RST"
  fi
}

rapport_chemins() {
  title "Chemins absolus à surveiller"
  log "Recherche de « $SRC_HOME » dans les fichiers copiés…"
  if [ "$O2S_GO" = "1" ]; then
    dst_run grep -rl --binary-files=without-match -F "$SRC_HOME" "$DST_DOCROOT" 2>/dev/null \
      | head -40 | sed 's/^/    /' || true
  fi
  if [ -n "${SRC_DB:-}" ] && [ "$O2S_GO" = "1" ]; then
    log "Recherche de « $SRC_HOME » dans la base…"
    mysql --defaults-extra-file="$WORK/my.cnf" -N -B "$SRC_DB" -e \
      "SELECT CONCAT(option_name,' (wp_options)') FROM ${SRC_PREFIX:-wp_}options
       WHERE option_value LIKE '%$SRC_HOME%' LIMIT 20;" 2>/dev/null | sed 's/^/    /' || true
  fi
  cat <<'NOTE'

    Rien ici n'est bloquant en soi : ces chemins seront corrigés par
    « --phase finaliser --reecrire-chemins ». Les caches (WP Rocket,
    LiteSpeed, Elementor) se régénèrent d'eux-mêmes une fois purgés.
NOTE
}

# ----------------------------------------------------------------- phases ---
phase_precopy() {
  phase_check || exit 1
  title "Pré-copie — $DOMAIN  ($SRC_USER → $DST_USER)"
  log "Le site reste en ligne pendant toute cette phase."

  log "Sauvegarde de la zone DNS (indispensable avant de retirer le domaine)"
  run_sh "./o2s-dns-save.sh --domaine $(printf '%q' "$DOMAIN") --out $(printf '%q' "$WORK/dns")"

  log "Sauvegarde des tâches cron de la lune source"
  run_sh "crontab -l > $(printf '%q' "$WORK/crontab-source.txt") 2>/dev/null || true"

  run dst_run mkdir -p "$DST_DOCROOT"
  sync_files 0
  ensure_dst_db
  transfer_db
  patch_wpconfig

  # L'état est recopié côté destination : la phase « finaliser » s'y exécute
  # et doit connaître la racine cible ainsi que le compte d'origine.
  log "Dépôt du fichier d'état sur la lune de destination"
  if [ "$O2S_GO" = "1" ]; then
    if dst_run sh -c "umask 077; mkdir -p o2s-migration/$DOMAIN; cat > o2s-migration/$DOMAIN/etat.env" < "$STATE"; then
      ok "état disponible sur $DST_USER:~/o2s-migration/$DOMAIN/etat.env"
    else
      warn "état non recopié — passez --src-user $SRC_USER à la phase finaliser"
    fi
  fi

  rapport_chemins

  title "Pré-copie terminée"
  cat <<FIN
  La lune « $DST_USER » contient maintenant une copie complète du site,
  base comprise. Le domaine pointe toujours sur « $SRC_USER » : rien n'a
  changé pour les visiteurs.

  Prochaine étape, au moment choisi pour la bascule :

    ./o2s-migrer.sh --domaine $DOMAIN --dst-user $DST_USER --phase delta --gel --go

FIN
}

phase_delta() {
  SRC_DOCROOT="${SRC_DOCROOT:-$(state_get "$STATE" SRC_DOCROOT)}"
  DST_DOCROOT="${DST_DOCROOT:-$(state_get "$STATE" DST_DOCROOT)}"
  DST_DB="${DST_DB:-$(state_get "$STATE" DST_DB)}"
  DST_DBUSER="${DST_DBUSER:-$(state_get "$STATE" DST_DBUSER)}"
  DST_DBPASS="$(state_get "$STATE" DST_DBPASS)"
  [ -n "$SRC_DOCROOT" ] || die "état introuvable — lancez d'abord --phase precopy"
  read_wpconfig
  if [ -n "${SRC_DB:-}" ] && [ -z "$DST_DBPASS" ]; then
    die "identifiants de la base cible absents de $STATE — relancez --phase precopy"
  fi

  title "Delta — $DOMAIN"
  if [ "$GEL" = "1" ]; then
    log "Passage du site source en maintenance (aucune écriture perdue)"
    run_sh "printf '<?php \$upgrading = time(); ?>' > $(printf '%q' "$SRC_DOCROOT/.maintenance")"
    state_set "$STATE" GEL 1
  else
    warn "sans --gel, toute écriture faite après le dump sera perdue"
  fi

  sync_files 1
  transfer_db
  patch_wpconfig

  title "À faire maintenant dans cPanel — c'est la seule coupure"
  cat <<BASCULE
  1. cPanel de « $SRC_USER »   > Domaines > $DOMAIN > Supprimer
  2. cPanel de « $DST_USER »   > Domaines > Créer un domaine
        Domaine         : $DOMAIN
        Racine du site  : $DST_DOCROOT
        (décochez « Partager le document root » si l'option apparaît)
  3. Éditeur de zone de « $DST_USER » : ressaisissez les enregistrements
     relevés dans $WORK/dns  (MX, SPF, DKIM, DMARC, CAA, vérifications).
  4. SSL/TLS Status > Exécuter AutoSSL sur « $DST_USER ».

  La lune « $SRC_USER » conserve le site intact, en mode maintenance : c'est
  votre filet. Pour revenir en arrière, il suffit d'y recréer le domaine et
  de supprimer le fichier .maintenance à la racine.

  Puis, sur la lune de DESTINATION :
     ./o2s-migrer.sh --domaine $DOMAIN --dst-user $DST_USER --phase finaliser --go

BASCULE
}

phase_finaliser() {
  DST_DOCROOT="${DST_DOCROOT:-$(state_get "$STATE" DST_DOCROOT)}"
  [ -n "$DST_DOCROOT" ] || die "état introuvable — précisez --dst-docroot"

  # Cette phase tourne sur la lune de DESTINATION. Le fichier d'état y est
  # recopié par la pré-copie ; s'il manque, --src-user doit être fourni.
  SRC_USER_OLD="${SRC_USER_OPT:-$(state_get "$STATE" SRC_USER)}"
  SRC_HOME_OLD="/home/$SRC_USER_OLD"

  title "Finalisation — $DOMAIN"

  log "Droits sur les fichiers"
  run_sh "find $(printf '%q' "$DST_DOCROOT") -type d -exec chmod 755 {} + 2>/dev/null; true"
  run_sh "find $(printf '%q' "$DST_DOCROOT") -type f -exec chmod 644 {} + 2>/dev/null; true"
  run_sh "chmod 600 $(printf '%q' "$DST_DOCROOT/wp-config.php") 2>/dev/null; true"

  if [ "$REECRIRE" = "1" ]; then
    # Sans ce contrôle, un SRC_USER vide donnerait « /home/ » comme motif de
    # remplacement, et le sed réécrirait tous les chemins de tous les fichiers.
    case "$SRC_USER_OLD" in
      "" ) die "--reecrire-chemins exige --src-user (nom d'utilisateur cPanel de la lune d'origine)" ;;
      */*|.|..) die "--src-user invalide : $SRC_USER_OLD" ;;
    esac
    [ "$SRC_USER_OLD" = "$(o2s_user)" ] && die "--src-user est identique au compte courant : rien à réécrire"
    [ -d "$SRC_HOME_OLD" ] || log "note : $SRC_HOME_OLD n'est pas visible depuis ici, c'est normal"
    log "Réécriture des chemins $SRC_HOME_OLD → $(o2s_home) dans les fichiers de configuration"
    run_sh "grep -rl --binary-files=without-match -F $(printf '%q' "$SRC_HOME_OLD") \
      $(printf '%q' "$DST_DOCROOT") 2>/dev/null \
      | grep -E '\\.(php|ini|htaccess|json|conf|env)$|\\.htaccess' \
      | xargs -r sed -i $(printf '%q' "s|$SRC_HOME_OLD|$(o2s_home)|g")"
  fi

  log "Sortie de maintenance"
  run_sh "rm -f $(printf '%q' "$DST_DOCROOT/.maintenance")"

  if command -v wp >/dev/null 2>&1 && [ -r "$DST_DOCROOT/wp-config.php" ]; then
    log "Purge des caches et régénération des permaliens (WP-CLI)"
    run_sh "cd $(printf '%q' "$DST_DOCROOT") && wp cache flush --quiet 2>/dev/null; \
            wp rewrite flush --hard --quiet 2>/dev/null; \
            wp transient delete --all --quiet 2>/dev/null; true"
    if [ "$REECRIRE" = "1" ]; then
      log "Chemins absolus restants en base :"
      run_sh "cd $(printf '%q' "$DST_DOCROOT") && \
        wp search-replace $(printf '%q' "$SRC_HOME_OLD") $(printf '%q' "$(o2s_home)") \
        --all-tables-with-prefix --precise --report-changed-only 2>/dev/null || true"
    fi
  else
    warn "WP-CLI absent : purgez le cache et réenregistrez les permaliens depuis l'admin"
  fi

  title "Contrôles"
  run_sh "./o2s-verif.sh --domaine $(printf '%q' "$DOMAIN") --docroot $(printf '%q' "$DST_DOCROOT")"
}

# ------------------------------------------------------------------ main ----
[ "$O2S_GO" = "1" ] || warn "MODE SIMULATION — rien ne sera modifié. Ajoutez --go pour exécuter."

case "$PHASE" in
  check)     phase_check ;;
  precopy)   phase_precopy ;;
  delta)     phase_delta ;;
  finaliser) phase_finaliser ;;
esac
