#!/usr/bin/env bash
#
# o2s-verif.sh — photographie l'état d'un site, puis compare avant / après
# bascule entre lunes.
#
#   ./o2s-verif.sh --domaine exemple.fr --snapshot avant     # avant la bascule
#   ./o2s-verif.sh --domaine exemple.fr --snapshot apres     # après, avec écarts
#   ./o2s-verif.sh --domaine exemple.fr --docroot ~/exemple.fr
#
# Sur 23 sites, l'œil ne suffit pas : une redirection perdue ou un MX disparu
# se voient rarement en ouvrant la page d'accueil. On relève donc des faits
# mesurables des deux côtés de l'opération et on affiche uniquement ce qui a
# bougé.
#
set -uo pipefail
cd -- "$(dirname -- "$0")" || exit 1
. ./o2s-lib.sh

DOMAIN="" DOCROOT="" SNAP="" SOUS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --domaine|--domain) DOMAIN="${2:-}";  shift 2 ;;
    --docroot)          DOCROOT="${2:-}"; shift 2 ;;
    --snapshot)         SNAP="${2:-}";    shift 2 ;;
    --sous-domaines)    SOUS="${2:-}";    shift 2 ;;
    -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
    *) die "option inconnue : $1" ;;
  esac
done
[ -n "$DOMAIN" ] || die "--domaine est obligatoire"

WORK="$(o2s_home)/o2s-migration/$DOMAIN"
mkdir -p "$WORK" 2>/dev/null

# ------------------------------------------------------------- collecte -----
releve() {
  local u
  for u in "http://$DOMAIN" "https://$DOMAIN" "https://www.$DOMAIN"; do
    local line
    line="$(curl -sS -o /dev/null -m 25 -L \
      -w '%{http_code} %{num_redirects} %{url_effective}' "$u" 2>/dev/null || echo 'ERR 0 -')"
    printf 'http\t%s\t%s\n' "$u" "$line"
  done

  local titre
  titre="$(curl -sS -m 25 -L "https://$DOMAIN" 2>/dev/null \
    | tr -d '\n' | sed -n 's/.*<title[^>]*>\(.\{1,160\}\)<\/title>.*/\1/Ip' | head -n1)"
  printf 'titre\t%s\n' "${titre:-<vide>}"

  local poids
  poids="$(curl -sS -o /dev/null -m 25 -L -w '%{size_download}' "https://$DOMAIN" 2>/dev/null || echo 0)"
  # Arrondi au Ko : le contenu bouge légèrement d'un chargement à l'autre
  # (jetons CSRF, horodatages), un écart d'octets n'est pas un signal.
  printf 'poids_ko\t%s\n' "$(( ${poids:-0} / 1024 ))"

  if command -v openssl >/dev/null 2>&1; then
    local cert
    cert="$(echo | timeout 15 openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null \
      | openssl x509 -noout -issuer -enddate 2>/dev/null | tr '\n' ' ')"
    printf 'ssl\t%s\n' "${cert:-<indisponible>}"
  fi

  if command -v dig >/dev/null 2>&1; then
    printf 'dns_a\t%s\n'     "$(dig +short A    "$DOMAIN" 2>/dev/null | sort | tr '\n' ' ')"
    printf 'dns_mx\t%s\n'    "$(dig +short MX   "$DOMAIN" 2>/dev/null | sort | tr '\n' ' ')"
    printf 'dns_ns\t%s\n'    "$(dig +short NS   "$DOMAIN" 2>/dev/null | sort | tr '\n' ' ')"
    printf 'dns_spf\t%s\n'   "$(dig +short TXT  "$DOMAIN" 2>/dev/null | grep -i spf1 | tr '\n' ' ')"
    printf 'dns_dmarc\t%s\n' "$(dig +short TXT "_dmarc.$DOMAIN" 2>/dev/null | tr '\n' ' ')"
  fi

  # Sous-domaines et alias CDN : ils vivent dans la zone du domaine parent et
  # disparaissent donc avec elle. Sans relevé nominatif, leur perte ne se voit
  # pas — le domaine principal, lui, répond toujours.
  if [ -n "$SOUS" ] && command -v dig >/dev/null 2>&1; then
    for sd in $(printf '%s' "$SOUS" | tr ',' ' '); do
      case "$sd" in *.*) fqdn="$sd" ;; *) fqdn="$sd.$DOMAIN" ;; esac
      printf 'sous_a\t%s\t%s\n'     "$fqdn" "$(dig +short A     "$fqdn" 2>/dev/null | sort | tr '\n' ' ')"
      printf 'sous_cname\t%s\t%s\n' "$fqdn" "$(dig +short CNAME "$fqdn" 2>/dev/null | sort | tr '\n' ' ')"
      printf 'sous_http\t%s\t%s\n'  "$fqdn" "$(curl -sS -o /dev/null -m 25 -L \
        -w '%{http_code} %{num_redirects} %{url_effective}' "https://$fqdn" 2>/dev/null || echo 'ERR 0 -')"
    done
  fi

  if [ -n "$DOCROOT" ] && [ -r "$DOCROOT/wp-config.php" ] && command -v wp >/dev/null 2>&1; then
    printf 'wp_siteurl\t%s\n' "$(cd "$DOCROOT" && wp option get siteurl --skip-plugins --skip-themes 2>/dev/null)"
    printf 'wp_home\t%s\n'    "$(cd "$DOCROOT" && wp option get home    --skip-plugins --skip-themes 2>/dev/null)"
    printf 'wp_posts\t%s\n'   "$(cd "$DOCROOT" && wp post list --post_type=post --post_status=publish --format=count --skip-plugins --skip-themes 2>/dev/null)"
    printf 'wp_pages\t%s\n'   "$(cd "$DOCROOT" && wp post list --post_type=page --post_status=publish --format=count --skip-plugins --skip-themes 2>/dev/null)"
  fi
}

# --------------------------------------------------------------- snapshot ---
if [ -n "$SNAP" ]; then
  case "$SNAP" in avant|apres) ;; *) die "--snapshot attend « avant » ou « apres »" ;; esac
  F="$WORK/etat-$SNAP.tsv"
  title "Relevé « $SNAP » — $DOMAIN"
  releve > "$F"
  ok "$(wc -l < "$F") mesure(s) → $F"

  if [ "$SNAP" = "apres" ] && [ -r "$WORK/etat-avant.tsv" ]; then
    title "Écarts avant → après"
    # Comparaison en awk : la clé d'une ligne « http » comprend l'URL testée,
    # sinon deux mesures différentes se confondraient.
    # Un seul passage awk : il émet les écarts, puis leur nombre en dernière ligne.
    # La clé d'une ligne « http » comprend l'URL testée, sans quoi les trois
    # mesures se confondraient.
    rapport=$(awk -F'\t' '
      function k()        { return ($1 ~ /^(http|sous_)/) ? $1 FS $2 : $1 }
      function v(  i,s,d) { d=($1 ~ /^(http|sous_)/)?3:2; s="";
                            for(i=d;i<=NF;i++) s=s (i>d?" ":"") $i; return s }
      $1=="poids_ko"      { next }
      NR==FNR             { a[k()]=v(); next }
                          { key=k(); seen[key]=1;
                            if (!(key in a))      { printf "  %s\n      avant : <non relevé>\n      après : %s\n", key, v(); n++ }
                            else if (a[key]!=v()) { printf "  %s\n      avant : %s\n      après : %s\n", key, a[key], v(); n++ } }
      END                 { for (key in a) if (!(key in seen))
                              { printf "  %s\n      avant : %s\n      après : <plus mesurable>\n", key, a[key]; n++ }
                            printf "ECARTS=%d\n", n+0 }
    ' "$WORK/etat-avant.tsv" "$F")

    printf '%s\n' "$rapport" | grep -v '^ECARTS=' || true
    ecarts=$(printf '%s\n' "$rapport" | sed -n 's/^ECARTS=//p')

    if [ "${ecarts:-0}" = "0" ]; then
      ok "aucun écart — le site répond comme avant la bascule"
    else
      warn "$ecarts écart(s) ci-dessus. Tous ne sont pas anormaux : l'émetteur du"
      warn "certificat change si AutoSSL vient de le réémettre. En revanche un MX,"
      warn "un SPF ou un DKIM disparu doit être corrigé immédiatement."
    fi

    a_ko=$(awk -F'\t' '$1=="poids_ko"{print $2}' "$WORK/etat-avant.tsv")
    b_ko=$(awk -F'\t' '$1=="poids_ko"{print $2}' "$F")
    if [ -n "${a_ko:-}" ] && [ -n "${b_ko:-}" ] && [ "${a_ko:-0}" -gt 0 ]; then
      d=$(( (b_ko - a_ko) * 100 / a_ko )); d=${d#-}
      if [ "$d" -gt 20 ]; then
        warn "page d'accueil : ${a_ko} Ko avant, ${b_ko} Ko après (${d} % d'écart)"
      else
        ok "page d'accueil de poids comparable (${a_ko} → ${b_ko} Ko)"
      fi
    fi
  fi
  exit 0
fi

# ------------------------------------------------------- contrôle ponctuel --
title "Contrôles — $DOMAIN"
releve | while IFS=$'\t' read -r k a b; do
  case "$k" in
    http|sous_http)  code="${b%% *}"
           case "$code" in
             2*|3*) ok  "$a → $b" ;;
             *)     err "$a → $b" ;;
           esac ;;
    *)     log "$k : $a $b" ;;
  esac
done

if [ -n "$DOCROOT" ]; then
  [ -d "$DOCROOT" ] && ok "racine présente : $DOCROOT" || err "racine absente : $DOCROOT"
  if [ -r "$DOCROOT/wp-config.php" ]; then
    perms="$(stat -c '%a' "$DOCROOT/wp-config.php" 2>/dev/null)"
    [ "$perms" = "600" ] || [ "$perms" = "640" ] \
      && ok "wp-config.php en $perms" \
      || warn "wp-config.php en $perms — préférez 600"
  fi
  [ -f "$DOCROOT/.maintenance" ] && err "le site est encore en mode maintenance (.maintenance présent)"
fi

crons=$(crontab -l 2>/dev/null | grep -cvE '^[[:space:]]*(#|$)' || true); crons=${crons:-0}
log "tâches cron sur ce compte : $crons"
[ "$crons" = "0" ] && warn "aucune tâche cron ici — vérifiez qu'aucune n'était définie sur la lune source"
