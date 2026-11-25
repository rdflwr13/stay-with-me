package swmviewpointfix;

import me.zed_0xff.zombie_buddy.Patch;
import zombie.characters.IsoGameCharacter;

@Patch(className = "zombiechunking.ChunkFrame", methodName = "captured", isAdvice = true)
public final class Patch_VisceralCapture {
    public static volatile boolean bound;

    private Patch_VisceralCapture() {
    }

    @Patch.OnEnter(skipOn = true)
    public static boolean enter(@Patch.Argument(1) IsoGameCharacter c) {
        if (!bound) {
            bound = true;
            System.out.println("[SWM Viewpoint Fix] Visceral capture patch active");
        }
        return SwmCompanion.isCompanion(c);
    }
}
