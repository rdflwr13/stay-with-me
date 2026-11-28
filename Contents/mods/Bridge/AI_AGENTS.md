# Stay With Me: guide for AI agents

This file is for an AI agent (a coding assistant or any program driven by a language model) that a player connects to the game. The mod has a bridge: a few plain text files the game reads and writes while you play. Through them an agent can see what is going on, talk as the companion, and give her orders.

Read the whole file before you send the first command.

## What you need

- Project Zomboid Build 42 with Stay With Me enabled.
- Read and write access to the player's `Zomboid/Lua/bridge/` folder:
  - Windows: `C:\Users\<user>\Zomboid\Lua\bridge\`
  - macOS and Linux: `~/Zomboid/Lua/bridge/`
- The player in a loaded world. The bridge does nothing in the main menu.

## How the bridge turns on

The game checks every 5 seconds whether `bridge/in.txt` exists. If it does, the bridge is on. If you delete it, the bridge turns off.

When the bridge turns on, the mod skips every command already in `in.txt` and remembers the highest number. Only lines added after that are executed. So you never replay old commands by accident, and you must always use numbers higher than the last one.

## Files

| File | Who writes | What it is |
|---|---|---|
| `in.txt` | you | Commands, one per line. Append new lines. |
| `out.txt` | game | State snapshot. Rewritten whole each time. |
| `chat.txt` | game | What the player types in chat. Appended. |
| `events.txt` | game | What the companion says. Appended. Only with `events on`. |
| `movement-trace.txt` | game | Movement log dump from `logdump`. Only with `verbose on`. |

### in.txt

Each line is a number, a space, the command and its arguments:

```
41 diag on
42 say hex:48656c6c6f
43 goto 10102 8246 0
```

- The number must grow. A line whose number is not higher than the last executed one is ignored.
- Commands are read twice a second, all new lines at once, in order.
- You may trim old lines from the file, but never restart the numbering while the game is running.
- While the game is paused nothing is read or executed. A command that seems ignored may just be waiting for the pause to end.
- Plain English text can be written as is, spaces included. Anything with other letters goes as hex with the `hex:` prefix: UTF-8 bytes, two hex digits each. The game mangles raw non-ASCII text in files. Characters outside the basic plane, such as emoji, come out as `?`.

### out.txt

Lines of `key=value`. It is written:

- after commands run;
- every 5 seconds, but only after `diag on`;
- in full detail once after `diag full`.

Without `diag on` the file goes stale. Turn it on first.

The keys you will use most:

| Key | Meaning |
|---|---|
| `tick` | Game frame counter. If it does not grow, the game is paused or closed. |
| `ack` | Number of the last executed command. |
| `result` | `<number>: <reply>` of the last executed command. |
| `mode` | `follow`, `wait`, `rest` or `home`. |
| `red_x`, `red_y`, `red_z`, `red_health` | Player position and health. The `red` prefix means the player, whatever their name. |
| `body_alive`, `body_x`, `body_y`, `body_z`, `body_health` | Companion. |
| `body_pathing`, `body_moving`, `path_result` | Is she walking, and how the path search went. |
| `task` | Current job, if any. |
| `fight`, `fight_target` | Combat state. |
| `dist` | Distance between companion and player. |
| `target` | Where `goto` sent her, or `none`. |

`diag full` adds wounds, mood, relationship, items, nearby zombies, chat counters and much more. Use it when you need detail, not every turn.

### chat.txt

One line per chat message: `<seq> <author hex> <text hex>`. Decode both from hex. The companion's own lines are not written here.

`seq` starts from 1 again every time the game starts, while the file keeps growing. Track how many lines you have read, not the `seq` value.

### events.txt

One line per thing the companion said: `<tick> <kind> <text hex>`. Only after `events on`. Useful to avoid repeating her or talking over her.

## Rules for a good agent

- Read `out.txt` before acting and after. Check `ack` to know your command was executed, and `result` for the reply.
- Only the last reply is kept in `result`. If you send several commands at once, you will see only the last one's reply. Send one command at a time when the reply matters. With `verbose on`, every command's reply is also written to the game's `console.txt` (in the `Zomboid` folder) as `[Bridge] cmd <number> -> <reply>`.
- `wait <ticks>` pauses reading of `in.txt` for that many game frames. At 60 frames per second `wait 600` is about 10 seconds, but it is longer when the game runs slower. Plain `wait` without a number is different: it tells the companion to stay in place.
- Talk to the player through `say`, short and in character. Do not post logs, numbers or technical notes in the game chat.
- The player is in charge. Do not move them (`ptp`) or change their game without being asked.
- If something fails, the `result` line says why. Read it before trying again.

## Commands

Arguments in `<>` are required, in `[]` optional. Coordinates are world tiles: `x y z`, where `z` is the floor (0 is ground).

### Bridge and diagnostics

| Command | What it does |
|---|---|
| `status` | Replies `ok`. Use it to test the connection. |
| `diag on` / `diag off` | Keep `out.txt` updated every 5 seconds. |
| `diag` / `diag full` | Write `out.txt` once, short or full. |
| `events on` / `events off` | Write the companion's lines to `events.txt`. |
| `verbose on` / `verbose off` | Detailed mod log in the game's `console.txt`. Needed for `logdump`. |
| `trace [ticks]` | Per-frame movement trace in the log, 300 frames by default. |
| `logdump` | Save the recent movement log to `movement-trace.txt`. |
| `wait <ticks>` | Pause reading of further commands. |
| `scenario <name>` | Run every line of `bridge/scenario-<name>.txt` at once, without numbers. Lines starting with `#` are skipped. `wait` inside a scenario does not pause it. |
| `assert arrived` | `PASS` if she is within reach of her `goto` or job target. |
| `assert moving` | `PASS` if she is following a path right now. |
| `assert stuck` / `assert nostuck` | Whether she has been standing still for 60+ frames. |
| `assert clear` | `PASS` if she has no job and no path. |
| `assert` | Distance and progress numbers for the current route. |
| `sq <x> <y> [z]` | What is on a tile and whether its four sides are blocked. |
| `doors [radius]` | Doors and gates around the player. |

### Companion: presence and movement

| Command | What it does |
|---|---|
| `call` | Bring the companion into the world near the player. |
| `goodbye` | She says goodbye and leaves. |
| `come` | Move her next to the player at once. |
| `go` | Follow the player. |
| `wait` | Stay here. |
| `rest` | Rest mode. |
| `mode <follow\|wait\|rest\|home>` | Set mode directly. `home` needs a home set first. |
| `stop` | Stop walking and cancel the current job. |
| `goto <x> <y> [z]` | Walk to a tile. |
| `walk <type>` / `walk auto` | Force a walk type, or give the choice back to the mod. |
| `keep behind` | Keep behind the player when following. |
| `far on` / `far off` | Follow at a longer or the usual distance. |
| `tp <x> <y> [z]` | Teleport the companion. For testing. |
| `ptp <x> <y> [z]` | Teleport the player. For testing, only when the player asks. |

### Companion: talking and body

| Command | What it does |
|---|---|
| `say <text>` | She says it. Use `say hex:<hex>` for anything beyond plain English. |
| `voice <name>` | Play a female voice line, `ShoutHey` by default. |
| `quiet on` / `quiet off` | Silence or allow her automatic lines. Your `say` still works. |
| `sit` / `sleep` / `stand` | Pose. |
| `anim <name> [seconds]` | Play an animation, 4 seconds by default. |
| `name <text>` | Rename her. |

### Combat and care

| Command | What it does |
|---|---|
| `combat <mode>` | `bodyguard`, `escort`, `aggressive`, `backup` or `stayback`. |
| `wounds` | The player's wounds by body part. |
| `heal` / `heal stop` | She treats the player's wounds with what she and the player carry. |
| `kills` | Her kill count. |

### Work

| Command | What it does |
|---|---|
| `look [radius]` | Containers, corpses and items around the player, numbered. Up to 15 tiles. |
| `take <n> [Type]` | She collects from entry `n` of the last `look`, everything or only `Type`. |
| `job <kind> <x> <y> [z]` | Start a job at a tile. |
| `chop` | Chop the nearest tree. |
| `task` | What she is doing now. |
| `chores` | Housework status and controls. `chores` alone prints the options. |
| `shower start\|stop` / `bath start\|stop` | Wash at the nearest shower or bath. |
| `exercise` / `exercise stop` | Work out. |
| `read status\|books\|start\|stop` | Reading. |
| `items` | What she carries. |

Job kinds for `job`: `animalCare`, `bath`, `brushTeeth`, `chopTree`, `cleanUp`, `clearPlants`, `climbLadder`, `closeCurtains`, `closeDoors`, `closeWindows`, `deposit`, `digFurrows`, `emptyFluid`, `exercise`, `fertilizePlants`, `fillTroughs`, `fillWater`, `harvestCrops`, `lightsOff`, `lightsOn`, `lootArea`, `moveCorpses`, `openCurtains`, `openDoors`, `openWindows`, `petAnimals`, `pryDoor`, `read`, `roam`, `shower`, `sowSeeds`, `tendAnimals`, `tendCrops`, `washSink`, `waterPlants`. Most of them work best from the in-game menus, which pick targets for you. `job` is mainly for testing.

### Home, places, relationship

| Command | What it does |
|---|---|
| `home` | Home status and options: `status`, `set`, `clear`, `away <hours>` and more. |
| `places` | Places she has noticed and talked about. |
| `rel` / `gift` | Relationship and gifts. Without arguments they show the current state and the options. |

Any command with wrong arguments replies with its usage. Read `result`.

## Single player, multiplayer and test builds

- In multiplayer and in the public Workshop build, only commands from the mod's safe list run. The others reply `not in multiplayer` or `test build only`. Everything listed in this file is on the safe list, except `call` with an argument. Test builds also have `fight`, `stamina`, `cities`, `car`, `drive`, the self-tests and other developer commands.
- In multiplayer the files are on the player's own computer. Each player can connect their own agent to their own companion.

## Example: play together

1. Append `1 diag on`, `2 events on`, `3 quiet on` if you will speak for her yourself.
2. Read `out.txt` until `ack=3` and `tick` grows.
3. Loop:
   - read new lines in `chat.txt` and `events.txt`;
   - read `out.txt`;
   - answer the player with `say` when they talk to her;
   - act on what you see: `heal` when `red_health` drops, `go` when the player leaves, `look` and `take` when they loot.

## Example: reproduce a movement bug

Find the place where she gets stuck. Then append this to `in.txt`, with your own numbers and coordinates:

```
101 verbose on
102 mode wait
103 tp 11141.7 6860.5 0
104 ptp 11140.1 6860.8 0
105 job tendCrops 11131 6852 0
106 trace 600
107 wait 1200
108 assert arrived
109 assert nostuck
110 diag full
111 logdump
```

- Lines 101 to 107 run at once. Then reading stops for 1200 frames while she walks.
- Lines 108 to 111 run together after the pause. `out.txt` keeps only the last reply, so read the `assert` replies in `console.txt`: `verbose on` puts them there.
- Repeat with the next numbers after each change to the mod, until both asserts pass.

`scenario` is handy for the setup part, lines 101 to 106. Do not put `wait` and `assert` in a scenario file: its lines run all at once, so the asserts would check before she has moved.

Then read `movement-trace.txt` and `console.txt`. `tools/movement-analyze.lua` in the source repository turns the log into a readable timeline.
