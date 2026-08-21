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

## D'abord : cinq lunes, est-ce le bon nombre ?

23 sites pour 5 lunes, c'est 4,6 sites par lune — et donc l'impossibilité
d'isoler seul le moindre site à enjeu. Or c'est précisément là que le
cloisonnement rapporte le plus : un site qui pèse dans le chiffre d'affaires
gagne à ne partager sa lune avec rien.

Les offres o2switch ouvrent **4, 8 ou 16 lunes gratuites** selon le plan, et
jusqu'à 20 en option payante (de l'ordre de 1,50 € par lune supplémentaire).
**Vérifiez ce que votre plan autorise avant de figer la répartition.** Passer
de 5 à 8 lunes change la nature de l'exercice :

| | 5 lunes | 8 lunes |
|---|---|---|
| Sites par lune | 4 à 5 partout | 1 pour les sites critiques, 5 à 6 pour les autres |
| Sites à enjeu isolés seuls | aucun | 3 |
| Périmètre exposé si un site de niche tombe | 4 autres sites | 5 autres sites, tous sans enjeu |

Le gain ne vient pas du nombre de lunes en soi : il vient de la possibilité de
mettre les sites qui comptent **tout seuls**. Si le plan ne permet que 5 lunes
et que l'option payante n'est pas souhaitée, la répartition ci-dessous reste
valable — elle privilégie alors l'isolement du groupe le plus fragile.

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

## Trame de répartition

Les intitulés ci-dessous sont une proposition de structure, pas une
affectation. Seuls les sites identifiables depuis vos pages publiques sont
préremplis, à titre d'exemple de raisonnement — ils sont à confirmer.

| Lune | Intention | Sites | Valeur | Risque |
|---|---|---|---|---|
| **lune-1** | Actif principal, isolé autant que possible | `webandseo.fr` *(+ sous-domaines éventuels)* | 3 | ? |
| **lune-2** | Marques et services commerciaux | `seopepper.com`, `monsitedeniche.com`, `impactmarketing.fr` | 3 | ? |
| **lune-3** | Perso, newsletter, annexes | `maximilien.me`, `webandseo.net` | 2 | ? |
| **lune-4** | Sites de niche — lot A | *à compléter* | 1–2 | 2–3 |
| **lune-5** | Sites de niche — lot B, et bac à sable | *à compléter* | 1 | 3 |

Deux remarques sur cette trame :

- `webandseo.fr/agence/`, `/academie/`, `/academie/produit/…` sont des
  **sous-répertoires** : même installation, donc même lune, ce n'est pas un
  choix mais un fait. À confirmer qu'il ne s'agit pas d'installations
  distinctes.
- Les sites de niche sont ceux qui présentent le plus de risque (thèmes et
  extensions variés, maintenance moins suivie) et le moins de valeur unitaire.
  Les concentrer sur deux lunes protège tout le reste : c'est le meilleur
  rapport effort/protection de l'ensemble.

---

## Feuille d'inventaire

`plan/inventaire.csv` est une trame à remplir. Le plus rapide est de la
générer plutôt que de la saisir : lancez `o2s-inventaire.sh` sur le compte
principal, il produit un `sites.tsv` qui contient déjà domaines, racines,
bases, versions de PHP et tailles. Il ne reste qu'à ajouter les deux notes et
la lune cible.

---

## Ce qu'il me manque pour finaliser

1. **La liste des 23 domaines** — un simple copier-coller de la colonne
   « Domaines » du cPanel suffit. Le `sites.tsv` de l'inventaire est encore
   mieux : il apporte tailles, versions de PHP et bases en une fois.
2. **Le nombre de lunes réellement disponibles** sur votre plan (4, 8 ou 16
   gratuites ?), pour savoir si on vise 5 ou davantage.
3. **Les sites qui portent des boîtes email**, et ceux qui utilisent des DNS
   externes (Cloudflare ou registrar) plutôt que ceux d'o2switch — ces deux
   points changent la procédure de bascule, pas la répartition.
4. **Les sites accessibles à un tiers**, s'il y en a.
5. Pour les sites de niche, une indication grossière suffit : lesquels
   génèrent des revenus, lesquels sont expérimentaux.

Avec ces éléments, la répartition se finalise et chaque site reçoit sa
commande de migration, prête à copier-coller.
