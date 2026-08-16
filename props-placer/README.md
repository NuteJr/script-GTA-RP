# Props Placer

Poser, déplacer, tourner et supprimer des **props persistants** en jeu, avec un contrôle
d'accès par joueur, et une architecture pensée pour un serveur **très peuplé**.

Les props survivent aux redémarrages du serveur, sont visibles par tout le monde, et ne
coûtent **aucune entité réseau**.

---

## Sommaire

- [Ce que fait le script](#ce-que-fait-le-script)
- [Installation](#installation)
- [Donner l'accès](#donner-laccès)
- [Commandes](#commandes)
- [Le catalogue](#le-catalogue)
- [Le mode placement](#le-mode-placement)
- [Persistance](#persistance)
- [Optimisation — comment ça tient avec 200 joueurs](#optimisation--comment-ça-tient-avec-200-joueurs)
- [Réglages](#réglages)
- [Sécurité](#sécurité)
- [Exports](#exports)
- [Dépannage](#dépannage)
- [Limites connues](#limites-connues)

---

## Ce que fait le script

| Fonction | Détail |
|---|---|
| **Catalogue** | Menu avec vignettes, familles, recherche, favoris et historique |
| **Faire apparaître** | `/spawnprop <modèle>` ouvre un mode placement avec un objet fantôme |
| **Déplacer** | `/moveprop` reprend le prop visé et le repositionne |
| **Tourner** | Molette sur 3 axes (lacet, tangage, roulis), pas fin avec MAJ |
| **Hauteur** | Flèches haut/bas, avec collage au sol automatique optionnel |
| **Supprimer** | `/delprop` sur le prop visé, `/propwipe <rayon>` pour un nettoyage de zone |
| **Persistance** | JSON ou MySQL, rechargé au démarrage du serveur |
| **Accès** | Permissions ACE, ou liste d'identifiants, avec deux niveaux (user / admin) |

---

## Installation

1. Copiez le dossier `props-placer` dans les ressources de votre serveur :

   ```
   server-data/
   └── resources/
       └── [custom]/
           └── props-placer/
               ├── fxmanifest.lua
               ├── config.lua
               ├── catalog.lua
               ├── install.sql
               ├── client/
               │   ├── streaming.lua
               │   ├── placement.lua
               │   ├── menu.lua
               │   └── commands.lua
               ├── server/
               │   ├── storage.lua
               │   └── main.lua
               ├── html/
               │   ├── index.html
               │   ├── style.css
               │   ├── app.js
               │   └── images/          ← vos vignettes (voir le README dedans)
               └── data/
                   └── props.json
   ```

2. Dans `server.cfg` :

   ```cfg
   ensure props-placer
   ```

3. Donnez-vous l'accès (voir la section suivante), puis testez avec :

   ```
   /props                        → ouvre le catalogue
   /spawnprop prop_bench_01a     → pose directement par nom de modèle
   ```

**Aucune dépendance obligatoire.** `oxmysql` n'est nécessaire que si vous passez la
persistance en MySQL.

> Le dossier `data/` et le fichier `props.json` doivent exister et être **accessibles en
> écriture** par le serveur — c'est là que les props sont enregistrés en mode JSON.

---

## Donner l'accès

Deux méthodes, cumulables. Il y a **deux niveaux** :

| Niveau | Droits |
|---|---|
| `props.manage` (*user*) | Poser, déplacer et supprimer **ses propres** props |
| `props.admin` (*admin*) | En plus : modifier les props **des autres**, `/propwipe`, ignorer le quota |

### Méthode 1 — permissions ACE (recommandée)

Dans `server.cfg` :

```cfg
## Un groupe complet
add_ace group.admin props.admin allow
add_ace group.moderator props.manage allow

## Ou un joueur précis, par son identifiant
add_principal identifier.license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx group.admin
```

Vous pouvez aussi créer un groupe dédié :

```cfg
add_ace group.builder props.manage allow
add_principal identifier.license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx group.builder
```

### Méthode 2 — liste d'identifiants dans `config.lua`

Pratique pour accorder l'accès à une personne sans toucher aux groupes ACE :

```lua
Config.AllowedIdentifiers = {
    ['license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'] = 'admin',
    ['license:yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy'] = 'user',
}
```

Pour trouver la licence d'un joueur connecté, tapez `status` dans la console du serveur.

Le type d'identifiant est réglable avec `Config.IdentifierType` (`license`, `steam`,
`discord`, `fivem`…). C'est aussi lui qui sert à déterminer **le propriétaire** d'un prop.

> Un joueur sans accès ne voit même pas les commandes dans les suggestions du chat, et le
> serveur rejette toutes ses demandes de toute façon.

---

## Commandes

| Commande | Niveau | Effet |
|---|---|---|
| `/props` | user | Ouvre le catalogue (vignettes, familles, favoris) |
| `/spawnprop <modèle>` | user | Ouvre le mode placement pour un nouveau prop |
| `/moveprop` | user | Reprend le prop visé (position + rotation) |
| `/delprop` | user | Supprime le prop visé |
| `/propinfo` | user | Modèle, id et coordonnées du prop visé (détails en console F8) |
| `/propcount` | user | Nombre de props chargés localement et sur le serveur |
| `/propwipe [rayon]` | **admin** | Supprime tous les props dans le rayon (défaut 10 m) |

Le « prop visé » est celui que vous regardez (raycast depuis la caméra). Si vous ne visez rien
de précis, le script prend le plus proche de vous.

Les noms de commandes sont modifiables dans `Config.Commands` (et `Config.UI.Command` pour le
catalogue).

`/props` est aussi enregistrée comme **touche assignable** : chaque joueur choisit la sienne
dans *Paramètres → Commandes → FiveM → « Ouvrir le catalogue de props »*. Aucune touche n'est
imposée par défaut, pour ne pas écraser un bind existant — mettez-en une dans
`Config.UI.DefaultKey` (ex. `'F6'`) si vous préférez.

---

## Le catalogue

`/props` ouvre un menu plein écran :

- **Familles** dans la colonne de gauche (mobilier urbain, chantier, tables & chaises, caisses,
  nourriture, nature, éclairage, bureau, divers), avec le nombre de props de chacune ;
- **Tous / ★ Favoris / 🕘 Récents** en haut de la même colonne ;
- **Recherche** instantanée sur le nom lisible, le nom du modèle *et* le nom de la famille ;
- **Grille de vignettes** : clic pour passer directement en mode placement, clic sur l'étoile
  pour mettre en favori ;
- **Échap** pour fermer, **Entrée** dans la recherche pour prendre le premier résultat.

Favoris et récents sont enregistrés **chez le joueur** (KVP local) : ils survivent aux
reconnexions et ne coûtent rien au serveur.

Si vous cherchez un modèle absent du catalogue, tapez son nom exact : un bouton
« Placer *nom* quand même » apparaît. `/spawnprop <modèle>` reste disponible et fait la même
chose sans passer par le menu.

### Modifier le catalogue

Tout est dans **`catalog.lua`**, en clair :

```lua
{ id = 'urbain', label = 'Mobilier urbain', icon = '🏙️', props = {
    'prop_bench_01a',
    'prop_bin_01a',
    { model = 'prop_postbox_01a', label = 'Boîte aux lettres' },  -- libellé forcé
}},
```

Sans `label`, le menu en génère un lisible depuis le nom du modèle
(`prop_bench_01a` → « Bench 01a »). Pour ajouter une famille, copiez un bloc et changez `id`,
`label` et `icon` (n'importe quel emoji).

**Les modèles inexistants sont masqués automatiquement.** À l'ouverture du menu, le client
vérifie chaque modèle avec `IsModelInCdimage`. Vous pouvez donc lister sans risque des props
issus de vos ressources streamées : ils apparaissent chez les joueurs qui les ont et nulle part
ailleurs. C'est aussi le filet de sécurité si un nom du catalogue fourni est erroné —
il disparaît au lieu de provoquer une erreur.

### Les vignettes

**GTA V ne fournit aucune image de prop** : il n'existe pas de native pour en générer, et rien
n'est livré avec le jeu. Elles doivent donc venir de vous. Sans image, chaque carte affiche
l'icône de sa famille et reste parfaitement utilisable.

Déposez vos PNG dans `html/images/`, nommés exactement comme le modèle :

```
html/images/prop_bench_01a.png
```

Un repli distant est disponible si vous acceptez une dépendance externe :

```lua
Config.UI.RemoteImageURL = 'https://exemple.tld/objects/%s.png'
```

Il n'est utilisé que lorsque l'image locale est absente. Le détail (comment produire les
images, ce qu'implique le repli distant) est dans `html/images/README.md`.

### Performance du menu

Le catalogue est construit **une seule fois** et mis en cache : les vérifications de modèles ne
sont pas refaites à chaque ouverture. Les cartes sont rendues **par paquets de
`Config.UI.PageSize`** avec défilement infini, et les images utilisent le lazy loading natif du
navigateur. Avec 500 props dans une famille, 60 cartes existent dans le DOM au démarrage, et le
navigateur ne télécharge que les images visibles.

---

## Le mode placement

Un objet semi-transparent suit votre visée. Rien n'est envoyé au serveur tant que vous n'avez
pas validé — vous pouvez tourner autour de l'objet et l'ajuster autant que vous voulez sans
générer un seul paquet réseau.

| Touche | Action |
|---|---|
| **Souris** | Vise l'endroit où poser le prop |
| **Molette** | Tourne le prop sur l'axe courant |
| **G** | Change d'axe de rotation : Z (lacet) → X (tangage) → Y (roulis) |
| **↑ / ↓** | Monte / descend le prop |
| **MAJ** (maintenu) | Pas fin (0,5° au lieu de 5°, 1 cm au lieu de 10 cm) |
| **X** | Active/désactive le collage au sol |
| **H** | Remet la rotation et la hauteur à zéro |
| **Entrée** | Valider |
| **Retour arrière** | Annuler |

Le collage au sol utilise les **dimensions réelles du modèle** : c'est la *base* de l'objet qui
est posée sur le sol, pas son centre. Un banc ne s'enfonce donc pas à moitié dans le bitume.

Toutes ces touches sont dans `Config.Keys`.

### Trouver des noms de modèles

Les modèles sont ceux du jeu de base ou de vos ressources streamées. Bases de données utiles :

- [gta5-mods / objects](https://www.gta5-mods.com/)
- [Prop list — forge.plebmasters.de](https://forge.plebmasters.de/objects)

Exemples qui fonctionnent partout : `prop_bench_01a`, `prop_barrier_work05`,
`prop_roadcone02a`, `prop_beer_bottle`, `prop_table_03`.

---

## Persistance

### Backend JSON (par défaut)

```lua
Config.Storage      = 'json'
Config.JsonFile     = 'data/props.json'
Config.SaveInterval = 30000   -- ms
```

Les écritures sont **regroupées** : le script marque les données comme modifiées et n'écrit le
fichier qu'une fois toutes les 30 secondes, plus une écriture immédiate à l'arrêt de la
ressource. Poser 100 props d'affilée provoque **1 écriture disque**, pas 100.

Sauvegardez `data/props.json` comme n'importe quel fichier — c'est tout votre décor.

### Backend MySQL

```lua
Config.Storage    = 'mysql'
Config.MySQLTable = 'placed_props'
```

1. Exécutez `install.sql` sur votre base.
2. Assurez-vous qu'`oxmysql` démarre **avant** cette ressource dans `server.cfg`.

Les requêtes sont asynchrones (`exports.oxmysql`), elles ne bloquent jamais le tick serveur.
Si `oxmysql` n'est pas démarré, le script bascule automatiquement sur le JSON en l'annonçant
dans la console plutôt que de planter.

### Migrer JSON → MySQL

Le format JSON est un simple tableau d'objets aux mêmes noms de colonnes (`id`, `model`,
`x`…`rz`, `owner`, `ownerName`, `createdAt`) : un import direct est trivial.

---

## Optimisation — comment ça tient avec 200 joueurs

C'est le point de conception central. Quatre mécanismes :

### 1. Les props ne sont pas des entités réseau

Chaque client crée ses propres objets **en local** (`CreateObjectNoOffset` avec
`isNetwork = false`). Conséquences :

- **zéro** entité réseau créée sur le serveur, quel que soit le nombre de props ;
- **zéro** synchronisation continue — un prop figé n'envoie aucun paquet ;
- pas de consommation du budget d'entités réseau du serveur, qui est limité et partagé avec
  les véhicules et les joueurs.

Le serveur ne transmet que des **coordonnées**. Un prop coûte une centaine d'octets, une fois.

### 2. Streaming par grille spatiale

La map est découpée en cellules de `Config.CellSize` mètres. Le client s'abonne aux cellules
autour de lui (`Config.CellRadius`), le serveur ne lui envoie **que celles-là**, et uniquement
celles qu'il n'a pas déjà.

Un joueur à Paleto ne reçoit jamais les 3000 props de Los Santos. En quittant une zone, les
données correspondantes sont libérées côté client.

### 3. Diffusion ciblée

Le serveur mémorise les cellules auxquelles chaque joueur est abonné. Quand un prop est posé,
déplacé ou supprimé, le paquet part **uniquement vers les joueurs qui regardent cette zone** —
pas en `-1` vers tout le serveur. Avec 200 joueurs répartis sur la map, poser un prop envoie
typiquement 2 ou 3 messages au lieu de 200.

### 4. Création étalée et hystérésis

- Les objets ne sont créés que dans `Config.RenderDistance`, par paquets de
  `Config.MaxSpawnPerPass` toutes les `Config.RenderInterval` ms : arriver en voiture dans une
  zone à 200 props ne provoque pas de micro-freeze.
- La suppression se fait à `RenderDistance × Config.DespawnFactor` : un objet ne clignote pas
  quand on fait des allers-retours pile à la limite.
- `Config.MaxObjects` plafonne le nombre d'objets créés simultanément, pour protéger le pool
  d'entités du jeu.
- `SetEntityLodDist` réduit la distance de LOD de chaque prop.

### Réglages selon la charge

| Situation | Ajustement |
|---|---|
| Serveur très peuplé, FPS en baisse | Baissez `RenderDistance` (80), `MaxObjects` (250), montez `RenderInterval` (750) |
| Décor dense sur une petite zone | Baissez `CellSize` (100) pour des paquets plus petits |
| Grands espaces, props éparpillés | Montez `CellSize` (250) et `RenderDistance` |
| Micro-freezes à l'arrivée en zone | Baissez `MaxSpawnPerPass` (3) |

---

## Réglages

Tout est dans `config.lua`, avec un commentaire par option. Les plus utiles :

```lua
Config.MaxProps          = 5000   -- plafond serveur
Config.MaxPropsPerPlayer = 250    -- quota par joueur (0 = illimité, admins exemptés)
Config.ActionCooldown    = 250    -- ms entre deux actions d'un même joueur
Config.OnlyOwnerCanEdit  = true   -- un joueur ne touche pas aux props des autres
Config.Frozen            = true   -- props figés (recommandé : pas de physique = pas de coût)
Config.Collisions        = true   -- props solides
```

Restreindre les modèles autorisés :

```lua
-- Liste blanche : SEULS ces modèles sont posables
Config.ModelWhitelist = {
    ['prop_bench_01a']      = true,
    ['prop_barrier_work05'] = true,
}

-- Liste noire : toujours refusés
Config.ModelBlacklist = {
    ['prop_beach_fire'] = true,
}
```

Après modification : `restart props-placer`.

---

## Sécurité

Le serveur est la seule autorité. À chaque événement reçu, il vérifie :

- **l'accès** du joueur (ACE ou liste d'identifiants) — jamais une valeur envoyée par le client ;
- un **cooldown** par joueur (`Config.ActionCooldown`) contre le spam d'événements ;
- les **quotas** serveur et par joueur ;
- le **modèle** demandé (format du nom, liste blanche/noire) ;
- les **coordonnées** : type numérique, `NaN`/infini rejetés, bornes de map ;
- la **propriété** du prop pour un déplacement ou une suppression ;
- la **taille** des demandes d'abonnement (un client ne peut pas réclamer toute la map d'un coup).

Les commandes sont enregistrées côté client pour que le mode placement s'ouvre sans
aller-retour réseau : c'est du confort d'affichage, pas un contrôle. Un client modifié qui
appelle les événements directement se fait rejeter exactement de la même façon.

---

## Exports

Pour piloter le décor depuis une autre ressource :

```lua
-- Liste complète des props
local list = exports['props-placer']:GetProps()

-- Poser un prop (renvoie son id, ou nil si refusé)
local id = exports['props-placer']:AddProp('prop_bench_01a', {
    x = 215.7, y = -810.2, z = 30.7, rz = 90.0
})

-- Supprimer un prop
exports['props-placer']:RemoveProp(id)
```

Ces exports passent par les mêmes validations et la même persistance que les commandes.

---

## Dépannage

| Symptôme | Cause probable |
|---|---|
| « Vous n'avez pas accès aux props » | Aucune permission accordée — voir [Donner l'accès](#donner-laccès). Reconnectez-vous après un `add_ace` |
| Le menu est vide ou une famille manque | Les modèles listés n'existent pas dans le jeu du joueur : ils sont masqués volontairement. Passez `Config.Debug = true` pour voir le décompte en console |
| Les cartes n'ont pas d'image | Normal tant que `html/images/` est vide — voir [Les vignettes](#les-vignettes) |
| Le menu s'ouvre mais la souris ne répond pas | Une autre ressource garde le focus NUI. Testez avec les autres menus fermés |
| `/props` ne fait rien | La touche assignable n'est pas bindée **et** la commande a été renommée dans `Config.UI.Command` |
| Les commandes n'apparaissent pas dans le chat | Normal sans accès : les suggestions ne sont ajoutées qu'aux joueurs autorisés |
| « Modèle inconnu » | Le nom est faux, ou la ressource qui stream ce modèle n'est pas démarrée |
| Le prop disparaît quand je m'éloigne | Comportement voulu : `Config.RenderDistance`. Montez-la si besoin |
| Les props ne reviennent pas après un redémarrage | Vérifiez les droits d'écriture sur `data/props.json`, ou la console au démarrage (`[props][storage]`) |
| `oxmysql introuvable` dans la console | `Config.Storage = 'mysql'` mais oxmysql n'est pas démarré : le script est repassé en JSON |
| Le prop s'enfonce dans le sol | Désactivez le collage au sol (**X**) et ajustez à la main avec les flèches |
| Micro-freeze en arrivant dans une zone dense | Baissez `Config.MaxSpawnPerPass` |

Activez `Config.Debug = true` pour des logs détaillés côté client et serveur.

---

## Limites connues

- Les props étant **locaux à chaque client**, ils ne sont pas visibles par les autres
  ressources qui parcourent les entités réseau (certains scripts anticheat ou de raycast
  serveur ne les verront pas).
- Un prop figé n'a pas de physique : il ne tombera pas si vous le placez en l'air, et ne peut
  pas être poussé. C'est voulu — c'est ce qui rend le décor gratuit en performance.
- Pas d'annulation (`undo`) ni d'historique : une suppression est définitive une fois
  enregistrée.
- Pas de copier/coller ni de sélection multiple.
- **Aucune vignette n'est fournie** : le dossier `html/images/` est vide au départ, pour ne pas
  redistribuer des fichiers dont je ne maîtrise pas les droits. Le menu fonctionne sans, avec
  les icônes de famille.
- Le catalogue livré est un point de départ (environ 300 modèles courants), pas un inventaire
  exhaustif des props du jeu — il y en a plusieurs milliers. `catalog.lua` est fait pour être
  étendu.
- La rotation se règle axe par axe ; il n'y a pas de gizmo 3D à la souris.
- `Config.MaxObjects` peut masquer des props dans une zone extrêmement dense : les objets
  créés sont ceux rencontrés en premier, sans tri par distance.
