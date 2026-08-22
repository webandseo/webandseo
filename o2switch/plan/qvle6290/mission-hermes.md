# Mission — cloisonner 25 sites o2switch sur 4 lunes (compte `qvle6290`)

## L'objectif

25 sites cohabitent dans le compte cPanel `qvle6290`. Une seule compromission
les expose tous. Quatre lunes (sous-comptes cPanel isolés) ont été créées pour
cloisonner.

**20 sites sont à déplacer.** Les 5 autres restent où ils sont.

C'est la même opération que sur le compte `webandseo`, avec le même outillage.
Une différence de taille : **sur ce compte, on ne sait encore rien des
particularités** — emails, sous-domaines, DNS externes, CDN. L'inventaire n'est
donc pas une formalité, c'est ce qui déterminera la procédure de chaque site.

## Répartition à appliquer

| Compte cible | Sites | Action |
|---|---|---|
| `qvle6290` *(principal)* | `1tchat.fr`, `achachichou.fr`, `atous.org`, `bitcoinfrance.net`, `blogfamilial.com` | **aucune** — ils y sont déjà |
| `sc1qvle6290` | `cherchenet.fr`, `coursdelargent.net`, `dentpourdent.net`, `domi-music.com`, `e-p-o-c.fr` | 5 migrations |
| `sc2qvle6290` | `eparsa.fr`, `etoile-rouge.fr`, `guidebarbecue.fr`, `guidejardin.com`, `guidemaison.net` | 5 migrations |
| `sc3qvle6290` | `ismap.fr`, `leblogcbd.fr`, `logiciel-emailing.net`, `mes-vacances-scolaires.fr`, `metaux.xyz` | 5 migrations |
| `sc4qvle6290` | `oglinks.com`, `peintremik-art.com`, `platomic.com`, `prixdesmetaux.fr`, `vetementsminceur.com` | 5 migrations |

Répartition arrêtée. Ne la modifie pas de ta propre initiative : si l'inventaire
fait apparaître un problème (voir « Quand t'arrêter »), remonte-le.

## Étape 0 — inventaire, et c'est un point d'arrêt

Quatre inconnues conditionnent la procédure de chaque site :

- quels domaines portent des **boîtes email** ;
- lesquels ont des **sous-domaines** ;
- lesquels utilisent des **DNS externes** (Cloudflare, registrar) ;
- lesquels passent par un **CDN** ou un autre alias DNS.

En SSH sur `qvle6290` :

    cd ~ && git clone https://github.com/webandseo/webandseo.git o2s-outils
    cd o2s-outils/o2switch/bin && chmod +x *.sh
    hostname -f          # relève le serveur de ce compte, il servira plus bas
    ./o2s-inventaire.sh

Le script est en lecture seule. **Remonte le `sites.tsv` et le nom du serveur
avant de démarrer la première migration**, et attends le feu vert : c'est à ce
moment que la feuille `plan/qvle6290/inventaire.csv` sera complétée, et donc que
les commandes générées seront justes.

Une piste à vérifier dès l'inventaire : `logiciel-emailing.net` traite
d'emailing. Un site de cette thématique porte souvent une configuration SPF,
DKIM et DMARC soignée. Regarde son relevé DNS de près.

## Ce qui est automatisé, et ce qui ne l'est pas

Un domaine ne peut pas exister sur deux comptes cPanel du même serveur en même
temps. Le déplacement impose donc de le **retirer** du compte de départ avant de
pouvoir l'**ajouter** sur celui d'arrivée. Ni cPanel ni o2switch ne proposent
cette bascule en une opération : deux manipulations manuelles, et c'est la seule
coupure.

Tout le reste est scripté. La stratégie consiste à **tout préparer pendant que
le site tourne**, pour réduire la fenêtre aux deux clics.

Les cinq comptes cohabitent sur la même machine : les transferts se font de
disque à disque, en local. Lance donc les scripts **en SSH sur `qvle6290`**,
jamais depuis un poste distant.

## Prérequis, une seule fois

1. **Autorisation SSH** : cPanel → `Sécurité` → `Autorisation SSH`, déclarer ton
   IP. Sur `qvle6290` **et** sur les quatre lunes.
2. **Clé SSH de `qvle6290` vers chaque lune.** Depuis `qvle6290` :

       ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519 && cat ~/.ssh/id_ed25519.pub

   Puis dans le cPanel de **chacune** des 4 lunes : `Sécurité` → `Accès SSH` →
   `Gérer les clés SSH` → `Importer une clé`, coller, et surtout cliquer sur
   **Autoriser** — une clé importée mais non autorisée ne sert à rien.
3. **Installer l'outillage sur chaque lune aussi** (même `git clone`) : la phase
   `finaliser` s'exécute côté destination.
4. **Vérifier** :

       ./o2s-migrer.sh --domaine cherchenet.fr --dst-user sc1qvle6290 --phase check

   Si la connexion échoue alors que la clé est autorisée, le shell cloisonné
   n'accepte peut-être pas `localhost` : teste `ssh sc1qvle6290@<serveur>` avec
   le nom relevé par `hostname -f`. Si c'est cette forme qui répond, ajoute
   `--dst-host <serveur>` à toutes les commandes.

## Procédure, pour chaque site

Génère les commandes plutôt que de les taper. **Attention à la feuille : deux
hébergements sont décrits dans `plan/`, se tromper viserait les mauvais
comptes.**

    ./o2s-plan.sh --csv ../plan/qvle6290/inventaire.csv                     # les 20
    ./o2s-plan.sh --csv ../plan/qvle6290/inventaire.csv --lune sc1qvle6290  # une lune

Le schéma est toujours le même :

**La veille — aucune coupure, le site tourne**

    ./o2s-verif.sh  --domaine SITE --snapshot avant
    ./o2s-migrer.sh --domaine SITE --dst-user LUNE --phase precopy --go

À l'issue de cette phase, la lune contient une copie complète du site et de sa
base, `wp-config.php` recâblé. Le domaine pointe toujours sur `qvle6290` : rien
n'a changé pour les visiteurs. C'est l'étape longue, prends ton temps.

Ouvre ensuite le relevé DNS produit dans `~/o2s-migration/SITE/dns/` et repère
ce qui devra être ressaisi.

**Jour J — la bascule**

    ./o2s-migrer.sh --domaine SITE --dst-user LUNE --phase delta --gel --go

`--gel` met le site source en maintenance avant de resynchroniser : aucune
écriture ne peut être perdue entre le dump et la bascule. Quelques secondes.

Puis dans cPanel, dans cet ordre :

1. `qvle6290` → `Domaines` → SITE → **Supprimer**
2. LUNE → `Domaines` → **Créer un domaine**, racine `/home/LUNE/SITE`
3. LUNE → `Éditeur de zone` → ressaisir les enregistrements relevés
4. LUNE → `SSL/TLS Status` → **Exécuter AutoSSL**

**Puis, sur la lune**

    ./o2s-migrer.sh --domaine SITE --dst-user LUNE --src-user qvle6290 \
                    --phase finaliser --reecrire-chemins --go
    ./o2s-verif.sh  --domaine SITE --snapshot apres

Le relevé « après » est comparé au « avant » et n'affiche que les écarts.

## Les quatre pièges

Les quatre s'appliquent ici, sans exception connue à ce stade.

**1. Retirer un domaine détruit sa zone DNS.** En le recréant sur la lune,
cPanel régénère une zone *par défaut* : MX, SPF, DKIM, DMARC, CAA,
vérifications de propriété et CNAME disparaissent. Le piège, c'est que **le site
remarche normalement** — la panne se manifeste deux heures plus tard, quand les
emails cessent de partir. `o2s-dns-save.sh` relève la zone avant l'opération (la
phase `precopy` le fait automatiquement). Sans objet pour les domaines en DNS
externe.

**2. Le certificat SSL ne suit pas.** Il appartient au compte cPanel. Lance
AutoSSL immédiatement après avoir ajouté le domaine. Si le site est derrière
Cloudflare en mode proxy, passe-le en `DNS only` le temps de la validation.

**3. Les emails ne se déplacent pas seuls.** Si l'inventaire révèle des boîtes,
elles sont à recréer sur la lune, puis deux répertoires à transférer :
`mail/SITE` (contenu des boîtes) et `etc/SITE` (configurations et mots de
passe). Bascule à heure creuse : les messages entrants peuvent être rejetés
pendant la fenêtre.

Et même sans boîte : l'absence de boîtes ne veut pas dire que la zone ne
contient ni MX, ni SPF, ni DKIM, ni DMARC. Ces enregistrements servent au
courrier sortant — formulaires de contact, notifications WordPress. Ressaisis
tout ce que le relevé montre, sans trier.

**4. Un sous-domaine ne peut pas quitter son domaine principal.** Il reste sur
la même lune, obligatoirement. Et surtout : **supprimer un domaine supprime tous
ses sous-domaines avec lui.** Si l'inventaire en révèle, ils doivent être
pré-copiés et recréés eux aussi, sous peine de disparaître.

Ne confonds pas un sous-domaine avec un **alias DNS**. Un sous-domaine a une
racine web : il se migre et se recrée dans `Domaines`. Un alias — un CNAME de
CDN, par exemple — n'a pas de racine : il se ressaisit uniquement dans
l'**Éditeur de zone**. Le créer comme sous-domaine produirait un enregistrement
A qui empêcherait le CNAME d'exister, et le CDN serait contourné sans que rien
n'ait l'air cassé.

## Règles de sûreté

- **Ne supprime jamais rien sur `qvle6290`.** Les scripts ne le font pas ; ne le
  fais pas non plus. Les fichiers et bases y restent intacts après la bascule :
  c'est le filet.
- **Retour arrière** : retirer le domaine de la lune, le recréer sur `qvle6290`
  avec sa racine d'avant, et supprimer le fichier `.maintenance` à la racine. Le
  site repart identique.
- Les scripts **simulent par défaut**. Lance chaque commande une première fois
  sans `--go` et lis ce qu'elle annonce avant d'exécuter.
- **Ne fais pas le ménage sur `qvle6290`** avant plusieurs jours de
  fonctionnement normal, emails et tâches cron vérifiés.
- `--reecrire-chemins` exige `--src-user qvle6290`. Ne le retire pas.

## Ordre d'exécution

1. **L'inventaire, et tu t'arrêtes.** Attends le feu vert avant toute migration :
   la feuille doit d'abord être complétée avec ce que tu auras trouvé.
2. **Un seul site ensuite**, le plus léger sans email, sans sous-domaine et sans
   DNS externe. Il valide la clé SSH, la bascule, AutoSSL, et donne le vrai
   chronomètre. Compte une heure. **Arrête-toi là aussi et fais un point.**
3. Puis les sites ordinaires, du plus léger au plus lourd. 15 à 20 minutes
   chacun une fois la procédure rodée.
4. Ceux qui portent des emails, un sous-domaine, un CDN ou une zone DNS chargée
   en dernier, à heure creuse, un ou deux par jour avec un contrôle le
   lendemain.

N'enchaîne pas les 20 d'un bloc. Chaque bascule mérite ses quinze minutes
d'attention.

## Le lendemain de chaque migration

- Recréer les **tâches cron** relevées (`~/o2s-migration/SITE/crontab-source.txt`)
- Vérifier la **version de PHP** et ses extensions sur la lune
- Purger les caches du site et d'un éventuel CDN
- Contrôler la Search Console et les logs d'erreur à 24 h

## Quand t'arrêter et demander

- **Après l'inventaire**, systématiquement.
- Un site a des **sous-domaines** : la répartition n'en tient pas compte,
  remonte-le avant de déplacer le domaine parent.
- Un site porte des **boîtes email** avec un historique à conserver : confirme
  la fenêtre de bascule avant de lancer.
- Un site passe par un **CDN** ou porte un **alias DNS** : signale-le, le CNAME
  devra être ressaisi et le cache purgé.
- L'inventaire révèle un site **nettement plus gros ou plus sensible** que ses
  voisins de lune : la répartition a été faite par ordre alphabétique, sans
  critère de risque.
- `o2s-verif.sh --snapshot apres` signale un **MX, SPF, DKIM, DMARC ou CNAME
  disparu** : corrige immédiatement dans l'Éditeur de zone, avant de passer au
  site suivant.
- La connexion SSH entre comptes ne s'établit ni par `localhost` ni par le nom
  du serveur : ne cherche pas de contournement, remonte-le.

## À me remonter

- Le nom du serveur (`hostname -f`) et le `sites.tsv` de l'inventaire, **avant**
  toute migration
- Après le premier site : le temps réel, et ce qui a coincé
- Après chaque site : la sortie de `o2s-verif.sh --snapshot apres`
- Un point global une fois les 20 faits, avec ce qui reste à finir

## Références

Dépôt `webandseo/webandseo`, branche `claude/o2switch-sites-distribution-f3ws7q` :

- `o2switch/README.md` — runbook détaillé
- `o2switch/plan/methode.md` — critères de répartition
- `o2switch/plan/qvle6290/repartition.md` — la répartition de ce compte

Guide officiel o2switch, à recouper :
<https://faq.o2switch.fr/guides/migrations/deplacer-site-hebergement-o2switch/>
