# Répartir des sites sur des lunes o2switch — la méthode

Ce document pose le raisonnement et les critères, indépendamment du compte.
La répartition effectivement retenue pour chaque hébergement se trouve dans le
sous-dossier correspondant :

- `plan/webandseo/` — compte `webandseo`, 23 sites
- `plan/qvle6290/` — compte `qvle6290`, 25 sites

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

## Générer les commandes

Une fois la feuille du compte remplie, `bin/o2s-plan.sh` en tire les commandes
de chaque site, dans l'ordre de passage conseillé. `--csv` est obligatoire :
plusieurs hébergements sont décrits dans `plan/`, et un défaut implicite
produirait des commandes visant les mauvais comptes.

```sh
./o2s-plan.sh --csv ../plan/<compte>/inventaire.csv                  # tout
./o2s-plan.sh --csv ../plan/<compte>/inventaire.csv --lune <lune>    # une lune
```

Il contrôle aussi la cohérence du plan et signale les regroupements
dangereux — un site noté risque 3 partageant sa lune avec un site noté
valeur 3 — ainsi que les sites encore sans lune cible.

## Feuille d'inventaire

`plan/<compte>/inventaire.csv` est une trame à remplir. Le plus rapide est de la
générer plutôt que de la saisir : lancez `o2s-inventaire.sh` sur le compte
principal, il produit un `sites.tsv` qui contient déjà domaines, racines,
bases, versions de PHP et tailles. Il ne reste qu'à ajouter les deux notes et
la lune cible.

---

