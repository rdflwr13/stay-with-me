# Stay With Me

A companion mod for Project Zomboid (Build 42). She walks with you, fights beside you, treats your wounds and waits for you at home. Singleplayer works, multiplayer is playable.

- Steam Workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=3800989007
- Mod ID: `Bridge`

## Layout

`Contents/mods/Bridge` is the mod exactly as it ships on the Workshop. Lua lives in `common/media/lua` (`client`, `server`, `shared`).

The blank lines in the Lua files are intentional: comments are stripped at build time and replaced with empty lines, so line numbers match error logs and the development source.

## AI agents

The mod can be driven by an AI agent through a few text files in `Zomboid/Lua/bridge/`. How it works and every command are in [`Contents/mods/Bridge/AI_AGENTS.md`](Contents/mods/Bridge/AI_AGENTS.md).

## Bugs and fixes

Bug reports are welcome in Issues. Pull requests are welcome too. Every change is tested in game before it is merged, so a merge can take time.

By submitting a pull request you agree that your contribution becomes part of this mod under the terms in `LICENSE.txt`.

## License

All rights reserved, see `LICENSE.txt`. You may read the code, change it for your own use and make other mods compatible with it. Do not reupload the mod or its parts without permission.
