# BMX 2 Places

Permet à **2 joueurs de rouler ensemble sur un BMX** : un conducteur, un passager debout/assis
derrière. Le passager est **attaché** au vélo à une position réglable, avec une animation, et
l'attachement est **synchronisé par le serveur** — tous les joueurs voient le duo.

Le script fournit aussi un **item `ox_inventory`** qui fait apparaître un BMX depuis
l'inventaire.

---

## Sommaire

- [Comment ça marche](#comment-ça-marche)
- [Installation](#installation)
  - [1. La ressource](#1-la-ressource)
  - [2. L'item ox_inventory](#2-litem-ox_inventory)
  - [3. Se passer d'ox_inventory](#3-se-passer-doxinventory)
- [Utilisation en jeu](#utilisation-en-jeu)
- [Personnalisation](#personnalisation)
  - [Régler la position du passager](#régler-la-position-du-passager)
  - [Changer le modèle de vélo](#changer-le-modèle-de-vélo)
  - [Changer la touche](#changer-la-touche)
  - [Changer l'animation](#changer-lanimation)
  - [Changer les messages](#changer-les-messages)
  - [Distance et délais](#distance-et-délais)
- [Dépannage](#dépannage)
- [Limites connues](#limites-connues)

---

## Comment ça marche

Le script suit le schéma **client détecte → serveur arbitre → tous les clients appliquent** :

1. **Client** (`client.lua`) : une boucle cherche un BMX proche, monté par quelqu'un d'autre.
   Si elle en trouve un, elle affiche l'aide à l'écran et attend l'appui sur la touche.
2. **Serveur** (`server.lua`) : il reçoit la demande, la **vérifie** (entité réelle du bon
   modèle, joueur vraiment à côté, conducteur présent et différent du demandeur, place libre),
   réserve la place et diffuse l'ordre à tout le monde.
3. **Tous les clients** attachent le ped du passager au vélo.

Le serveur est la seule autorité : un joueur ne peut pas s'attacher à un vélo à l'autre bout de
la map en trafiquant son client.

En parallèle, le serveur enregistre un hook `useItem` d'`ox_inventory` : quand le joueur
utilise l'item, l'item est consommé et le client fait apparaître un BMX devant lui.

### Fichiers

| Fichier | Rôle |
|---|---|
| `fxmanifest.lua` | Déclaration de la ressource pour FiveM |
| `config.lua` | **Tous les réglages** — c'est le seul fichier à modifier normalement |
| `client.lua` | Détection, aide à l'écran, attachement/détachement, animation, spawn du BMX |
| `server.lua` | Gestion de la place, validations anti-triche, hook ox_inventory, nettoyage |

> `config.lua` est chargé en `shared_script` : il est lu **à la fois** par le client et par le
> serveur. Modifier `Config.Distance` change donc aussi la vérification côté serveur.

---

## Installation

### 1. La ressource

Copiez le dossier `bmx-2places` dans le dossier `resources` de votre serveur :

```
server-data/
└── resources/
    └── [custom]/
        └── bmx-2places/
            ├── fxmanifest.lua
            ├── config.lua
            ├── client.lua
            └── server.lua
```

Puis ajoutez-le à votre `server.cfg`, **après** `ox_inventory` :

```cfg
ensure ox_inventory
ensure bmx-2places
```

L'ordre compte : le script appelle `exports.ox_inventory:registerHook(...)` au démarrage.

### 2. L'item ox_inventory

Ajoutez l'item dans `ox_inventory/data/items.lua` :

```lua
['bmx'] = {
    label = 'BMX',
    weight = 8000,
    stack = false,
    close = true,
    description = 'Un BMX pliable, prêt à rouler.',
    client = {
        image = 'bmx.png'
    }
},
```

Placez ensuite une image `bmx.png` dans `ox_inventory/web/images/`, puis
`restart ox_inventory`.

Pour vous donner l'item et tester :

```
/giveitem 1 bmx 1
```

> Le nom de l'item doit correspondre à `Config.ItemName` dans `config.lua`.
> Si vous préférez un autre nom (`velo`, `bmx_pliable`…), changez-le **aux deux endroits**.

### 3. Se passer d'ox_inventory

Le système de passager fonctionne très bien sans inventaire — seul le **spawn par item** en
dépend. Si vous n'utilisez pas `ox_inventory` :

1. Supprimez le bloc `exports.ox_inventory:registerHook('useItem', ...)` en haut de
   `server.lua` (sans quoi la ressource plantera au démarrage, l'export n'existant pas).
2. Remplacez-le éventuellement par une commande de test :

   ```lua
   RegisterCommand('bmx', function(source)
       TriggerClientEvent('bmx:spawnFromItem', source)
   end, false)
   ```

Les joueurs peuvent alors utiliser n'importe quel BMX déjà présent dans le monde.

---

## Utilisation en jeu

| Situation | Action |
|---|---|
| Utiliser l'item **BMX** dans l'inventaire | Un BMX apparaît devant vous, l'item est consommé |
| À pied, à côté d'un BMX **monté par quelqu'un** | Un message apparaît : appuyez sur **F** pour monter derrière |
| Assis derrière | Appuyez sur **F** pour descendre |
| La place est déjà prise | Message « Il y a déjà quelqu'un derrière ! » |
| Le conducteur descend du vélo | Vous êtes automatiquement éjecté après ~1,5 s |

Le conducteur reçoit une notification quand quelqu'un monte ou descend.

---

## Personnalisation

Tout se règle dans **`config.lua`**. Après modification, faites `restart bmx-2places`
dans la console du serveur.

### Régler la position du passager

C'est le réglage le plus important, et le seul qui demande un peu de tâtonnement.
La position est **relative au centre du vélo**, en mètres :

```lua
Config.OffsetX =  0.0    -- gauche (négatif) / droite (positif)
Config.OffsetY = -0.42   -- avant (positif) / arrière (négatif)
Config.OffsetZ =  0.58   -- bas (négatif) / haut (positif)
```

**Méthode de réglage :** montez derrière quelqu'un et ajustez par pas de `0.05`.
Si le passager :

- **flotte au-dessus du vélo** → baissez `Config.OffsetZ`
- **s'enfonce dans le cadre** → montez `Config.OffsetZ`
- **est collé au guidon** → diminuez `Config.OffsetY` (plus négatif)
- **traîne derrière la roue** → augmentez `Config.OffsetY`
- **penche d'un côté** → ajustez `Config.OffsetX` (normalement `0.0`, le passager est centré)

Valeurs de départ typiques : `Y` entre `-0.30` et `-0.55`, `Z` entre `0.45` et `0.70`.

### Changer le modèle de vélo

```lua
Config.BMXModel = 'bmx'
```

Fonctionne avec n'importe quel modèle de vélo (voire de moto) : `scorcher`, `cruiser`,
`fixter`, `tribike`, `bmx`… Le serveur vérifie que le véhicule visé correspond bien à ce
modèle, donc **un seul modèle à la fois** est pris en charge.

Chaque modèle a une géométrie différente : après un changement, refaites le réglage des
offsets ci-dessus.

### Changer la touche

```lua
Config.MountKey = 23   -- F
```

Quelques identifiants courants :

| Valeur | Touche |
|---|---|
| `23` | F |
| `38` | E |
| `47` | G |
| `74` | H |
| `26` | C |
| `73` | X |

Liste complète : [docs.fivem.net — Controls](https://docs.fivem.net/docs/game-references/controls/).

La même touche sert à monter **et** à descendre. Le script la désactive temporairement
quand vous êtes à portée, pour éviter que GTA tente de vous faire monter sur le vélo
normalement (et éjecte le conducteur) au même moment.

### Changer l'animation

```lua
Config.AnimDict = 'amb@world_human_seat_ground@male@base'
Config.AnimName = 'base'
```

Mettez `Config.AnimDict = ''` pour **désactiver** l'animation (le ped garde sa pose par défaut).

Pour trouver d'autres animations, cherchez un dictionnaire et un nom compatibles sur
[Animation List (Alex Guirre)](https://alexguirre.github.io/animations-list/). Une animation
assise (`seat`, `sit`) donne le meilleur rendu.

### Changer les messages

```lua
Config.TextMonter    = 'Appuyez sur ~INPUT_ENTER~ pour monter derrière'
Config.TextMonte     = '~g~Vous êtes monté derrière !'
Config.TextDescendu  = '~r~Vous êtes descendu du BMX.'
Config.TextOccupe    = '~r~Il y a déjà quelqu\'un derrière !'
Config.TextPassMonte = '~g~Un passager est monté derrière vous !'
Config.TextPassDesc  = '~r~Le passager est descendu.'
Config.TextEjecte    = '~r~Le conducteur a quitté le BMX.'
```

Codes de couleur utilisables : `~r~` rouge, `~g~` vert, `~b~` bleu, `~y~` jaune, `~w~` blanc,
`~p~` violet, `~o~` orange, `~s~` retour au style par défaut.

`~INPUT_ENTER~` affiche automatiquement la touche réellement bindée par le joueur. Si vous
changez `Config.MountKey`, pensez à changer ce code aussi (par ex. `~INPUT_PICKUP~` pour E).

### Distance et délais

```lua
Config.Distance          = 2.5    -- distance max pour voir le message et monter (mètres)
Config.DistanceTolerance = 2.0    -- marge accordée par le serveur (latence / désync)
Config.NoDriverGrace     = 1500   -- délai (ms) sans conducteur avant éjection auto
```

- **`Config.Distance`** : un vélo est petit, `2.5` est un bon compromis. Trop grand, le
  message s'affiche de loin de façon gênante.
- **`Config.DistanceTolerance`** : le serveur revérifie la distance. Comme la position connue
  du serveur a toujours un léger retard, cette marge évite les refus injustifiés.
  Ne la mettez pas à une valeur énorme, c'est ce qui empêche les montées à distance.
- **`Config.NoDriverGrace`** : si le conducteur disparaît (descente, déconnexion), le passager
  est détaché après ce délai. La marge évite les fausses éjections pendant une micro-coupure
  réseau.

---

## Dépannage

| Symptôme | Cause probable |
|---|---|
| Erreur au démarrage sur `registerHook` | `ox_inventory` n'est pas démarré, ou l'est **après** cette ressource — vérifiez l'ordre dans `server.cfg` |
| L'item ne fait rien | Le nom dans `items.lua` ne correspond pas à `Config.ItemName` |
| L'item est consommé mais aucun vélo n'apparaît | Le modèle de `Config.BMXModel` est invalide ou introuvable |
| Rien ne s'affiche près du BMX | Personne n'est sur le vélo, ou le modèle ne correspond pas à `Config.BMXModel` |
| Le message s'affiche mais F ne fait rien | Une autre ressource capte la même touche, ou vous êtes déjà dans un véhicule |
| Le passager est mal placé | Réglez les offsets — voir [Régler la position du passager](#régler-la-position-du-passager) |
| Les autres joueurs ne voient pas le passager | Le vélo ou le ped n'était pas encore streamé chez eux. Le script attend 2 s ; au-delà il abandonne |
| Le passager reste collé après un crash serveur | `restart bmx-2places` : le script détache tout le monde à l'arrêt de la ressource |

Pour diagnostiquer, surveillez la console serveur et la console client (`F8`) pendant l'essai.

---

## Limites connues

- **Une seule place passager** par vélo, par conception.
- Le passager est **attaché**, pas assis : il ne peut pas tirer depuis le vélo comme un vrai
  passager, et ne bénéficie pas de la protection des collisions.
- Le vélo créé par l'item est un véhicule normal : il **n'est pas persistant** et disparaîtra
  au bout d'un moment s'il est laissé sans surveillance. L'item n'est pas rendu dans ce cas.
- Un seul modèle de vélo est pris en charge à la fois (`Config.BMXModel`).
- La détection du conducteur côté serveur utilise `GetPedInVehicleSeat`. Si votre build de
  FXServer ne l'expose pas, le script bascule automatiquement sur une méthode de repli
  (balayage des joueurs) — c'est transparent dans l'usage normal.
