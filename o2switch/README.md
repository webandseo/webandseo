# Déplacer des sites entre lunes o2switch

Outillage pour répartir plusieurs sites d'un même hébergement o2switch vers
des lunes distinctes, sans y passer ses journées.

---

## Le problème, tel qu'il se pose réellement

Déplacer un site d'une lune à une autre n'est pas difficile : c'est long, et
c'est long au mauvais endroit. Sur un site, la répartition du temps ressemble
à ceci :

| Étape | Durée typique | Automatisable |
|---|---|---|
| Copier les fichiers | 5 min à 2 h selon le poids | oui, entièrement |
| Exporter / importer la base | 1 à 15 min | oui, entièrement |
| Recréer la base et l'utilisateur, recâbler `wp-config.php` | 5 min | oui, entièrement |
| Relever la zone DNS avant de casser le domaine | 10 min | oui, entièrement |
| **Retirer le domaine de la lune A, l'ajouter sur la lune B** | **2 min** | **non — cPanel uniquement** |
| Ressaisir les enregistrements DNS personnalisés | 10 min | non, mais guidé |
| Relancer AutoSSL, recréer crons et emails | 10 min | partiellement |
| Vérifier que rien n'a cassé | 15 min | oui, entièrement |

L'essentiel du temps part dans des tâches mécaniques et répétitives. C'est ce
que ces scripts prennent en charge. Il reste, par site, **une seule
manipulation cPanel** — la bascule du domaine — plus la ressaisie DNS quand
la zone est personnalisée.

Deuxième levier, décisif : **les lunes d'un même hébergement cohabitent sur le
même serveur**. Le transfert se fait donc de disque à disque, en local, sans
jamais repasser par votre connexion. Un site de 8 Go se copie en minutes, pas
en demi-journée. C'est pour cela que ces scripts se lancent **en SSH sur la
lune source**, et non depuis votre poste.

---

## Ce qui n'est pas automatisable, et pourquoi

Un domaine ne peut pas exister sur deux comptes cPanel du même serveur en même
temps. Le déplacement impose donc de le **retirer** de la lune de départ avant
de pouvoir l'**ajouter** sur celle d'arrivée. cPanel n'expose pas cette bascule
en une opération atomique, et aucun outil o2switch ne la propose aujourd'hui :
la documentation officielle décrit bien une suppression suivie d'un ajout.

D'où la stratégie retenue ici : **tout préparer pendant que le site tourne**,
pour que la fenêtre entre suppression et ajout se réduise à la minute
nécessaire aux deux clics.

---

## Les quatre pièges qui coûtent cher

**1. La zone DNS disparaît avec le domaine.** Retirer un domaine d'un compte
cPanel supprime sa zone. En le recréant sur l'autre lune, cPanel régénère une
zone *par défaut* : MX, SPF, DKIM, DMARC, CAA, vérifications de propriété et
sous-domaines pointant ailleurs sont perdus. Le site, lui, remarche — c'est ce
qui rend la panne sournoise : elle se manifeste deux heures plus tard, quand
les emails cessent de partir. `o2s-dns-save.sh` relève la zone avant
l'opération, par trois canaux indépendants.

*Ne concerne pas les domaines dont les DNS sont gérés ailleurs (Cloudflare,
registrar) : la zone o2switch n'est alors pas utilisée.*

**2. Le certificat SSL ne suit pas.** Le certificat appartient au compte
cPanel. Après la bascule, le domaine n'en a plus — et comme la plupart des
sites forcent HTTPS par `.htaccess`, qui a voyagé avec les fichiers, le site
n'est pas seulement dégradé : il est inaccessible. Générez le certificat
immédiatement, par `Sécurité` → `Let's Encrypt™ SSL` → `Générer`, en cochant
le domaine **et** son `www`, et en décochant les sous-domaines techniques
(`.odns.fr`, `.o2switch.net`, `.universe.wf`) dont la présence fait échouer la
demande entière. AutoSSL finit par le faire seul, mais il attend la
propagation DNS et peut mettre des heures. Si le domaine est derrière
Cloudflare en mode proxy, passez-le temporairement en `DNS only`, sans quoi
la validation HTTP-01 peut échouer.

**3. Les emails ne se déplacent pas tout seuls.** Les comptes doivent être
recréés sur la lune de destination, et deux répertoires transférés pour
conserver l'historique et les mots de passe : `mail/domaine.fr` (le contenu
des boîtes) et `etc/domaine.fr` (les configurations). Prévoyez la bascule à
une heure creuse : les messages entrants peuvent être rejetés pendant la
fenêtre.

**4. Un sous-domaine ne peut pas quitter son domaine principal.** Il doit
rester sur la même lune. Si `boutique.exemple.fr` et `exemple.fr` doivent être
séparés, ce n'est pas faisable par ce chemin. Prenez-en compte au moment de
répartir les sites.

---

## Prérequis, une seule fois

1. **Autoriser SSH sur chaque lune** : cPanel → `Sécurité` → `Autorisation SSH`,
   y déclarer votre IP publique. À faire sur toutes les lunes concernées.

2. **Permettre à la lune source d'écrire sur la lune de destination.** Depuis
   la lune source, en SSH :

   ```sh
   ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
   cat ~/.ssh/id_ed25519.pub
   ```

   Puis, dans le cPanel de la lune de **destination** :
   `Sécurité` → `Accès SSH` → `Gérer les clés SSH` → `Importer une clé`,
   coller la clé publique, et surtout cliquer sur **Autoriser** (`Authorize`) —
   une clé importée mais non autorisée ne sert à rien.

3. **Installer l'outillage sur chaque lune concernée** — la source comme la
   destination : les phases `precopy` et `delta` se lancent depuis la source,
   la phase `finaliser` depuis la destination.

   ```sh
   cd ~ && git clone https://github.com/webandseo/webandseo.git o2s-outils
   cd o2s-outils/o2switch/bin && chmod +x *.sh
   ```

4. **Vérifier** :

   ```sh
   ./o2s-migrer.sh --domaine exemple.fr --dst-user lune2 --phase check
   ```

   Les scripts visent `localhost` par défaut, puisque les lunes partagent le
   serveur. Si la connexion est refusée alors que la clé est bien autorisée,
   le shell cloisonné n'accepte peut-être pas ce nom : essayez
   `ssh lune2@canard.o2switch.net`, et si c'est cette forme qui répond,
   ajoutez `--dst-host canard.o2switch.net` à chaque commande. Le transfert
   reste interne au serveur dans les deux cas.

---

## Procédure, site par site

> Tous les scripts **simulent** par défaut et n'écrivent rien. Ajoutez `--go`
> pour exécuter. Aucun d'eux ne supprime quoi que ce soit sur la lune source.

### La veille — préparation, sans aucune coupure

```sh
./o2s-verif.sh   --domaine exemple.fr --snapshot avant
./o2s-migrer.sh  --domaine exemple.fr --dst-user lune2 --phase precopy --go
```

À l'issue de cette phase, la lune de destination contient une copie complète
du site et de sa base, `wp-config.php` recâblé. Le domaine pointe toujours sur
la lune d'origine : **rien n'a changé pour les visiteurs**. Prenez le temps
qu'il faut, c'est l'étape longue.

Ouvrez le relevé DNS produit dans `~/o2s-migration/exemple.fr/dns/` et repérez
ce qui devra être ressaisi.

### Le jour J — la bascule

```sh
./o2s-migrer.sh --domaine exemple.fr --dst-user lune2 --phase delta --gel --go
```

`--gel` met le site source en maintenance avant la resynchronisation : aucune
commande, aucun commentaire, aucune écriture ne peut être perdu entre le dump
et la bascule. Cette phase dure quelques secondes.

Puis, dans cPanel — c'est la seule coupure :

1. Lune source → `Domaines` → `exemple.fr` → **Supprimer**
2. Lune de destination → `Domaines` → **Créer un domaine**
   - domaine : `exemple.fr`
   - racine du site : le chemin affiché par le script
   - décocher « partager le document root » si l'option apparaît
3. `Éditeur de zone` de la lune de destination : ressaisir les enregistrements
   relevés à l'étape précédente
4. `SSL/TLS Status` → **Exécuter AutoSSL**

Enfin, depuis la lune de **destination** :

```sh
./o2s-migrer.sh --domaine exemple.fr --dst-user lune2 --src-user lune1 \
                --phase finaliser --reecrire-chemins --go
./o2s-verif.sh  --domaine exemple.fr --snapshot apres
```

`--src-user` est le nom du compte cPanel d'origine. La pré-copie l'a
normalement déposé sur la lune de destination, mais le passer explicitement ne
coûte rien — et c'est obligatoire avec `--reecrire-chemins`, faute de quoi le
script refuse de démarrer plutôt que de réécrire des chemins au hasard.

Le relevé « après » est comparé au relevé « avant » et n'affiche que les
écarts. Un changement d'émetteur de certificat est normal — AutoSSL vient de
le réémettre. Un MX, un SPF ou un DKIM manquant ne l'est pas.

### Le lendemain — les finitions

- Recréer les **comptes email**, puis transférer `mail/exemple.fr` et
  `etc/exemple.fr` (le fichier `crontab-source.txt` et le relevé sont dans
  `~/o2s-migration/exemple.fr/`)
- Recréer les **tâches cron** relevées lors de la pré-copie
- Vérifier la **version de PHP** et ses extensions sur la lune de destination
- Purger le cache du site et de l'éventuel CDN
- Contrôler la Search Console et les logs d'erreur 24 h plus tard

---

## Revenir en arrière

C'est la propriété la plus utile de cette méthode : **rien n'est jamais
supprimé sur la lune source**. Les fichiers, la base et les comptes y restent
intacts. Si quelque chose se passe mal après la bascule, il suffit de retirer
le domaine de la lune de destination et de le recréer sur la lune d'origine,
avec sa racine d'avant. Le site repart dans l'état exact qu'il avait.

En pratique : recréer le domaine sur la lune d'origine avec sa racine
d'avant, puis **supprimer le fichier `.maintenance`** que `--gel` y avait
déposé — sans quoi le site affiche une page de maintenance alors que tout
fonctionne.

Ne faites le ménage sur la lune source qu'après quelques jours de
fonctionnement normal, une fois les emails et les tâches planifiées vérifiés.

---

## Les scripts

| Script | Rôle |
|---|---|
| `o2s-inventaire.sh` | Dresse l'inventaire d'un compte : domaines, racines, bases, tailles, PHP, emails, crons. À lancer en premier, sur chaque lune. Ne modifie rien. |
| `o2s-dns-save.sh` | Relève la zone DNS d'un domaine avant de le retirer. Trois sources, de la plus fidèle à la plus approximative. |
| `o2s-migrer.sh` | Le cœur : `check`, `precopy`, `delta`, `finaliser`. |
| `o2s-verif.sh` | Relevé `avant` / `apres` et comparaison. Détecte les régressions invisibles à l'œil. |
| `o2s-plan.sh` | Tire les commandes de chaque site depuis la feuille d'un compte, dans l'ordre de passage, et contrôle la cohérence du plan. |

### Organisation de `plan/`

Le runbook et l'outillage sont génériques ; chaque hébergement a son dossier.

    plan/methode.md    critères de répartition, indépendants du compte
    plan/webandseo/    compte webandseo — 23 sites, 18 migrations  (effectuée)
    plan/qvle6290/     compte qvle6290  — 25 sites, 20 migrations  (effectuée)
    plan/trlh2564/     compte trlh2564  — 23 sites, 19 migrations  (effectuée)
    plan/elyes7/       compte elyes7    — 10 sites,  8 migrations

Chaque dossier contient `repartition.md` (la répartition retenue),
`inventaire.csv` (la feuille de travail) et `mission-hermes.md` (l'ordre de
mission remis à l'exécutant).

`--csv` est obligatoire sur `o2s-plan.sh` : avec deux feuilles, un défaut
implicite produirait des commandes visant les mauvais comptes.
| `o2s-lib.sh`, `o2s-json.php`, `o2s-wpcfg.php` | Fonctions communes, lecture des réponses de l'API cPanel et des `wp-config.php`. |

Chaque script accepte `--help`.

### Détails d'implémentation qui ont leur importance

- Les caches (`wp-content/cache`, LiteSpeed, WP Rocket, Elementor) et les
  sauvegardes de plugins sont **exclus** du transfert : inutiles à déplacer,
  et truffés de chemins absolus périmés qui casseraient le site à l'arrivée.
  Ils se régénèrent d'eux-mêmes.
- Les mots de passe de base ne transitent jamais par une ligne de commande :
  ils passent par des fichiers d'options à droits `600`, supprimés après usage.
- `wp-config.php` est lu avec le tokenizer PHP et réécrit via `var_export`,
  ce qui reste correct pour les mots de passe contenant apostrophes,
  contre-obliques ou guillemets — cas où une réécriture à coups d'expressions
  régulières produit un fichier invalide.
- Une copie `wp-config.php.avant-migration` est conservée à l'arrivée.
- L'état de chaque migration est conservé dans
  `~/o2s-migration/<domaine>/etat.env` (droits `600`) : les phases peuvent être
  relancées sans tout recommencer.
- `rsync` reprend un transfert interrompu là où il s'est arrêté. Relancer la
  même commande est toujours sûr.

---

## Ordre de passage conseillé

1. **Un site sans enjeu d'abord** — le plus petit, le moins visité. Il sert de
   répétition : vous validez la clé SSH, la bascule cPanel, AutoSSL, et vous
   chronométrez. Comptez une heure pour ce premier site, quinze à vingt
   minutes pour les suivants.
2. **Puis les sites sans email et sans DNS personnalisé** : ce sont les plus
   simples, la zone se régénère seule.
3. **Ensuite les sites avec emails ou zone DNS chargée**, un par jour ou deux,
   avec un contrôle le lendemain.
4. **Les sites à fort trafic ou à transactions en dernier**, à heure creuse,
   quand la procédure est devenue routinière.

Ne cherchez pas à enchaîner les 23 sites d'un bloc. La procédure est fiable,
mais chaque bascule mérite ses quinze minutes d'attention.
