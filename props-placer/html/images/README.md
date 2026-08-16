# Vignettes des props

Déposez ici une image par modèle, nommée **exactement** comme le modèle :

```
html/images/prop_bench_01a.png
html/images/prop_roadcone02a.png
html/images/prop_tree_pine_01.png
```

Formats servis par la ressource : `.png`, `.jpg`, `.webp` (déclarés dans `fxmanifest.lua`).
Le chemin est configurable via `Config.UI.LocalImages`.

## Pourquoi ce dossier est vide

GTA V et FiveM ne fournissent **aucune image de prévisualisation** des props : il n'existe pas
de native pour en générer, et aucun fichier de vignette n'est livré avec le jeu. Les images
doivent donc venir de vous.

Aucune n'est incluse ici pour ne pas embarquer des fichiers dont je ne maîtrise pas les droits
de redistribution.

## Sans images, ça marche quand même

Une carte sans image affiche l'icône de sa famille (🪑, 🚧, 🌳…) avec le nom lisible et le nom
du modèle. Le menu reste totalement utilisable — les vignettes sont un confort, pas une
dépendance.

## Comment les obtenir

**1. Les faire vous-même**

C'est la solution propre et la seule dont vous maîtrisez les droits. Posez le prop en jeu avec
`/spawnprop`, cadrez-le sur un fond uni, capturez, recadrez en 4:3, exportez en PNG au nom du
modèle. Long mais définitif — et vous pouvez ne le faire que pour les props que vous utilisez
vraiment (une centaine suffit largement en pratique).

**2. Une banque d'images communautaire**

Plusieurs sites communautaires publient des galeries de props avec une URL prévisible par
modèle. Si vous acceptez la dépendance externe, renseignez le motif d'URL :

```lua
Config.UI.RemoteImageURL = 'https://exemple.tld/objects/%s.png'
```

Elle n'est utilisée **qu'en repli**, quand l'image locale est absente. À savoir avant de
l'activer :

- chaque client charge les images depuis ce site : s'il tombe, les vignettes disparaissent ;
- vous envoyez du trafic vers un tiers sans garantie de disponibilité ni de pérennité ;
- vérifiez les conditions d'utilisation du site avant de le brancher sur votre serveur.

**3. Une approche mixte**

La plus raisonnable : images locales pour vos props courants (chargement instantané, aucune
dépendance), URL distante en repli pour la longue traîne du catalogue.

## Nommage

Le nom du fichier doit correspondre au modèle **en minuscules**, sans le chemin ni l'extension
dans `catalog.lua`. `Config.UI.LocalImages` vaut `images/%s.png` : `%s` est remplacé par le nom
du modèle.
