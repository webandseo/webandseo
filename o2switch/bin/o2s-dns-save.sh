#!/usr/bin/env bash
#
# o2s-dns-save.sh — sauvegarde la zone DNS d'un domaine AVANT de le retirer
# d'une lune.
#
#   ./o2s-dns-save.sh --domaine exemple.fr [--out RÉPERTOIRE]
#
# Pourquoi c'est indispensable : retirer un domaine d'un compte cPanel supprime
# aussi sa zone DNS. En le recréant sur la lune de destination, cPanel régénère
# une zone *par défaut*. Tout ce qui avait été ajouté à la main disparaît :
# MX (Google Workspace, Microsoft 365...), SPF, DKIM, DMARC, vérifications de
# propriété, sous-domaines pointant ailleurs, enregistrements CAA.
# C'est de très loin la première cause de casse sur ce type de migration, et
# ça se voit surtout 2 h plus tard quand les emails ne partent plus.
#
# Ne modifie rien. Trois sources sont tentées, de la plus fidèle à la plus
# approximative, et tout ce qui répond est conservé.
#
set -uo pipefail
cd -- "$(dirname -- "$0")" || exit 1
. ./o2s-lib.sh

DOMAIN="" OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --domaine|--domain) DOMAIN="${2:-}"; shift 2 ;;
    --out)              OUT="${2:-}";    shift 2 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) die "option inconnue : $1" ;;
  esac
done
[ -n "$DOMAIN" ] || die "--domaine est obligatoire"

OUT="${OUT:-$(o2s_home)/o2s-migration/$DOMAIN/dns}"
mkdir -p "$OUT" || die "impossible de créer $OUT"
STAMP="$(o2s_ts)"

title "Sauvegarde DNS de $DOMAIN"

# -- 1. UAPI DNS::parse_zone (cPanel récent) : la source la plus fidèle ------
log "Source 1/3 : API cPanel (DNS::parse_zone)"
uapi_json DNS parse_zone "zone=$DOMAIN" > "$OUT/parse_zone-$STAMP.json"
if o2s_json zone < "$OUT/parse_zone-$STAMP.json" > "$OUT/zone-$STAMP.txt" 2>/dev/null \
   && [ -s "$OUT/zone-$STAMP.txt" ]; then
  ok "$(wc -l < "$OUT/zone-$STAMP.txt") enregistrement(s) → zone-$STAMP.txt"
else
  rm -f "$OUT/zone-$STAMP.txt"
  warn "parse_zone n'a rien renvoyé"
fi

# -- 2. cpapi2 ZoneEdit::fetchzone (API historique) --------------------------
log "Source 2/3 : API cPanel historique (ZoneEdit::fetchzone)"
if command -v cpapi2 >/dev/null 2>&1; then
  cpapi2 --output=json ZoneEdit fetchzone "domain=$DOMAIN" \
    > "$OUT/fetchzone-$STAMP.json" 2>/dev/null && ok "→ fetchzone-$STAMP.json" \
    || warn "fetchzone indisponible"
else
  warn "cpapi2 absent"
fi

# -- 3. Relevé DNS public : fonctionne toujours, même sans API --------------
log "Source 3/3 : relevé depuis les serveurs de noms faisant autorité"
if command -v dig >/dev/null 2>&1; then
  NS="$(dig +short NS "$DOMAIN" 2>/dev/null | head -n1)"
  [ -n "$NS" ] && log "serveur interrogé : $NS" || warn "aucun NS trouvé, on interroge le résolveur par défaut"
  AT="${NS:+@$NS}"

  # Les sous-domaines réellement déclarés dans cPanel sont ajoutés aux préfixes
  # sondés : une liste figée laisserait passer un « annuaire » ou un « cdn »,
  # et c'est précisément ce genre d'enregistrement qui disparaît sans bruit.
  SUBS="$(uapi_json DomainInfo domains_data format=hash | o2s_json domains \
    | awk -F'\t' -v suf=".$DOMAIN" '{ n=length(suf)
        if (length($1) > n && substr($1, length($1)-n+1) == suf)
          print substr($1, 1, length($1)-n) }' | sort -u | tr '\n' ' ')"
  [ -n "$SUBS" ] && log "sous-domaines déclarés : $SUBS"

  TYPES="SOA NS A AAAA MX TXT CAA CNAME"
  # Préfixes courants : services mail, sélecteurs DKIM des principaux
  # expéditeurs, sous-domaines habituels. Mieux vaut en interroger trop.
  PREFIXES="@ www mail smtp imap pop ftp cpanel webmail webdisk cpcalendars cpcontacts
            autodiscover autoconfig _dmarc _domainkey default._domainkey google._domainkey
            selector1._domainkey selector2._domainkey k1._domainkey k2._domainkey
            s1._domainkey s2._domainkey mail._domainkey dkim._domainkey smtp._domainkey
            zoho._domainkey mandrill._domainkey sendgrid._domainkey brevo._domainkey
            mailjet._domainkey mj._domainkey pm._domainkey _acme-challenge _mta-sts
            _smtp._tls blog shop boutique app api dev staging preprod recette m cdn
            img static assets news forum wiki docs admin portal client crm mail2 track
            annuaire directory files media video download support aide help
            $SUBS"

  {
    printf '; Relevé DNS de %s — %s\n' "$DOMAIN" "$(date)"
    printf '; Serveur interrogé : %s\n;\n' "${NS:-résolveur par défaut}"
    for p in $PREFIXES; do
      if [ "$p" = "@" ]; then fqdn="$DOMAIN"; else fqdn="$p.$DOMAIN"; fi
      for t in $TYPES; do
        # shellcheck disable=SC2086
        dig +noall +answer +time=3 +tries=1 $AT "$fqdn" "$t" 2>/dev/null
      done
    done
    printf ';\n; Sous-domaines déclarés dans cPanel :\n'
    uapi_json DomainInfo domains_data format=hash | o2s_json domains \
      | awk -F'\t' -v d="$DOMAIN" '$1 ~ d {print "; " $1 " -> " $2}'
  } | awk '!seen[$0]++' > "$OUT/releve-dns-$STAMP.txt"

  n=$(grep -cvE '^[[:space:]]*(;|$)' "$OUT/releve-dns-$STAMP.txt" || true)
  ok "$n enregistrement(s) relevé(s) → releve-dns-$STAMP.txt"
else
  warn "dig absent : relevé public impossible"
fi

chmod -R go-rwx "$OUT" 2>/dev/null || :

title "À vérifier maintenant, avant toute suppression de domaine"
cat <<'RAPPEL'
  1. Ouvrez le relevé et repérez ce qui n'est PAS reconstruit automatiquement
     par cPanel : MX, SPF (TXT v=spf1), DKIM (*._domainkey), DMARC (_dmarc),
     CAA, vérifications de propriété (google-site-verification, MS=...),
     et tout CNAME / A pointant vers un service externe.
  2. Ces enregistrements-là devront être ressaisis à la main dans
     l'Éditeur de zone de la lune de destination, juste après y avoir
     ajouté le domaine.
  3. Si le domaine utilise des DNS externes (Cloudflare, registrar...),
     la zone o2switch n'est pas utilisée : rien à ressaisir, mais vérifiez
     que l'enregistrement A pointe bien vers l'IP du serveur.
RAPPEL
echo
log "Fichiers : $OUT"
RECAP=$(ls -1 "$OUT" 2>/dev/null | tr '\n' ' ')
echo "    $RECAP"
