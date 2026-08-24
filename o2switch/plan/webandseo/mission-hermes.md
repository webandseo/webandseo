# Mission — cloisonner 23 sites o2switch sur 4 lunes

## L'objectif

23 sites cohabitent aujourd'hui dans le compte cPanel `webandseo`, sur le
serveur `canard.o2switch.net`. Une seule compromission les expose tous. Quatre
lunes (sous-comptes cPanel isolés) ont été créées pour cloisonner.

**18 sites sont à déplacer.** Les 5 autres restent où ils sont.

Tu as l'accès cPanel, ce qui te permet de mener l'opération de bout en bout.
Un outillage a été préparé pour absorber la partie répétitive ; il est décrit
plus bas et il est testé, mais il n'a **jamais tourné contre cet hébergement**.
Traite le premier site comme une répétition, pas comme une migration.

## Répartition à appliquer

| Compte cible | Sites | Action |
|---|---|---|
| `webandseo` *(principal)* | `123loterie.com`, `despras.fr`, `domaine-chignard.fr`, `entretienauto.fr`, `etudiantenfrance.com` | **aucune** — ils y sont déjà |
| `sc1webandseo` | `guideregime.com`, `je-dois-reussir.com`, `jeanlouismahe.com`, `kolectou.com`, `leblogweb.fr` | 5 migrations |
| `sc2webandseo` | `ma-moto.net`, `ma-voiture.net`, `melimarie.fr`, `meuble.org` | 4 migrations |
| `sc3webandseo` | `plateaubriard.fr`, `prorecyclage.com`, `top-maison.net`, `tresorsinutiles.com` | 4 migrations |
| `sc4webandseo` | `troizenfants.fr`, `valdissole.fr`, `whiteref.com`, `whiteref.net`, `yves-simon.com` | 5 migrations |

Cette répartition est arrêtée. Ne la modifie pas de ta propre initiative :
si l'inventaire fait apparaître un problème (voir « Quand t'arrêter »),
remonte-le plutôt que de réorganiser.

## Étape 0 — inventaire, avant de toucher à quoi que ce soit

Trois points sont désormais établis, et ils simplifient beaucoup :

- **Aucun de ces 23 domaines n'héberge de boîte email.** Rien à migrer de ce
  côté — mais lis quand même le piège n° 3 plus bas, il en reste un.
- **Un seul sous-domaine est concerné** : `blog.whiteref.com`. Voir la section
  dédiée, c'est le cas le plus délicat des 18.
- **Un site passe par un CDN** : `je-dois-reussir.com`, via le CNAME
  `cdn.je-dois-reussir.com` (KeyCDN). Section dédiée également.

Restent à établir, pour chacun des 18 sites : son poids, sa base, sa version de
PHP, et si ses DNS sont gérés par o2switch ou ailleurs (Cloudflare, registrar).

En SSH sur `webandseo` :

```sh
cd ~ && git clone https://github.com/webandseo/webandseo.git o2s-outils
cd o2s-outils/o2switch/bin && chmod +x *.sh
./o2s-inventaire.sh
```

Le script est en lecture seule. Il produit un `sites.tsv` avec tout ça.
**Remonte-le avant de démarrer la première migration.**

## Ce qui est automatisé, et ce qui ne l'est pas

Un domaine ne peut pas exister sur deux comptes cPanel du même serveur en même
temps. Le déplacement impose donc de le **retirer** du compte de départ avant
de pouvoir l'**ajouter** sur celui d'arrivée. Ni cPanel ni o2switch ne
proposent cette bascule en une opération : c'est deux manipulations
manuelles, et c'est la seule coupure.

Tout le reste est scripté. La stratégie consiste à **tout préparer pendant que
le site tourne**, pour que la fenêtre entre suppression et ajout se réduise à
la minute nécessaire aux deux clics.

Les lunes partagent le serveur : les transferts se font de disque à disque, en
local. Lance donc les scripts **en SSH sur le compte source**, jamais depuis
un poste distant.

## Prérequis, une seule fois

1. **Autorisation SSH** : cPanel → `Sécurité` → `Autorisation SSH`, déclarer
   ton IP. Sur `webandseo` **et** sur les quatre lunes.
2. **Clé SSH de `webandseo` vers chaque lune.** Depuis `webandseo` :
   ```sh
   ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519 && cat ~/.ssh/id_ed25519.pub
   ```
   Puis dans le cPanel de **chacune** des 4 lunes :
   `Sécurité` → `Accès SSH` → `Gérer les clés SSH` → `Importer une clé`,
   coller, et surtout cliquer sur **Autoriser** — une clé importée mais non
   autorisée ne sert à rien.
3. **Installer l'outillage sur chaque lune aussi** (même `git clone`) : la
   phase `finaliser` s'exécute côté destination.
4. **Vérifier** :
   ```sh
   ./o2s-migrer.sh --domaine guideregime.com --dst-user sc1webandseo --phase check
   ```
   Si la connexion échoue alors que la clé est autorisée, le shell cloisonné
   n'accepte peut-être pas `localhost` : teste
   `ssh sc1webandseo@canard.o2switch.net`, et si c'est cette forme qui répond,
   ajoute `--dst-host canard.o2switch.net` à toutes les commandes.

## Procédure, pour chaque site

Génère les commandes exactes plutôt que de les taper :

```sh
./o2s-plan.sh --csv ../plan/webandseo/inventaire.csv                     # les 18
./o2s-plan.sh --csv ../plan/webandseo/inventaire.csv --lune sc1webandseo  # une lune
```

**Attention à la feuille** : deux hébergements sont décrits dans `plan/`, se
tromper viserait les mauvais comptes. `--csv` est devenu obligatoire pour cette
raison — il n'y a plus de feuille par défaut.

Le schéma est toujours le même :

**La veille — aucune coupure, le site tourne**
```sh
./o2s-verif.sh  --domaine SITE --snapshot avant
./o2s-migrer.sh --domaine SITE --dst-user LUNE --phase precopy --go
```
À l'issue de cette phase, la lune contient une copie complète du site et de sa
base, `wp-config.php` recâblé. Le domaine pointe toujours sur `webandseo` :
rien n'a changé pour les visiteurs. C'est l'étape longue, prends ton temps.

Ouvre ensuite le relevé DNS produit dans `~/o2s-migration/SITE/dns/` et repère
ce qui devra être ressaisi.

**Jour J — la bascule**
```sh
./o2s-migrer.sh --domaine SITE --dst-user LUNE --phase delta --gel --go
```
`--gel` met le site source en maintenance avant de resynchroniser : aucune
écriture ne peut être perdue entre le dump et la bascule. Quelques secondes.

Puis dans cPanel, dans cet ordre :
1. `webandseo` → `Domaines` → SITE → **Supprimer**
2. LUNE → `Domaines` → **Créer un domaine**, racine `/home/LUNE/SITE`
3. LUNE → `Éditeur de zone` → ressaisir les enregistrements relevés
4. LUNE → `SSL/TLS Status` → **Exécuter AutoSSL**

**Puis, sur la lune**
```sh
./o2s-migrer.sh --domaine SITE --dst-user LUNE --src-user webandseo \
                --phase finaliser --reecrire-chemins --go
./o2s-verif.sh  --domaine SITE --snapshot apres
```
Le relevé « après » est comparé au « avant » et n'affiche que les écarts.

## Les quatre pièges

**1. Retirer un domaine détruit sa zone DNS.** En le recréant sur la lune,
cPanel régénère une zone *par défaut* : MX, SPF, DKIM, DMARC, CAA et
vérifications de propriété disparaissent. Le piège, c'est que **le site
remarche normalement** — la panne se manifeste deux heures plus tard, quand
les emails cessent de partir. `o2s-dns-save.sh` relève la zone avant
l'opération (la phase `precopy` le fait automatiquement). Sans objet pour les
domaines en DNS externe.

**2. Le certificat SSL ne suit pas.** Il appartient au compte cPanel. Lance
AutoSSL immédiatement après avoir ajouté le domaine. Si le site est derrière
Cloudflare en mode proxy, passe-le en `DNS only` le temps de la validation.

**3. Les emails : aucune boîte, mais la zone reste à restaurer.** Il n'y a pas
de boîte à migrer, donc rien à transférer. Attention au raccourci : l'absence
de boîtes ne veut pas dire que la zone ne contient ni MX, ni SPF, ni DKIM, ni
DMARC. Ces enregistrements servent au **courrier sortant** — formulaires de
contact, notifications WordPress, mails transactionnels — et à la réputation du
domaine. Ressaisis tout ce que le relevé montre, sans trier.

**4. Un sous-domaine ne peut pas quitter son domaine principal.** Il reste sur
la même lune, obligatoirement. Et surtout : **supprimer un domaine supprime
tous ses sous-domaines avec lui.** C'est ce qui rend `whiteref.com` particulier.

## Deux sites demandent un traitement particulier

### `whiteref.com` — trois hôtes qui partent ensemble

Ce n'est pas un site mais une famille :

| Hôte | Rôle |
|---|---|
| `whiteref.com` et `www.whiteref.com` | redirection vers `https://www.leblogmarketing.fr` |
| `annuaire.whiteref.com` | redirection vers `https://www.leblogmarketing.fr` |
| `blog.whiteref.com` | le contenu réel |

**Supprimer `whiteref.com` du compte principal supprime aussi les deux
sous-domaines.** Les trois partent donc dans le même mouvement — vers
`sc4webandseo`, ce qui est déjà la lune prévue. Aucun conflit, mais trois
racines à pré-copier au lieu d'une.

**Avant tout : repère où sont implémentées les redirections.** Créées dans
cPanel → `Redirections`, elles sont stockées dans le compte et **ne suivront
pas** : à recréer à l'identique sur `sc4webandseo`. Écrites dans un
`.htaccess`, elles voyagent avec les fichiers. Vérifie avant, pas après.

Déroulé :

    # relevé DNS : une seule fois, sur le domaine parent — il sonde les sous-domaines
    ./o2s-dns-save.sh --domaine whiteref.com
    ./o2s-verif.sh --domaine whiteref.com --sous-domaines blog,annuaire --snapshot avant

    # pré-copie : un appel par hôte. Ajoute --no-wp sur ceux qui ne portent
    # qu'une redirection, ils n'ont ni WordPress ni base.
    ./o2s-migrer.sh --domaine whiteref.com          --dst-user sc4webandseo --phase precopy --go
    ./o2s-migrer.sh --domaine blog.whiteref.com     --dst-user sc4webandseo --phase precopy --go
    ./o2s-migrer.sh --domaine annuaire.whiteref.com --dst-user sc4webandseo --phase precopy --go

    # delta sur les trois, juste avant la bascule
    ./o2s-migrer.sh --domaine whiteref.com          --dst-user sc4webandseo --phase delta --gel --go
    ./o2s-migrer.sh --domaine blog.whiteref.com     --dst-user sc4webandseo --phase delta --gel --go
    ./o2s-migrer.sh --domaine annuaire.whiteref.com --dst-user sc4webandseo --phase delta --gel --go

Puis dans cPanel, **dans cet ordre** :

1. `webandseo` → supprimer `whiteref.com` (les sous-domaines partent avec)
2. `sc4webandseo` → créer le domaine `whiteref.com` **d'abord**
3. `sc4webandseo` → créer ensuite les sous-domaines `blog` et `annuaire`, avec
   les racines annoncées par les pré-copies
4. Recréer les redirections si elles étaient côté cPanel
5. Éditeur de zone : ressaisir le relevé
6. AutoSSL : vérifier qu'il couvre les **quatre** hôtes — `whiteref.com`,
   `www`, `blog`, `annuaire`

Enfin `finaliser` sur chacun des trois, puis :

    ./o2s-verif.sh --domaine whiteref.com --sous-domaines blog,annuaire --snapshot apres

### `je-dois-reussir.com` — CDN KeyCDN

La zone contient un CNAME :

    cdn.je-dois-reussir.com  ->  jedoisreussir-f692.kxcdn.com

Il vit dans la zone du domaine, disparaît avec elle, et **doit être ressaisi**
sur `sc1webandseo`. Sans lui, le CDN cesse de répondre alors que le site, lui,
marche parfaitement — le genre de panne qu'on met une demi-journée à voir.

> **`cdn` est un enregistrement DNS, pas un sous-domaine cPanel.** Il n'a pas
> de racine web : rien à pré-copier, rien à créer dans `Domaines`. Il se
> ressaisit uniquement dans l'**Éditeur de zone**, en CNAME.
>
> Le créer comme sous-domaine cPanel produirait un enregistrement A vers le
> serveur, qui empêcherait le CNAME d'exister. Le site continuerait de
> fonctionner, mais servirait ses fichiers depuis l'origine, CDN contourné —
> sans rien casser de visible.

Côté KeyCDN, rien à modifier : l'origine reste `je-dois-reussir.com` et l'IP du
serveur ne change pas. Deux précautions quand même :

- **Purge la zone KeyCDN juste après la bascule.** Le mode maintenance de
  `--gel` renvoie un 503, qu'un CDN ne met normalement pas en cache — mais une
  page de maintenance figée dans un cache est le genre d'incident qu'on préfère
  éviter que diagnostiquer.
- Entre la suppression et la recréation du domaine, l'origine n'a plus
  d'enregistrement A. Un *pull* du CDN pendant cette fenêtre peut échouer.
  Raison de plus pour enchaîner les deux clics sans traîner.

Relevés avant et après avec le nom d'hôte du CDN :

    ./o2s-verif.sh --domaine je-dois-reussir.com --sous-domaines cdn --snapshot avant

## Règles de sûreté

- **Ne supprime jamais rien sur `webandseo`.** Les scripts ne le font pas ;
  ne le fais pas non plus. Les fichiers et bases y restent intacts après la
  bascule : c'est le filet.
- **Retour arrière** : retirer le domaine de la lune, le recréer sur
  `webandseo` avec sa racine d'avant, et supprimer le fichier `.maintenance`
  à la racine. Le site repart identique.
- Les scripts **simulent par défaut**. Lance chaque commande une première fois
  sans `--go` et lis ce qu'elle annonce avant d'exécuter.
- **Ne fais pas le ménage sur `webandseo`** avant plusieurs jours de
  fonctionnement normal, emails et tâches cron vérifiés.
- `--reecrire-chemins` exige `--src-user webandseo`. Ne le retire pas.

## Ordre d'exécution

1. **Un seul site d'abord**, le plus léger d'après l'inventaire, en évitant
   `whiteref.com` et `je-dois-reussir.com`. Il valide la clé SSH, la bascule,
   AutoSSL, et donne le vrai chronomètre. Compte une heure.
   **Arrête-toi là et fais un point.**
2. Ensuite les 15 sites ordinaires, du plus léger au plus lourd. 15 à
   20 minutes chacun une fois la procédure rodée.
3. Puis `je-dois-reussir.com`, avec la purge KeyCDN.
4. **`whiteref.com` en dernier**, à heure creuse : c'est le seul cas à trois
   hôtes, et le seul où une erreur d'ordre dans cPanel coûte cher.

N'enchaîne pas les 18 d'un bloc. Chaque bascule mérite ses quinze minutes
d'attention.

## Le lendemain de chaque migration

- Recréer les **tâches cron** relevées (`~/o2s-migration/SITE/crontab-source.txt`)
- Vérifier la **version de PHP** et ses extensions sur la lune
- Purger les caches du site et du CDN
- Contrôler la Search Console et les logs d'erreur à 24 h

## Quand t'arrêter et demander

- L'inventaire révèle un **sous-domaine** ailleurs que sur `whiteref.com` : la
  répartition n'en tient pas compte, remonte-le avant de déplacer le domaine
  parent.
- L'inventaire révèle une **boîte email** quelque part : cela contredit ce qui
  a été annoncé, arrête-toi.
- Les redirections de `whiteref.com` ne sont **ni dans cPanel ni dans un
  `.htaccess`** (plugin WordPress, ou autre) : dis-le avant de basculer.
- L'inventaire révèle un **site nettement plus gros ou plus sensible** que les
  autres (boutique, paiement, comptes utilisateurs) : la répartition a été
  faite par ordre alphabétique, sans critère de risque. Signale-le avant de le
  déplacer.
- `o2s-verif.sh --snapshot apres` signale un **MX, SPF, DKIM ou DMARC
  disparu** : corrige immédiatement dans l'Éditeur de zone, avant de passer au
  site suivant.
- La connexion SSH entre comptes ne s'établit ni par `localhost` ni par le nom
  du serveur : ne cherche pas de contournement, remonte-le.

## À me remonter

- Le `sites.tsv` de l'inventaire, **avant** la première migration
- Où sont implémentées les redirections de `whiteref.com`
- Après le premier site : le temps réel, et ce qui a coincé
- Après chaque site : la sortie de `o2s-verif.sh --snapshot apres`
- Un point global une fois les 18 faits, avec ce qui reste à finir

## Références

- Outillage et runbook détaillé : `o2switch/README.md` du dépôt
  `webandseo/webandseo`, branche `claude/o2switch-sites-distribution-f3ws7q`
- Critères de répartition : `o2switch/plan/methode.md`
- Répartition de ce compte : `o2switch/plan/webandseo/repartition.md`
- Guide officiel o2switch :
  <https://faq.o2switch.fr/guides/migrations/deplacer-site-hebergement-o2switch/>
  — à recouper, il n'a pas pu être consulté lors de la préparation.
