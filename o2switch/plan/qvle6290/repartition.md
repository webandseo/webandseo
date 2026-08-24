# Compte `qvle6290` — répartition

> **Migration effectuée.** Les 20 sites ont été déplacés et leurs certificats
> Let's Encrypt générés. Ce document est conservé comme trace de ce qui a été
> appliqué.

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

### Particularités : aucune

Confirmé pour les 25 domaines : **aucun sous-domaine, aucune boîte email,
aucun cas particulier.** Ni CDN, ni alias DNS, ni DNS externe signalé. C'est
vingt fois la même séquence, sans exception à traiter.

Deux conséquences pratiques :

- La zone DNS reste malgré tout à restaurer intégralement après chaque bascule.
  L'absence de boîte email n'implique pas l'absence de SPF ou de DKIM : ces
  enregistrements servent au courrier **sortant** des sites, et les perdre fait
  finir en spam les notifications et les formulaires de contact, sans erreur
  visible.
- Les **certificats Let's Encrypt** sont à générer sur la lune juste après
  l'ajout de chaque domaine. Un certificat appartient au compte cPanel et ne
  suit pas le domaine ; comme les sites forcent HTTPS par `.htaccess`, un
  domaine sans certificat n'est pas dégradé mais inaccessible.
