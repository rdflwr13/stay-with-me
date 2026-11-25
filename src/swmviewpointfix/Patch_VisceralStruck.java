package swmviewpointfix;

import me.zed_0xff.zombie_buddy.Patch;
import zombie.characters.IsoZombie;

@Patch(className = "zombiechunking.ShotWounds", methodName = "struckBy", isAdvice = true)
public final class Patch_VisceralStruck {
    public static volatile boolean bound;

    private Patch_VisceralStruck() {
    }

    @Patch.OnEnter(skipOn = true)
    public static boolean enter(@Patch.Argument(0) IsoZombie z) {
        if (!bound) {
            bound = true;
            System.out.println("[SWM Viewpoint Fix] Visceral wound patch active");
        }
        return SwmCompanion.isCompanion(z);
    }
}
