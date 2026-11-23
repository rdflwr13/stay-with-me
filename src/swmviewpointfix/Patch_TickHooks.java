package swmviewpointfix;

import me.zed_0xff.zombie_buddy.Patch;

@Patch(className = "viewpoint.TickHooks", methodName = "updated", isAdvice = true)
public final class Patch_TickHooks {
    public static volatile boolean bound;

    private Patch_TickHooks() {
    }

    @Patch.OnEnter
    public static void enter() {
        if (!bound) {
            bound = true;
            System.out.println("[SWM Viewpoint Fix] tick hook active");
        }
        SwmCompanion.updateFromGame();
    }
}
