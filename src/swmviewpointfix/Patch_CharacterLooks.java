package swmviewpointfix;

import me.zed_0xff.zombie_buddy.Patch;
import zombie.characters.IsoGameCharacter;
import zombie.core.skinnedmodel.model.ModelInstance;

@Patch(className = "viewpoint.models.CharacterLooks", methodName = "ready", isAdvice = false)
public final class Patch_CharacterLooks {
    public static final String PREFIX = "[SWM Viewpoint Fix] ";
    public static volatile boolean bound;

    private Patch_CharacterLooks() {
    }

    @Patch.RuntimeType
    public static boolean ready(
            @Patch.Argument(0) IsoGameCharacter c,
            @Patch.Argument(1) ModelInstance m,
            @Patch.Argument(2) float d,
            @Patch.SuperMethod java.lang.reflect.Method original) throws Throwable {
        if (!bound) {
            bound = true;
            System.out.println(PREFIX + "patch active on viewpoint.models.CharacterLooks.ready");
        }
        if (original == null) {
            return true;
        }
        original.setAccessible(true);
        if (SwmCompanion.isDisabled() || c == null || !SwmCompanion.isCompanion(c)) {
            return (Boolean) original.invoke(null, c, m, d);
        }
        if (SwmCompanion.due(c)) {
            c.checkUpdateModelTextures();
        }
        return true;
    }
}
