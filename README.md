# autodread

A KoLmafia script that spends your turns in your clan's Dreadsylvania the way a good clanmate would.

## Usage

```
autodread           spend your adventures (or stop when nothing useful is left)
autodread 30        the same, spending at most 30 turns
autodread pencil    open the Village and Castle if shut, collect this instance's ghost pencil, then stop (a later run records a place with it)
autodread map       the same, then record a place on your map with the pencil (fights until one turns up), then stop
autodread map 20    the same, spending at most 20 turns (also works for pencil)
autodread status    show the instance, your noncombats and your map, without adventuring
```

`autodread status` shows:
- each zone's progress (kills of 1,000, as a %) and whether the clan rule is holding it back;
- the carriageman's total;
- for each of the nine places, whether you've had your action this instance and whether it's on your map;
- the ghost pencil situation, and your Freddy Kruegerands.

## What it does, in order

1. **Ghost pencil.** Once an instance, each player can take a ghost pencil from the schoolhouse in the Village Square
   (10 a clan). If you still have places to record, autodread takes it. If the schoolhouse is locked, it first buys a
   Dreadsylvanian skeleton key at the Terrified Eagle Inn (25 Freddy Kruegerands), which unlocks it for the whole clan.
   It then adventures in a zone with a place you haven't recorded and uses the pencil there (option 5). That adds a
   permanent shortcut to your map.
2. **Your noncombats.** Each player gets one action per place per instance. Places on your map are reached straight
   away by shortcut (1 turn). It takes the option you usually take:

   | Place | Action |
   |---|---|
   | The Cabin | Freddies from the newspapers |
   | The Tallest Tree | Freddies from the footlocker, once someone has unlocked the fire tower |
   | The Burrows | Freddies from the garbage |
   | The Village Square | the ghost pencil, otherwise Freddies from the blacksmith's till |
   | The Old Duke's Estate | Freddies from the graves |
   | The Great Hall | the wax banana, or the roast if the banana's gone |
   | The Tower | Freddies from the dresser |
   | The Dungeons | Freddies from the ashes |

   Freddy options stop at the clan's 10 a instance. It **never** takes an option that banishes an element or a monster
   type: those make a zone harder for everyone. Skid Row's loot needs a Moxie class, so it's skipped.
3. **Fights**, with spells only (Saucegeyser first). Every Dread fight you've lost was a melee macro, and ghosts can't
   be hurt physically. It fights in the reachable zone furthest from done, and **never fights a boss** (it runs away,
   which costs no turn).
4. **The carriageman.** If the Village or Castle is still shut, it feeds him drinks: each drink counts its average
   adventures, and he needs 1,000 for the Village and 2,000 for the Castle. Cheap drinks you hold go first. Then it
   buys the cheapest of a few cocktails per sheet, within `autodread_carriageBudget`.

## Clan rules (Not Dead Yet)

- *"Please try not to get an area to 100% complete until the other two zones are near completion."* autodread stops
  fighting in a zone at 950 kills (95%) unless both other zones have 900. A ready boss shuts that zone's noncombats
  for everyone.
- No element or monster banishes, and no boss fights.
- The rest is up to you: keep your loot preferences in the clan's spreadsheet, and pay the stash for boss loot you're
  given.

## Settings

`set autodread_<name> = <value>`

| Setting | Default | |
|---|---|---|
| `stopAt` | `950` | kills at which a zone is held back... |
| `othersAt` | `900` | ...unless both other zones have at least this many |
| `maximize` | `mainstat, spell damage percent, moxie, 0.5 hp, 3 dr` | maximizer terms for fights |
| `dangerRounds` | `3` | rounds of expected damage that must fit in 90% of your HP |
| `castsReady` | `4` | casts of your spell to have MP for before each fight |
| `carriage` | `true` | feed the carriageman when a zone is shut |
| `carriageMaxPerSheet` | `30` | most meat per sheet a drink may cost to be given away |
| `carriageBudget` | `50000` | most meat spent buying drinks for him in one go |
| `advReserve` | `0` | adventures to leave unspent |
| `debug` | `false` | print extra detail |
