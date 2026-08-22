# Compte `webandseo` — répartition

Méthode et critères : `plan/methode.md`.

## Les espaces disponibles

| Compte cPanel | Rôle |
|---|---|
| `webandseo` | Compte principal — c'est de lui que se gèrent les lunes |
| `sc1webandseo` | Lune 1 |
| `sc2webandseo` | Lune 2 |
| `sc3webandseo` | Lune 3 |
| `sc4webandseo` | Lune 4 |

> Le nom de la lune 1 est à confirmer : la liste transmise indiquait
> `sc2webandseo` pour les lunes 1 et 2. `sc1webandseo` est retenu par
> cohérence avec `sc2` / `sc3` / `sc4`.

**Quatre lunes, pas cinq espaces équivalents.** Le compte principal n'est pas
une lune parmi d'autres : c'est celui depuis lequel les lunes se créent et se
gèrent. Y héberger des sites revient à garder le point le plus sensible de
l'installation exposé au risque qu'on cherche précisément à cloisonner.

**Le mieux qu'on puisse en faire est de le vider complètement.** Il ne reste
alors plus rien à compromettre là où ça ferait le plus de dégâts. Cela donne :

| | 23 sites sur 5 espaces | 23 sites sur 4 lunes, principal vide |
|---|---|---|
| Sites par espace | 4 à 5 | 5 à 6 |
| Compte principal exposé | oui | **non** |
| Périmètre si un site de niche tombe | 4 autres sites | 5 autres sites, sans enjeu |

Un site de plus par lune contre un compte principal hors d'atteinte : le
compte est largement favorable.

### Vaut-il la peine d'ouvrir plus de lunes ?

Quatre lunes sont *actives*, ce qui ne dit pas combien le plan en autorise.
Les offres o2switch en ouvrent **4, 8 ou 16 gratuites** selon le plan, et
jusqu'à 20 en option payante (de l'ordre de 1,50 € par lune). À vérifier dans
Mon Univers Web.

L'intérêt n'est pas d'avoir plus de lunes pour elles-mêmes : c'est de pouvoir
mettre **seuls** les sites qui comptent. Avec quatre lunes, `webandseo.fr` et
`seopepper.com` partagent forcément leur espace. Avec huit, chacun a le sien,
et les sites de niche — les plus risqués, les moins critiques — se concentrent
ailleurs sans mettre quoi que ce soit d'autre en jeu.

Si le plan n'autorise que quatre lunes, la répartition ci-dessous reste
valable : elle isole alors le groupe le plus fragile, ce qui est le meilleur
usage possible de quatre espaces.

## Répartition retenue

Arrêtée par Maximilien. 23 sites, dont **18 à déplacer**.

| Compte | Sites | Nb |
|---|---|---|
| `webandseo` *(principal)* | `123loterie.com`, `despras.fr`, `domaine-chignard.fr`, `entretienauto.fr`, `etudiantenfrance.com` | 5, en place |
| `sc1webandseo` | `guideregime.com`, `je-dois-reussir.com`, `jeanlouismahe.com`, `kolectou.com`, `leblogweb.fr` | 5 |
| `sc2webandseo` | `ma-moto.net`, `ma-voiture.net`, `melimarie.fr`, `meuble.org` | 4 |
| `sc3webandseo` | `plateaubriard.fr`, `prorecyclage.com`, `top-maison.net`, `tresorsinutiles.com` | 4 |
| `sc4webandseo` | `troizenfants.fr`, `valdissole.fr`, `whiteref.com`, `whiteref.net`, `yves-simon.com` | 5 |

### Deux écarts assumés par rapport aux critères ci-dessus

**Le découpage est alphabétique.** `123loterie` → `etudiantenfrance`, puis
`guideregime` → `leblogweb`, et ainsi de suite. Les notes de valeur et de
risque n'ont donc pas été appliquées : chaque lune réunit des sites dont le
seul point commun est l'initiale. Concrètement, si l'un de ces 23 sites pèse
nettement plus que les autres, il partage aujourd'hui sa lune avec quatre
voisins tirés au sort par l'alphabet.

Un découpage alphabétique divise malgré tout le périmètre exposé par cinq :
c'est l'essentiel du gain, et il est acquis. Affiner reste possible plus tard,
un déplacement de lune à lune coûtant le même effort qu'une migration
initiale.

**Cinq sites restent sur le compte principal.** Le vider entièrement aurait
mis hors d'atteinte le compte depuis lequel se gèrent les lunes. Le choix
retenu conserve 5 sites dessus.

### Particularités relevées

- **Aucune boîte email** sur les 23 domaines. Cela retire la partie la plus
  pénible d'une migration cPanel. La zone DNS reste à restaurer intégralement :
  MX, SPF et DKIM peuvent servir au courrier sortant des sites même sans boîte.
- **`whiteref.com` est une famille de trois hôtes** : le domaine et
  `annuaire.` redirigent vers `www.leblogmarketing.fr`, `blog.` porte le
  contenu. Supprimer le domaine emporte ses sous-domaines : les trois partent
  ensemble vers `sc4webandseo`, ce qui est déjà la lune prévue — pas de
  conflit, mais trois racines à traiter.
- **`je-dois-reussir.com` passe par KeyCDN** : `cdn.je-dois-reussir.com` est un
  CNAME vers `jedoisreussir-f692.kxcdn.com`. Il vit dans la zone du domaine et
  disparaît avec elle : à ressaisir sur `sc1webandseo`, dans l'Éditeur de zone
  uniquement — c'est un alias DNS, pas un sous-domaine cPanel.
- **Aucun autre sous-domaine** parmi les 18 sites à déplacer.

## Suite

La répartition est transmise à l'agent Hermes pour exécution :
voir `plan/mission-hermes.md`.

Reste à établir pendant l'inventaire, avant la première migration : quels
sites portent des boîtes email, lesquels utilisent des DNS externes, et
lesquels ont des sous-domaines. Ces trois points changent la procédure de
bascule, pas la répartition.

Le nom de la lune 1 (`sc1webandseo`) est confirmé.
