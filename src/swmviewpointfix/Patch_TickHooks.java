package swmviewpointfix;

import me.zed_0xff.zombie_buddy.Patch;

@Patch(className = "viewpoint.TickHooks", methodName = "updated", isAdvice = true)
public final class Patch_TickHooks {
    private Patch_TickHooks() {
    }

    @Patch.OnEnter
    public static void enter() {
        SwmCompanion.updateFromGame();
    }
}
