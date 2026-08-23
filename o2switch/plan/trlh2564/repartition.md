# Compte `trlh2564` — répartition

Méthode et critères : `plan/methode.md`.

## Les espaces disponibles

| Compte cPanel | Rôle |
|---|---|
| `trlh2564` | Compte principal — c'est de lui que se gèrent les lunes |
| `sc1trlh2564` | Lune 1 |
| `sc2trlh2564` | Lune 2 |
| `sc3trlh2564` | Lune 3 |
| `sc4trlh2564` | Lune 4 |

Le serveur qui héberge ce compte est à relever au premier accès SSH
(`hostname -f`), ou dans la barre latérale du cPanel : rien ne dit qu'il
s'agit du même que pour les deux hébergements précédents. Sans incidence sur
la procédure — les cinq comptes cohabitent forcément sur la même machine, les
transferts restent internes.

## Répartition retenue

Arrêtée par Maximilien. 23 sites, dont **19 à déplacer**.

| Compte | Sites | Nb |
|---|---|---|
| `trlh2564` *(principal)* | `revue-de-synthese.eu`, `vv-artdesign.com`, `wepeek.fr`, `yatoo.org` | 4, en place |
| `sc1trlh2564` | `aliens-cafe.com`, `artswall.fr`, `blogvoyage.eu`, `caet.fr`, `delsoko.fr` | 5 |
| `sc2trlh2564` | `espace-zen.fr`, `ftpix.fr`, `guidevoyage.net`, `herve-sarl.fr`, `kalaphoto.fr` | 5 |
| `sc3trlh2564` | `laiton.eu`, `le-paysagiste.net`, `leblogdubienetre.com`, `morningcoffee.fr` | 4 |
| `sc4trlh2564` | `muxi.fr`, `paiecheck.com`, `plomb.eu`, `programme-repere.fr`, `publiepapier.fr` | 5 |

### Écarts assumés, identiques aux deux premiers comptes

Le découpage est **alphabétique**, les quatre derniers noms restant sur le
compte principal. Les notes de valeur et de risque décrites dans `methode.md`
n'ont pas été appliquées. Un découpage alphabétique divise malgré tout le
périmètre exposé par cinq, et affiner reste possible plus tard — un
déplacement de lune à lune coûte le même effort qu'une migration initiale.

**Quatre sites restent sur le compte principal**, celui depuis lequel se
gèrent les lunes.

### Particularités : aucune

Confirmé pour les 23 domaines : **aucun sous-domaine, aucune boîte email,
aucun cas particulier.** Ni CDN, ni alias DNS, ni DNS externe signalé.

Deux conséquences pratiques, les mêmes que sur `qvle6290` :

- La zone DNS reste à restaurer intégralement après chaque bascule. L'absence
  de boîte email n'implique pas l'absence de SPF ou de DKIM : ces
  enregistrements servent au courrier **sortant** des sites, et les perdre fait
  finir en spam les notifications et les formulaires de contact, sans erreur
  visible.
- Les **certificats Let's Encrypt** sont à générer sur la lune juste après
  l'ajout de chaque domaine. Un certificat appartient au compte cPanel et ne
  suit pas le domaine ; comme les sites forcent HTTPS par `.htaccess`, un
  domaine sans certificat n'est pas dégradé mais inaccessible.
