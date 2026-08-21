# Répartition des 23 sites sur les lunes

Document de travail. La méthode et les contraintes sont établies ; le tableau
final attend la liste réelle des sites (voir « Ce qu'il me manque » en fin de
page).

---

## Ce qu'une lune protège, et ce qu'elle ne protège pas

Une lune est un compte cPanel indépendant : système de fichiers séparé,
utilisateur système distinct, ressources dédiées. Un WordPress compromis dans
une lune ne donne pas accès aux fichiers des autres lunes. C'est exactement la
réponse au risque décrit — aujourd'hui, une seule faille expose les 23 sites.

Trois limites à garder en tête, pour ne pas se croire mieux protégé qu'on
ne l'est :

- **Le cloisonnement s'arrête à la lune.** Les sites d'une même lune restent
  perméables entre eux. La question à se poser pour chaque groupe n'est donc
  pas « ces sites se ressemblent-ils ? » mais **« suis-je prêt à les perdre
  ensemble ? »**
- **L'IP ne change pas.** Toutes les lunes partagent l'IP du serveur. Aucun
  effet, ni positif ni négatif, sur l'empreinte SEO du réseau. Si la
  diversification d'IP est un objectif à part, elle relève de l'option
  ipXtender, pas des lunes.
- **Le compte principal reste le plus sensible.** C'est de lui que se gèrent
  les lunes. Le laisser **sans aucun site** est le meilleur usage qu'on puisse
  en faire : plus rien à y compromettre. C'est bien ce que vise une répartition
  23 sites → 5 lunes.

---

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

## Critères de classement

Deux notes par site, de 1 à 3. Elles se croisent, elles ne s'additionnent pas.

**Valeur** — ce que coûterait la perte ou l'indisponibilité du site
1. aucun revenu, aucun trafic, reconstructible en une journée
2. trafic réel, revenus indirects, image
3. revenus directs, clients, contenus non reproductibles

**Risque** — la probabilité d'être le point d'entrée
1. site sobre : peu de plugins, à jour, pas de compte utilisateur, pas de
   formulaire d'upload
2. site standard : une dizaine de plugins, mises à jour irrégulières
3. site exposé : e-commerce ou paiement, comptes utilisateurs, extensions ou
   thèmes hors dépôt officiel, version de PHP ou de WordPress ancienne, site
   repris d'un tiers dont l'historique est inconnu

La règle de placement en découle : **un site noté risque 3 ne partage jamais
sa lune avec un site noté valeur 3.** Tout le reste est du remplissage.

---

## Contraintes techniques à respecter

- **Un sous-domaine reste sur la lune de son domaine principal.** Si
  `boutique.exemple.fr` et `exemple.fr` existent tous les deux, ils sont
  indissociables. À repérer avant de composer les groupes.
- **Les domaines portant des boîtes email** demandent une bascule plus
  soignée. Les regrouper permet de traiter cette difficulté en une fois.
- **Un site accessible à un tiers** (client, prestataire, marque blanche) va
  dans une lune où il est seul ou entouré d'autres sites du même tiers : c'est
  le cas d'usage d'origine des lunes, on peut alors déléguer l'accès cPanel
  sans exposer le reste.
- **L'équilibrage disque et ressources** vient en dernier. Il n'entre en jeu
  que si un site pèse à lui seul une part importante du quota.

---

## Trame de répartition

Structure proposée, à confirmer. Seuls les sites identifiables depuis vos
pages publiques sont préremplis — les 17 autres manquent.

| Lune | Intention | Sites | Nb |
|---|---|---|---|
| `webandseo` | **Vidé.** Aucun site. | — | 0 |
| `sc1webandseo` | Les deux actifs à plus forte valeur, groupe volontairement restreint | `webandseo.fr`, `seopepper.com` | 2 |
| `sc2webandseo` | Marques, services, perso | `monsitedeniche.com`, `impactmarketing.fr`, `webandseo.net`, `maximilien.me` | 4 |
| `sc3webandseo` | Sites de niche — lot A | *à compléter* | ~8 |
| `sc4webandseo` | Sites de niche — lot B | *à compléter* | ~9 |

Le raisonnement tient en une phrase : **les 17 sites de niche portent
l'essentiel du risque et le moins de valeur unitaire.** Les concentrer sur
deux lunes met tout le reste à l'abri, pour un effort identique.

Deux points à vérifier avant de figer :

- `webandseo.fr/agence/`, `/academie/`, `/academie/produit/…` sont des
  **sous-répertoires** : même installation, donc même lune — ce n'est pas un
  choix. À confirmer qu'il ne s'agit pas d'installations distinctes.
- Si l'un de ces domaines porte des **sous-domaines**, ceux-ci sont
  indissociables du domaine principal et suivent forcément.

## Générer les commandes

Une fois `inventaire.csv` rempli, `bin/o2s-plan.sh` en tire les commandes de
chaque site, dans l'ordre de passage conseillé :

```sh
./o2s-plan.sh --csv ../plan/inventaire.csv                  # tout
./o2s-plan.sh --csv ../plan/inventaire.csv --lune sc3webandseo   # une lune
```

Il contrôle aussi la cohérence du plan et signale les regroupements
dangereux — un site noté risque 3 partageant sa lune avec un site noté
valeur 3 — ainsi que les sites encore sans lune cible.

## Feuille d'inventaire

`plan/inventaire.csv` est une trame à remplir. Le plus rapide est de la
générer plutôt que de la saisir : lancez `o2s-inventaire.sh` sur le compte
principal, il produit un `sites.tsv` qui contient déjà domaines, racines,
bases, versions de PHP et tailles. Il ne reste qu'à ajouter les deux notes et
la lune cible.

---

## Ce qu'il me manque pour finaliser

1. **La liste des 23 domaines** — un simple copier-coller de la colonne
   « Domaines » du cPanel de `webandseo` suffit. Le `sites.tsv` de l'inventaire
   est encore mieux : il apporte tailles, versions de PHP et bases en une fois.
   C'est le seul élément vraiment bloquant.
2. **Le nombre de lunes que le plan autorise** (4, 8 ou 16 gratuites ?) —
   quatre sont actives, mais rien ne dit que c'est le maximum. Visible dans
   Mon Univers Web.
3. **Le vrai nom de la lune 1** (`sc1webandseo` ?).
4. **Les sites qui portent des boîtes email**, et ceux qui utilisent des DNS
   externes (Cloudflare ou registrar) plutôt que ceux d'o2switch — ces deux
   points changent la procédure de bascule, pas la répartition.
5. **Les sites accessibles à un tiers**, s'il y en a.
6. Pour les sites de niche, une indication grossière suffit : lesquels
   génèrent des revenus, lesquels sont expérimentaux.

Avec ces éléments, la répartition se finalise et chaque site reçoit sa
commande de migration, prête à copier-coller.
