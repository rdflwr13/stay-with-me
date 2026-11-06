# Changelog

## 0.6.2.1

Safeguard pregame appearance drafts and move the draft to bridge

Changelog:
- Pregame appearance drafts are now applied to `Bridge.store` before the first `dress` and kept on disk after the apply. The draft is removed only on the next session, after `store.pregameState == "applied"` has been loaded from ModData.
- `BridgePregame.consumeInto` is now a state machine returning `applied`, `retry`, `wait`, `none`, `legacy`, `invalid`, or `mp`.
- The first spawn is deferred for up to 10 seconds while the import is pending. Reads are throttled to one per second, permanent draft errors stop for the session while keeping the file, and the session gives up after the window and spawns normally.
- Draft binding now compares `WORLD` only. `MAP` and `MODE` differences are logged once and no longer reject or delete the draft.
- A late apply calls `BridgeInventory.skin` and resets the model next frame.
- The draft file moved from `Zomboid/Lua/stay_with_me_pregame.txt` to `Zomboid/Lua/bridge/stay_with_me_pregame.txt`. `readDraft`, `writeDraft`, and `removeDraftFile` use the new path.
- Legacy saves without `pregameState` and with a spawned companion keep the existing reject-and-remove behavior.
- Added transition-only logs for pending world, world mismatch, map or mode differences, permanent draft errors, the 10-second give-up, applied state, and next-session removal. No per-tick logs were added.
- `BridgeData.neverSpawned`, the draft file format, and `VERSION` are unchanged. Multiplayer still returns `mp` with no import and no deletion.

Tested:
- LuaJIT: `BridgePregame.lua` and `BridgeMain.lua` parse successfully.
- Local state-machine harness: draft read reasons, fresh apply, draft retention, next-session removal, world mismatch retry and 10-second give-up, map and mode tolerance, legacy reject-remove, multiplayer, missing data, read throttling, forced bypass, and pending-without-draft no-wait. 31 checks, 0 failures.

To test:
- New save with a distinctive pregame appearance: the import applies before `spawned zombie`, the companion matches, and the draft still exists after apply.
- Save and reload: `draft removed after applied save` appears and the appearance persists.
- Force quit before saving after the first spawn: relaunch keeps the draft and reapplies the appearance.
- Edit the draft `MAP` to `DEFAULT`: the import still applies and the map difference is logged once.
- Change the draft `WORLD`: no apply, the draft is kept, and the companion spawns after the wait window with fallback gender and defaults.
- Existing save with a spawned companion and a stale draft: the draft is removed with no appearance override.
- Manual `pregameState = "pending"`: the retry applies on reload.
- Multiplayer: no import and no draft deletion.
- Confirm there are no repeated per-tick draft log lines.
