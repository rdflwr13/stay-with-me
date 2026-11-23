package swmviewpointfix;

import me.zed_0xff.zombie_buddy.Patch;

@Patch(className = "viewpoint.models.CharacterLooks", methodName = "begin", isAdvice = true, strictMatch = true)
public final class Patch_CharacterLooksBegin {
    private Patch_CharacterLooksBegin() {
    }

    @Patch.OnEnter
    public static void enter() {
        SwmCompanion.beginCapture();
    }
}
