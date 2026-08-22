# Compte `qvle6290` — répartition

Méthode et critères : `plan/methode.md`.

## Les espaces disponibles

| Compte cPanel | Rôle |
|---|---|
| `qvle6290` | Compte principal — c'est de lui que se gèrent les lunes |
| `sc1qvle6290` | Lune 1 |
| `sc2qvle6290` | Lune 2 |
| `sc3qvle6290` | Lune 3 |
| `sc4qvle6290` | Lune 4 |

Le serveur qui héberge ce compte n'est pas nécessairement `canard.o2switch.net`
— c'est une offre distincte de celle de `webandseo`. À relever au premier accès
SSH (`hostname -f`), ou dans la barre latérale du cPanel. Sans incidence sur la
procédure : les cinq comptes cohabitent forcément sur la même machine, les
transferts restent internes.

## Répartition retenue

Arrêtée par Maximilien. 25 sites, dont **20 à déplacer**.

| Compte | Sites | Nb |
|---|---|---|
| `qvle6290` *(principal)* | `1tchat.fr`, `achachichou.fr`, `atous.org`, `bitcoinfrance.net`, `blogfamilial.com` | 5, en place |
| `sc1qvle6290` | `cherchenet.fr`, `coursdelargent.net`, `dentpourdent.net`, `domi-music.com`, `e-p-o-c.fr` | 5 |
| `sc2qvle6290` | `eparsa.fr`, `etoile-rouge.fr`, `guidebarbecue.fr`, `guidejardin.com`, `guidemaison.net` | 5 |
| `sc3qvle6290` | `ismap.fr`, `leblogcbd.fr`, `logiciel-emailing.net`, `mes-vacances-scolaires.fr`, `metaux.xyz` | 5 |
| `sc4qvle6290` | `oglinks.com`, `peintremik-art.com`, `platomic.com`, `prixdesmetaux.fr`, `vetementsminceur.com` | 5 |

### Écarts assumés, identiques au premier compte

Le découpage est **alphabétique** : cinq groupes de cinq, dans l'ordre des noms.
Les notes de valeur et de risque décrites dans `methode.md` n'ont pas été
appliquées. Un découpage alphabétique divise malgré tout le périmètre exposé
par cinq, et affiner reste possible plus tard — un déplacement de lune à lune
coûte le même effort qu'une migration initiale.

**Cinq sites restent sur le compte principal**, celui depuis lequel se gèrent
les lunes.

### Ce qu'on ne sait pas encore

Contrairement au compte `webandseo`, aucune particularité n'a encore été
relevée ici. Les quatre points suivants sont **inconnus** et conditionnent la
procédure de bascule, pas la répartition :

- quels domaines portent des **boîtes email** ;
- lesquels ont des **sous-domaines** — un sous-domaine ne peut pas quitter son
  domaine principal, et supprimer un domaine emporte tous les siens ;
- lesquels utilisent des **DNS externes** (Cloudflare, registrar) plutôt que
  ceux d'o2switch ;
- lesquels passent par un **CDN** ou tout autre alias DNS.

C'est l'objet de l'inventaire préalable, qui est un point d'arrêt obligatoire
dans l'ordre de mission.

Un seul soupçon, à vérifier : `logiciel-emailing.net` traite d'emailing. Un
site de cette thématique a de bonnes chances de porter une configuration SPF,
DKIM et DMARC soignée, voire d'envoyer réellement du courrier. À regarder de
près dans le relevé DNS avant de le basculer.
