package swmviewpointfix;

import me.zed_0xff.zombie_buddy.Patch;
import zombie.characters.IsoGameCharacter;

@Patch(className = "viewpoint.models.CharacterLooks", methodName = "ready", isAdvice = true)
public final class Patch_CharacterLooks {
    public static final String PREFIX = "[SWM Viewpoint Fix] ";
    public static volatile boolean bound;
    public static volatile IsoGameCharacter companionCall;

    private Patch_CharacterLooks() {
    }

    @Patch.OnEnter
    public static void enter(@Patch.Argument(0) IsoGameCharacter c) {
        if (!bound) {
            bound = true;
            System.out.println(PREFIX + "patch active on viewpoint.models.CharacterLooks.ready");
        }
        if (SwmCompanion.isDisabled() || c == null || !SwmCompanion.isCompanion(c)) {
            companionCall = null;
            return;
        }
        companionCall = c;
        SwmCompanion.force(c);
    }

    @Patch.OnExit
    public static void exit(@Patch.Argument(0) IsoGameCharacter c, @Patch.Return(readOnly = false) boolean ret) {
        if (c != null && c == companionCall) {
            SwmCompanion.restore(c);
            ret = true;
        }
        companionCall = null;
    }
}
