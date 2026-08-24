# Mission — cloisonner 10 sites o2switch sur 4 lunes (compte `elyes7`)

## L'objectif

10 sites cohabitent dans le compte cPanel `elyes7`. Une seule compromission
les expose tous. Quatre lunes (sous-comptes cPanel isolés) ont été créées pour
cloisonner.

**8 sites sont à déplacer.** Les 2 autres restent où ils sont.

C'est la quatrième fois : les comptes `webandseo`, `qvle6290` et `trlh2564`
sont déjà migrés, avec le même outillage. Et c'est de loin le plus court —
**aucun sous-domaine, aucune boîte email, aucun cas particulier.** 8 sites
ordinaires, la même séquence répétée huit fois.

Deux sites par lune seulement : c'est le cloisonnement le plus serré des quatre
hébergements. Une compromission n'exposerait qu'un seul voisin.

## Répartition à appliquer

| Compte cible | Sites | Action |
|---|---|---|
| `elyes7` *(principal)* | `acheterdesactions.fr`, `actejuridique.fr` | **aucune** — ils y sont déjà |
| `sc1elyes7` | `amenagements.net`, `bricoler.net` | 2 migrations |
| `sc2elyes7` | `damejeanne.fr`, `disqueuse.net` | 2 migrations |
| `sc3elyes7` | `maisonoptimale.fr`, `nourdegypte.com` | 2 migrations |
| `sc4elyes7` | `pacteassocies.fr`, `reparer.eu` | 2 migrations |

Répartition arrêtée. Ne la modifie pas de ta propre initiative.

## Étape 0 — inventaire

En SSH sur `elyes7` :

    cd ~ && git clone https://github.com/webandseo/webandseo.git o2s-outils
    cd o2s-outils/o2switch/bin && chmod +x *.sh
    hostname -f          # relève le serveur de ce compte, il servira plus bas
    ./o2s-inventaire.sh

Le script est en lecture seule. Il donne le poids, la base, la version de PHP
et la racine web de chaque site — de quoi établir l'ordre de passage, du plus
léger au plus lourd.

**Remonte le `sites.tsv` et le nom du serveur avant de démarrer**, puis
complète `plan/elyes7/inventaire.csv` avec les tailles : c'est ce qui rend
juste l'ordre proposé par le générateur de commandes.

## Ce qui est automatisé, et ce qui ne l'est pas

Un domaine ne peut pas exister sur deux comptes cPanel du même serveur en même
temps. Le déplacement impose donc de le **retirer** du compte de départ avant de
pouvoir l'**ajouter** sur celui d'arrivée. Ni cPanel ni o2switch ne proposent
cette bascule en une opération : deux manipulations manuelles, et c'est la seule
coupure.

Tout le reste est scripté. La stratégie consiste à **tout préparer pendant que
le site tourne**, pour réduire la fenêtre aux deux clics.

Les cinq comptes cohabitent sur la même machine : les transferts se font de
disque à disque, en local. Lance donc les scripts **en SSH sur `elyes7`**,
jamais depuis un poste distant.

## Prérequis, une seule fois

1. **Autorisation SSH** : cPanel → `Sécurité` → `Autorisation SSH`, déclarer ton
   IP. Sur `elyes7` **et** sur les quatre lunes.
2. **Clé SSH de `elyes7` vers chaque lune.** Depuis `elyes7` :

       ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519 && cat ~/.ssh/id_ed25519.pub

   Puis dans le cPanel de **chacune** des 4 lunes : `Sécurité` → `Accès SSH` →
   `Gérer les clés SSH` → `Importer une clé`, coller, et surtout cliquer sur
   **Autoriser** — une clé importée mais non autorisée ne sert à rien.
3. **Installer l'outillage sur chaque lune aussi** (même `git clone`) : la phase
   `finaliser` s'exécute côté destination.
4. **Vérifier** :

       ./o2s-migrer.sh --domaine amenagements.net --dst-user sc1elyes7 --phase check

   Si la connexion échoue alors que la clé est autorisée, le shell cloisonné
   n'accepte peut-être pas `localhost` : teste `ssh sc1elyes7@<serveur>` avec
   le nom relevé par `hostname -f`. Si c'est cette forme qui répond, ajoute
   `--dst-host <serveur>` à toutes les commandes.

## Procédure, pour chaque site

Génère les commandes plutôt que de les taper. **Attention à la feuille : deux
hébergements sont décrits dans `plan/`, se tromper viserait les mauvais
comptes.**

    ./o2s-plan.sh --csv ../plan/elyes7/inventaire.csv                     # les 8
    ./o2s-plan.sh --csv ../plan/elyes7/inventaire.csv --lune sc1elyes7  # une lune

**La veille — aucune coupure, le site tourne**

    ./o2s-verif.sh  --domaine SITE --snapshot avant
    ./o2s-migrer.sh --domaine SITE --dst-user LUNE --phase precopy --go

À l'issue de cette phase, la lune contient une copie complète du site et de sa
base, `wp-config.php` recâblé. Le domaine pointe toujours sur `elyes7` : rien
n'a changé pour les visiteurs. C'est l'étape longue, prends ton temps.

Ouvre ensuite le relevé DNS produit dans `~/o2s-migration/SITE/dns/` et repère
ce qui devra être ressaisi.

**Jour J — la bascule**

    ./o2s-migrer.sh --domaine SITE --dst-user LUNE --phase delta --gel --go

`--gel` met le site source en maintenance avant de resynchroniser : aucune
écriture ne peut être perdue entre le dump et la bascule. Quelques secondes.

Puis dans cPanel, dans cet ordre :

1. `elyes7` → `Domaines` → SITE → **Supprimer**
2. LUNE → `Domaines` → **Créer un domaine**, racine `/home/LUNE/SITE`
3. LUNE → `Éditeur de zone` → ressaisir les enregistrements relevés
4. LUNE → `Sécurité` → **`Let's Encrypt™ SSL`** → **Générer** le certificat
   (voir la section suivante, c'est l'étape à ne pas repousser)

**Puis, sur la lune**

    ./o2s-migrer.sh --domaine SITE --dst-user LUNE --src-user elyes7 \
                    --phase finaliser --reecrire-chemins --go
    ./o2s-verif.sh  --domaine SITE --snapshot apres

Le relevé « après » est comparé au « avant » et n'affiche que les écarts.

## Les certificats SSL — à faire dans la foulée, pas plus tard

**Un certificat appartient au compte cPanel, il ne suit pas le domaine.** Dès
que le site est ajouté sur la lune, il n'a plus aucun certificat valide : le
navigateur affiche un avertissement de sécurité en pleine page.

Et c'est pire que « le site n'est pas en HTTPS ». La quasi-totalité des
WordPress forcent HTTPS, par `.htaccess` ou par extension — et ce `.htaccess`
a voyagé avec les fichiers. Le site redirige donc vers un HTTPS cassé :
**concrètement il est inaccessible**, pas simplement dégradé. Génère le
certificat immédiatement après avoir ajouté le domaine, pas en fin de journée.

### La marche à suivre

Sur la lune de destination : `Sécurité` → **`Let's Encrypt™ SSL`** → repérer le
domaine dans la liste → **Générer**.

Trois points de vigilance :

- **Coche `domaine.tld` et `www.domaine.tld`.** Un certificat qui ne couvre que
  l'un des deux laisse l'autre en erreur, et les visiteurs arrivent sur les deux.
- **Décoche les sous-domaines techniques** — tout ce qui se termine par
  `.odns.fr`, `.o2switch.net` ou `.universe.wf`. o2switch le documente
  explicitement : leur présence fait **échouer la demande entière**, et l'échec
  n'est pas toujours lisible.
- **Ne compte pas sur AutoSSL pour aller vite.** o2switch finit par installer
  un Let's Encrypt automatiquement sur tous les domaines, mais il attend la
  propagation DNS et peut mettre des heures. Sur une bascule, la génération
  manuelle est immédiate : c'est elle qu'on veut.

L'émission demande que le domaine résolve déjà vers le serveur. C'est le cas
tout de suite ici : l'IP ne change pas d'un compte à l'autre, seul le compte
propriétaire change. Aucune attente de propagation à prévoir.

Les certificats Let's Encrypt sont valables 90 jours et o2switch les renouvelle
ensuite automatiquement. Rien à planifier de ce côté.

### Contrôle de fin de campagne

Une fois les 8 sites déplacés, vérifie qu'aucun certificat n'est passé à la
trappe. Depuis n'importe quel compte :

    for d in $(awk -F, 'NR>1 && $14 ~ /^sc/ {print $1}' ../plan/elyes7/inventaire.csv); do
      printf '%-32s ' "$d"
      echo | openssl s_client -servername "$d" -connect "$d:443" 2>/dev/null \
        | openssl x509 -noout -issuer -enddate 2>/dev/null || echo "AUCUN CERTIFICAT"
    done

Les 8 lignes doivent afficher un émetteur Let's Encrypt et une date
d'expiration à environ 90 jours. Toute ligne vide ou marquée `AUCUN CERTIFICAT`
est un site en erreur de sécurité pour ses visiteurs : à traiter tout de suite.

## Les autres pièges

**Retirer un domaine détruit sa zone DNS.** C'est le piège principal, et il
reste entier. En recréant le domaine sur la lune, cPanel régénère une zone *par
défaut* : tout ce qui avait été ajouté à la main disparaît — SPF, DKIM, DMARC,
CAA, vérifications de propriété, CNAME. Le piège, c'est que **le site remarche
normalement** : rien ne signale la perte.

L'absence de boîtes email ne met pas à l'abri. Un site sans boîte peut très bien
avoir un SPF et un DKIM, qui servent au courrier **sortant** — formulaires de
contact, notifications WordPress, mails transactionnels. Les perdre, c'est voir
ces messages finir en spam, sans erreur visible nulle part.

`o2s-dns-save.sh` relève la zone avant l'opération, et la phase `precopy` le
fait automatiquement. **Ressaisis tout ce que le relevé montre, sans trier.**

**Deux garde-fous, même s'ils ne devraient pas servir ici.** Il a été confirmé
qu'aucun de ces 10 domaines n'a de sous-domaine ni de boîte email. Si
l'inventaire en révèle malgré tout un, arrête-toi : supprimer un domaine
supprime tous ses sous-domaines avec lui, et une boîte email demande de
transférer `mail/SITE` et `etc/SITE` en plus du reste.

## Règles de sûreté

- **Ne supprime jamais rien sur `elyes7`.** Les scripts ne le font pas ; ne le
  fais pas non plus. Les fichiers et bases y restent intacts après la bascule :
  c'est le filet.
- **Retour arrière** : retirer le domaine de la lune, le recréer sur `elyes7`
  avec sa racine d'avant, et supprimer le fichier `.maintenance` à la racine. Le
  site repart identique.
- Les scripts **simulent par défaut**. Lance chaque commande une première fois
  sans `--go` et lis ce qu'elle annonce avant d'exécuter.
- **Ne fais pas le ménage sur `elyes7`** avant plusieurs jours de
  fonctionnement normal, tâches cron vérifiées.
- `--reecrire-chemins` exige `--src-user elyes7`. Ne le retire pas.

## Ordre d'exécution

1. **Un seul site d'abord**, le plus léger d'après l'inventaire. Il valide la
   clé SSH, la bascule, la génération du certificat, et donne le vrai
   chronomètre. Compte une heure. **Arrête-toi là et fais un point.**
2. Ensuite les 7 autres, du plus léger au plus lourd. 15 à 20 minutes chacun
   une fois la procédure rodée.
3. Les plus visités en dernier, à heure creuse.

N'enchaîne pas les 8 d'un bloc. Chaque bascule mérite ses quinze minutes
d'attention.

## Le lendemain de chaque migration

- Recréer les **tâches cron** relevées (`~/o2s-migration/SITE/crontab-source.txt`)
- Vérifier la **version de PHP** et ses extensions sur la lune
- Purger les caches du site
- Contrôler la Search Console et les logs d'erreur à 24 h

## Quand t'arrêter et demander

- L'inventaire révèle un **sous-domaine** ou une **boîte email** : cela
  contredit ce qui a été confirmé, arrête-toi.
- Un certificat Let's Encrypt **refuse d'être généré** après deux tentatives :
  ne laisse pas le site en erreur de sécurité, remonte-le.
- `o2s-verif.sh --snapshot apres` signale un **SPF, DKIM, DMARC ou MX disparu** :
  corrige immédiatement dans l'Éditeur de zone, avant de passer au site suivant.
- L'inventaire révèle un site **nettement plus gros ou plus sensible** que ses
  voisins de lune : la répartition a été faite par ordre alphabétique, sans
  critère de risque.
- La connexion SSH entre comptes ne s'établit ni par `localhost` ni par le nom
  du serveur : ne cherche pas de contournement, remonte-le.

## À me remonter

- Le nom du serveur (`hostname -f`) et le `sites.tsv` de l'inventaire, **avant**
  toute migration
- Après le premier site : le temps réel, et ce qui a coincé
- Après chaque site : la sortie de `o2s-verif.sh --snapshot apres`
- **Le contrôle SSL de fin de campagne**, les 8 lignes
- Un point global une fois les 8 faits, avec ce qui reste à finir

## Références

Dépôt `webandseo/webandseo`, branche `claude/o2switch-sites-distribution-f3ws7q` :

- `o2switch/README.md` — runbook détaillé
- `o2switch/plan/methode.md` — critères de répartition
- `o2switch/plan/elyes7/repartition.md` — la répartition de ce compte

Documentation o2switch :
[Let's Encrypt, certificat SSL gratuit](https://faq.o2switch.fr/cpanel/securite/lets-encrypt-ssl-gratuit/) ·
[Déplacer un site d'un hébergement à un autre](https://faq.o2switch.fr/guides/migrations/deplacer-site-hebergement-o2switch/)
