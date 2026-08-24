# Compte `elyes7` — répartition

> **Migration effectuée.** Les 8 sites ont été déplacés et leurs certificats
> Let's Encrypt générés. Ce document est conservé comme trace de ce qui a été
> appliqué.

Méthode et critères : `plan/methode.md`.

## Les espaces disponibles

| Compte cPanel | Rôle |
|---|---|
| `elyes7` | Compte principal — c'est de lui que se gèrent les lunes |
| `sc1elyes7` | Lune 1 |
| `sc2elyes7` | Lune 2 |
| `sc3elyes7` | Lune 3 |
| `sc4elyes7` | Lune 4 |

Le serveur qui héberge ce compte est à relever au premier accès SSH
(`hostname -f`), ou dans la barre latérale du cPanel : rien ne dit qu'il
s'agit du même que pour les hébergements précédents. Sans incidence sur la
procédure — les cinq comptes cohabitent forcément sur la même machine.

## Répartition retenue

Arrêtée par Maximilien. 10 sites, dont **8 à déplacer**.

| Compte | Sites | Nb |
|---|---|---|
| `elyes7` *(principal)* | `acheterdesactions.fr`, `actejuridique.fr` | 2, en place |
| `sc1elyes7` | `amenagements.net`, `bricoler.net` | 2 |
| `sc2elyes7` | `damejeanne.fr`, `disqueuse.net` | 2 |
| `sc3elyes7` | `maisonoptimale.fr`, `nourdegypte.com` | 2 |
| `sc4elyes7` | `pacteassocies.fr`, `reparer.eu` | 2 |

### Le mieux cloisonné des quatre hébergements

Deux sites par espace, contre quatre à six sur les trois précédents. C'est le
rapport le plus favorable du parc : une compromission n'exposerait qu'un seul
voisin, là où elle en atteignait quatre ailleurs.

Le découpage reste **alphabétique**, les deux premiers noms restant sur le
compte principal, et les notes de valeur et de risque de `methode.md` n'ont pas
été appliquées. Avec dix sites pour cinq espaces, la question se pose moins :
quel que soit le critère retenu, le périmètre exposé se limite à deux sites.

### Particularités : aucune

Confirmé pour les 10 domaines : **aucun sous-domaine, aucune boîte email,
aucun cas particulier.** Ni CDN, ni alias DNS, ni DNS externe signalé.

Deux conséquences pratiques, les mêmes que sur les comptes précédents :

- La zone DNS reste à restaurer intégralement après chaque bascule. L'absence
  de boîte email n'implique pas l'absence de SPF ou de DKIM : ces
  enregistrements servent au courrier **sortant** des sites, et les perdre fait
  finir en spam les notifications et les formulaires de contact, sans erreur
  visible.
- Les **certificats Let's Encrypt** sont à générer sur la lune juste après
  l'ajout de chaque domaine. Un certificat appartient au compte cPanel et ne
  suit pas le domaine ; comme les sites forcent HTTPS par `.htaccess`, un
  domaine sans certificat n'est pas dégradé mais inaccessible.
