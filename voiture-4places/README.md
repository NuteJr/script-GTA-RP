# Voiture 4 Places

Ajoute **2 places arrière** aux voitures qui n'en ont que 2 (sportives, coupés, muscle cars…).
Les passagers ne sont pas assis dans un vrai siège : ils sont **attachés** à la carrosserie du
véhicule, à une position réglable, avec une animation. Le tout est synchronisé par le serveur,
donc **tous les joueurs voient les passagers** au bon endroit.

---

## Sommaire

- [Comment ça marche](#comment-ça-marche)
- [Installation](#installation)
- [Utilisation en jeu](#utilisation-en-jeu)
- [Personnalisation](#personnalisation)
  - [Régler la position des sièges](#régler-la-position-des-sièges)
  - [Changer la touche](#changer-la-touche)
  - [Changer l'animation](#changer-lanimation)
  - [Changer les messages](#changer-les-messages)
  - [Distance et délais](#distance-et-délais)
- [Quels véhicules sont concernés](#quels-véhicules-sont-concernés)
- [Dépannage](#dépannage)
- [Limites connues](#limites-connues)

---

## Comment ça marche

Le script suit le schéma **client détecte → serveur arbitre → tous les clients appliquent** :

1. **Client** (`client.lua`) : une boucle cherche en permanence une voiture 2 places proche,
   conduite par quelqu'un d'autre. Si elle en trouve une, elle affiche l'aide à l'écran et
   attend l'appui sur la touche.
2. **Serveur** (`server.lua`) : il reçoit la demande, la **vérifie** (véhicule réel, joueur
   vraiment à côté, conducteur présent et différent du demandeur, place libre), réserve un
   slot (1 = arrière gauche, 2 = arrière droit) et diffuse l'ordre à tout le monde.
3. **Tous les clients** attachent le ped du passager au véhicule à la position du slot.

Le serveur est la seule autorité : un joueur ne peut pas se téléporter sur une voiture à
l'autre bout de la map en trafiquant son client.

### Fichiers

| Fichier | Rôle |
|---|---|
| `fxmanifest.lua` | Déclaration de la ressource pour FiveM |
| `config.lua` | **Tous les réglages** — c'est le seul fichier à modifier normalement |
| `client.lua` | Détection, affichage de l'aide, attachement/détachement, animations |
| `server.lua` | Gestion des places, validations anti-triche, nettoyage |

> `config.lua` est chargé en `shared_script` : il est lu **à la fois** par le client et par le
> serveur. Modifier `Config.Distance` change donc aussi la vérification côté serveur.

---

## Installation

1. Copiez le dossier `voiture-4places` dans le dossier `resources` de votre serveur :

   ```
   server-data/
   └── resources/
       └── [custom]/
           └── voiture-4places/
               ├── fxmanifest.lua
               ├── config.lua
               ├── client.lua
               └── server.lua
   ```

2. Ajoutez la ressource dans votre `server.cfg` :

   ```cfg
   ensure voiture-4places
   ```

3. Redémarrez le serveur (ou tapez `ensure voiture-4places` dans la console live).

**Aucune dépendance** : le script fonctionne seul, sur n'importe quel framework
(ESX, QBCore, standalone…).

Le nom du dossier n'a aucune importance pour le fonctionnement, mais il doit correspondre à
ce que vous écrivez dans `server.cfg`.

---

## Utilisation en jeu

| Situation | Action |
|---|---|
| À pied, à côté d'une voiture 2 places **conduite** | Un message apparaît : appuyez sur **F** pour monter à l'arrière |
| Assis à l'arrière | Appuyez sur **F** pour descendre |
| Les 2 places arrière sont prises | Message « Les sièges arrière sont déjà complets ! » |
| Le conducteur sort du véhicule | Vous êtes automatiquement éjecté après ~1,5 s |

Le conducteur reçoit une notification quand quelqu'un monte ou descend.

---

## Personnalisation

Tout se règle dans **`config.lua`**. Après modification, faites `restart voiture-4places`
dans la console du serveur.

### Régler la position des sièges

C'est le réglage le plus important, et le seul qui demande un peu de tâtonnement.
Les positions sont **relatives au centre du véhicule**, en mètres :

```lua
Config.BackSeats = {
    [1] = { x = -0.35, y = -0.65, z = 0.35, rx = 0.0, ry = 0.0, rz = 0.0 },  -- Arrière gauche
    [2] = { x =  0.35, y = -0.65, z = 0.35, rx = 0.0, ry = 0.0, rz = 0.0 },  -- Arrière droit
}
```

| Axe | Signification |
|---|---|
| `x` | Gauche (négatif) / droite (positif) |
| `y` | Avant (positif) / arrière (négatif) |
| `z` | Bas (négatif) / haut (positif) |
| `rx` `ry` `rz` | Rotation du ped en degrés (tangage / roulis / lacet) |

**Méthode de réglage :** partez des valeurs par défaut, montez à l'arrière, et ajustez par pas
de `0.05`. Si le passager :

- **flotte au-dessus de la voiture** → baissez `z`
- **s'enfonce dans la carrosserie** → montez `z`
- **est sur le capot** → diminuez `y` (plus négatif)
- **dépasse du coffre** → augmentez `y`
- **est trop au centre / trop écarté** → ajustez `x` (les deux valeurs, opposées)
- **regarde de travers** → utilisez `rz` (par ex. `180.0` pour le retourner)

Les valeurs par défaut sont un compromis qui marche pour la plupart des sportives. Un véhicule
très long ou très bas demandera son propre réglage.

> **Astuce :** vous pouvez ajouter plus de 2 places en rajoutant des entrées `[3]`, `[4]`… mais
> il faut aussi changer la boucle `for i = 1, 2 do` dans `server.lua` (recherche du slot libre)
> pour qu'elle aille jusqu'au nouveau nombre de places.

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
quand vous êtes à portée, pour éviter que GTA tente d'ouvrir la portière en même temps.

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
Config.TextMonter    = 'Appuyez sur ~INPUT_ENTER~ pour monter à l\'arrière'
Config.TextMonte     = '~g~Vous êtes monté à l\'arrière !'
Config.TextDescendu  = '~r~Vous êtes descendu du véhicule.'
Config.TextComplet   = '~r~Les sièges arrière sont déjà complets !'
Config.TextPassMonte = '~g~Un passager est monté à l\'arrière !'
Config.TextPassDesc  = '~r~Un passager est descendu.'
Config.TextEjecte    = '~r~Le conducteur a quitté le véhicule.'
```

Codes de couleur utilisables : `~r~` rouge, `~g~` vert, `~b~` bleu, `~y~` jaune, `~w~` blanc,
`~p~` violet, `~o~` orange, `~s~` retour au style par défaut.

`~INPUT_ENTER~` affiche automatiquement la touche réellement bindée par le joueur. Si vous
changez `Config.MountKey`, pensez à changer ce code aussi (par ex. `~INPUT_PICKUP~` pour E).

### Distance et délais

```lua
Config.Distance          = 3.0    -- distance max pour voir le message et monter (mètres)
Config.DistanceTolerance = 2.0    -- marge accordée par le serveur (latence / désync)
Config.NoDriverGrace     = 1500   -- délai (ms) sans conducteur avant éjection auto
```

- **`Config.Distance`** : trop grand, le message s'affiche de loin de façon gênante ;
  trop petit, il faut se coller à la voiture.
- **`Config.DistanceTolerance`** : le serveur revérifie la distance. Comme la position connue
  du serveur a toujours un léger retard, cette marge évite les refus injustifiés.
  Ne la mettez pas à une valeur énorme, c'est ce qui empêche les montées à distance.
- **`Config.NoDriverGrace`** : si le conducteur disparaît (sortie, déconnexion), les passagers
  sont détachés après ce délai. La marge évite les fausses éjections pendant un changement de
  place ou une micro-coupure réseau.

---

## Quels véhicules sont concernés

Le script ne s'active que si **les deux conditions** sont réunies :

- la **classe** du véhicule est ≤ 7 — c'est-à-dire : Compacts, Berlines, SUV, Coupés,
  Muscle, Sports Classics, Sports, Super. Motos, vélos, bateaux, hélicos et avions sont exclus ;
- le véhicule a **au maximum 1 place passager** (donc 2 places au total avec le conducteur).

Pour modifier ce filtre, éditez `Is2SeatCar()` dans `client.lua` :

```lua
if GetVehicleClass(vehicle) > 7 then return false end
return GetVehicleMaxNumberOfPassengers(vehicle) <= 1
```

Par exemple, `<= 3` autoriserait aussi les voitures 4 places à recevoir 2 passagers de plus.

---

## Dépannage

| Symptôme | Cause probable |
|---|---|
| Rien ne s'affiche près de la voiture | Le véhicule n'est pas dans les critères (classe > 7 ou plus d'1 place passager), ou personne n'est au volant |
| Le message s'affiche mais F ne fait rien | Une autre ressource capte la même touche, ou vous êtes déjà dans un véhicule |
| Le passager est mal placé | Réglez `Config.BackSeats` — voir [Régler la position des sièges](#régler-la-position-des-sièges) |
| Les autres joueurs ne voient pas le passager | Le véhicule ou le ped n'était pas encore streamé chez eux. Le script attend 2 s ; au-delà il abandonne |
| Le passager reste collé après un crash serveur | `restart voiture-4places` : le script détache tout le monde à l'arrêt de la ressource |

Pour diagnostiquer, surveillez la console serveur (`F8` côté client) pendant l'essai.

---

## Limites connues

- Les passagers sont **attachés**, pas assis : ils ne peuvent pas tirer depuis le véhicule
  comme un vrai passager, et ne bénéficient pas de la protection des collisions.
- Les positions par défaut ne conviennent pas à **tous** les modèles ; un véhicule
  particulièrement long, bas ou exotique demandera son propre réglage.
- La détection du conducteur côté serveur utilise `GetPedInVehicleSeat`. Si votre build de
  FXServer ne l'expose pas, le script bascule automatiquement sur une méthode de repli
  (balayage des joueurs) — c'est transparent, mais moins précis si plusieurs joueurs sont
  réellement assis dans le véhicule.
