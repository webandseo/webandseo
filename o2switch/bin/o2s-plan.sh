#!/usr/bin/env bash
#
# o2s-plan.sh — transforme la feuille de répartition en commandes prêtes à
# copier-coller, et contrôle la cohérence du plan avant qu'on y touche.
#
#   ./o2s-plan.sh --csv ../plan/inventaire.csv
#   ./o2s-plan.sh --csv ../plan/inventaire.csv --lune sc1webandseo
#
# Sur 23 sites, le risque n'est pas de rater une commande : c'est d'en taper
# une avec le mauvais nom de lune. Autant les générer.
#
# Colonnes attendues (voir plan/inventaire.csv) :
#   1 domaine  2 lune_actuelle  3 racine_web  4 cms  5 base  6 php  7 taille_mo
#   8 emails  9 dns_externe  10 sous_domaines  11 valeur  12 risque
#   13 lune_cible  14 notes
#
# Le séparateur est la virgule : n'en mettez pas dans les champs, notes comprises.
#
set -uo pipefail
cd -- "$(dirname -- "$0")" || exit 1
. ./o2s-lib.sh

CSV="../plan/inventaire.csv" FILTRE="" SRC_DEFAUT="webandseo"
while [ $# -gt 0 ]; do
  case "$1" in
    --csv)   CSV="${2:-}";        shift 2 ;;
    --lune)  FILTRE="${2:-}";     shift 2 ;;
    --src-user) SRC_DEFAUT="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) die "option inconnue : $1" ;;
  esac
done
[ -r "$CSV" ] || die "feuille illisible : $CSV"

# ------------------------------------------------------------- cohérence ----
title "Contrôle du plan"

awk -F',' -v OFS=' ' '
  NR==1 { next }
  $1 ~ /^[[:space:]]*(#|$)/ { next }
  {
    dom=$1; val=$11+0; ris=$12+0; cible=$13
    gsub(/^[ \t]+|[ \t]+$/, "", cible); gsub(/^[ \t]+|[ \t]+$/, "", dom)
    if (dom=="") next
    total++
    actuelle=$2; gsub(/^[ \t]+|[ \t]+$/, "", actuelle)
    if (cible=="") { sans[++ns]=dom; next }
    n[cible]++; sites[cible]=sites[cible] " " dom
    if (cible == actuelle) { immobiles[++ni]=dom; next }
    bouge++
    if (ris>=3) risque3[cible]=risque3[cible] " " dom
    if (val>=3) valeur3[cible]=valeur3[cible] " " dom
    if (val==0) sansnote[++nn]=dom
  }
  END {
    printf "  %d site(s) dans la feuille, %d à déplacer\n", total, bouge+0
    for (l in n) printf "  %-16s %d site(s) :%s\n", l, n[l], sites[l]
    if (ni) { printf "\n  Déjà au bon endroit, aucune action (%d) :", ni
              for(i=1;i<=ni;i++) printf " %s", immobiles[i]; print "" }
    if (ns) { printf "\n  Sans lune cible (%d) :", ns; for(i=1;i<=ns;i++) printf " %s", sans[i]; print "" }
    if (nn) { printf "  Sans note de valeur (%d) :", nn; for(i=1;i<=nn;i++) printf " %s", sansnote[i]; print "" }

    # La règle qui justifie tout le cloisonnement : ce qui est le plus
    # probablement le point d\x27entrée ne partage pas sa lune avec ce dont la
    # perte coûte le plus cher.
    print ""
    for (l in n)
      if (risque3[l] != "" && valeur3[l] != "")
        printf "  ATTENTION  %s héberge à la fois du risque 3 (%s ) et de la valeur 3 (%s )\n", l, risque3[l], valeur3[l]
  }
' "$CSV"

# ------------------------------------------------------------- commandes ----
title "Commandes de migration"
cat <<'ORDRE'
  Ordre de passage : les sites sans email ni DNS externe d'abord, du plus
  léger au plus lourd, puis ceux qui portent des emails, et les sites à
  enjeu en dernier — quand la procédure est devenue routinière.

ORDRE

awk -F',' -v filtre="$FILTRE" -v src="$SRC_DEFAUT" '
  function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
  function nz(s)   { return (s == "") ? "~" : s }
  NR==1 { next }
  $1 ~ /^[[:space:]]*(#|$)/ { next }
  {
    dom=trim($1); cible=trim($13)
    if (dom=="" || cible=="") next
    src_user = (trim($2)=="" ? src : trim($2))
    if (cible == src_user) next          # ne bouge pas
    if (filtre != "" && cible != filtre) next
    # Priorité de passage : simple et léger avant complexe et lourd.
    p = 0
    if (trim($8) != "") p += 100          # porte des emails
    if (trim($9) != "") p += 50           # DNS gérés ailleurs
    p += (trim($11)+0) * 200              # valeur : les plus précieux en dernier
    p += int((trim($7)+0) / 500)          # taille, en paliers de 500 Mo
    # La tabulation est un séparateur « blanc » : `read` fusionne les
    # tabulations consécutives, donc une colonne vide décalerait toutes les
    # suivantes. On émet une sentinelle, retirée côté shell.
    printf "%09d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", p, dom, cible, src_user,
           nz(trim($11)), nz(trim($12)), nz(trim($8)), nz(trim($9)), nz(trim($10))
  }
' "$CSV" | sort -n | while IFS=$'\t' read -r _ dom cible src val ris mails dns sous; do
  for v in val ris mails dns sous; do
    eval "[ \"\$$v\" = \"~\" ] && $v=\"\""
  done
  printf '\n%s### %s  →  %s%s' "$C_D" "$dom" "$cible" "$C_RST"
  printf '   (valeur %s, risque %s' "${val:-?}" "${ris:-?}"
  [ -n "$mails" ] && [ "$mails" != "non" ] && printf ', emails'
  [ -n "$dns" ]   && printf ', DNS externe'
  [ -n "$sous" ]  && printf ', %s sous-domaine(s)' "$(printf '%s' "$sous" | wc -w | tr -d ' ')"
  printf ')\n'

  # Un domaine qui porte des sous-domaines les emporte à la suppression : ils
  # doivent être pré-copiés et recréés eux aussi, sinon ils disparaissent.
  opt_sous=""; liste_sous=""
  if [ -n "$sous" ]; then
    liste_sous="$(printf '%s' "$sous" | tr ' ' ',')"
    opt_sous=" --sous-domaines $liste_sous"
  fi

  printf '\n# --- la veille, sur %s (site en ligne, aucune coupure)\n' "$src"
  printf './o2s-verif.sh  --domaine %s%s --snapshot avant\n' "$dom" "$opt_sous"
  printf './o2s-migrer.sh --domaine %s --dst-user %s --phase precopy --go\n' "$dom" "$cible"
  for sd in $sous; do
    printf './o2s-migrer.sh --domaine %s.%s --dst-user %s --phase precopy --go\n' "$sd" "$dom" "$cible"
  done

  printf '\n# --- jour J, sur %s\n' "$src"
  printf './o2s-migrer.sh --domaine %s --dst-user %s --phase delta --gel --go\n' "$dom" "$cible"
  for sd in $sous; do
    printf './o2s-migrer.sh --domaine %s.%s --dst-user %s --phase delta --gel --go\n' "$sd" "$dom" "$cible"
  done
  printf '#   cPanel %s : Domaines > %s > Supprimer' "$src" "$dom"
  [ -n "$sous" ] && printf '  (emporte %s)' "$liste_sous"
  printf '\n'
  printf '#   cPanel %s : Créer un domaine > %s, racine /home/%s/%s\n' "$cible" "$dom" "$cible" "$dom"
  for sd in $sous; do
    printf '#   cPanel %s : puis créer le sous-domaine %s.%s\n' "$cible" "$sd" "$dom"
  done
  printf '#   Éditeur de zone de %s : ressaisir MX / SPF / DKIM / DMARC / CNAME\n' "$cible"
  printf '#   SSL/TLS Status de %s  : Exécuter AutoSSL' "$cible"
  [ -n "$sous" ] && printf '  (vérifier la couverture des sous-domaines)'
  printf '\n'

  printf '\n# --- puis sur %s\n' "$cible"
  printf './o2s-migrer.sh --domaine %s --dst-user %s --src-user %s \\\n' "$dom" "$cible" "$src"
  printf '                --phase finaliser --reecrire-chemins --go\n'
  for sd in $sous; do
    printf './o2s-migrer.sh --domaine %s.%s --dst-user %s --src-user %s \\\n' "$sd" "$dom" "$cible" "$src"
    printf '                --phase finaliser --reecrire-chemins --go\n'
  done
  printf './o2s-verif.sh  --domaine %s%s --snapshot apres\n' "$dom" "$opt_sous"

  [ -n "$mails" ] && [ "$mails" != "non" ] && printf '\n# Ce domaine porte des boîtes email : recréer les comptes sur %s,\n# puis transférer mail/%s et etc/%s.\n' "$cible" "$dom" "$dom"
  [ -n "$dns" ]   && printf '\n# DNS gérés hors o2switch : rien à ressaisir dans l\x27Éditeur de zone,\n# mais vérifier que l\x27enregistrement A pointe bien vers le serveur.\n'
done
