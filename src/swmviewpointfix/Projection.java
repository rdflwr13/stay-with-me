package swmviewpointfix;

import java.lang.reflect.Field;
import java.lang.reflect.Method;

import me.zed_0xff.zombie_buddy.Exposer;
import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.iso.IsoCamera;

/**
 * World-to-screen projection for Stay With Me's world-anchored overlays while
 * Viewpoint is in first person.
 *
 * Reuses Viewpoint's own projection path (the one {@code viewpoint.game.WorldText}
 * uses): {@code WorldText.screen.set(frame, place, w, h)} then
 * {@code WorldToScreen.pixel(x, y, z, lift, out)}.
 *
 * Contract used by StayWithMeOverlay.lua:
 *   project(x, y, z, lift) -> boolean visible; stores the last screen point
 *   projectX() -> last screen x
 *   projectY() -> last screen y
 */
@Exposer.LuaClass(name = "Projection")
public final class Projection {
    private static final String PREFIX = "[SWM Viewpoint Fix] ";

    private static volatile boolean disabled;
    private static volatile boolean ready;
    private static volatile float lastX;
    private static volatile float lastY;

    private static volatile Method frameMethod;
    private static volatile Field screenField;
    private static volatile Method setMethod;
    private static volatile Method pixelMethod;
    private static volatile Field freeCamActiveField;
    private static volatile Field freeCamPlaceField;
    private static volatile Field headTextHeightField;

    private Projection() {
    }

    @LuaMethod
    public static boolean project(double x, double y, double z, double lift) {
        if (disabled) {
            return false;
        }
        try {
            if (!bind()) {
                return false;
            }
            Object frame = frameMethod.invoke(null, 0);
            if (frame == null) {
                return false;
            }
            Object screen = screenField.get(null);
            if (screen == null) {
                return false;
            }
            Object place = freeCamActiveField.getBoolean(null) ? freeCamPlaceField.get(null) : null;
            float w = IsoCamera.getScreenWidth(0);
            float h = IsoCamera.getScreenHeight(0);
            Object setOk = setMethod.invoke(screen, frame, place, w, h);
            if (!(setOk instanceof Boolean) || !((Boolean) setOk)) {
                return false;
            }
            // lift arrives in game units (same value the iso path adds to z).
            // WorldToScreen.pixel adds it after scaling z by the isometric
            // factor, so convert game units to that scaled space.
            float height = (float) lift * 2.4494896f;
            if (height <= 0f) {
                height = headTextHeightField.getFloat(null);
            }
            float[] out = new float[2];
            Object visible = pixelMethod.invoke(screen, (float) x, (float) y, (float) z, height, out);
            if (!(visible instanceof Boolean) || !((Boolean) visible)) {
                return false;
            }
            lastX = out[0];
            lastY = out[1];
            return true;
        } catch (Throwable t) {
            disable(t);
            return false;
        }
    }

    @LuaMethod
    public static double projectX() {
        return lastX;
    }

    @LuaMethod
    public static double projectY() {
        return lastY;
    }

    private static boolean bind() throws Exception {
        if (ready) {
            return true;
        }
        ClassLoader cl = Projection.class.getClassLoader();

        Class<?> fp = Class.forName("viewpoint.FP", false, cl);
        frameMethod = fp.getDeclaredMethod("frame", int.class);
        frameMethod.setAccessible(true);

        Class<?> worldText = Class.forName("viewpoint.game.WorldText", false, cl);
        screenField = worldText.getDeclaredField("screen");
        screenField.setAccessible(true);

        Class<?> frameClass = Class.forName("viewpoint.core.Frame", false, cl);
        Class<?> placeClass = Class.forName("viewpoint.input.FreeCam$Place", false, cl);
        Class<?> worldToScreen = Class.forName("viewpoint.game.WorldToScreen", false, cl);
        setMethod = worldToScreen.getDeclaredMethod("set", frameClass, placeClass, float.class, float.class);
        setMethod.setAccessible(true);
        pixelMethod = worldToScreen.getDeclaredMethod("pixel", float.class, float.class, float.class, float.class, float[].class);
        pixelMethod.setAccessible(true);

        Class<?> freeCam = Class.forName("viewpoint.input.FreeCam", false, cl);
        freeCamActiveField = freeCam.getDeclaredField("active");
        freeCamActiveField.setAccessible(true);
        freeCamPlaceField = freeCam.getDeclaredField("place");
        freeCamPlaceField.setAccessible(true);

        Class<?> tuning = Class.forName("viewpoint.platform.Tuning", false, cl);
        headTextHeightField = tuning.getDeclaredField("headTextHeight");
        headTextHeightField.setAccessible(true);

        ready = true;
        return true;
    }

    private static void disable(Throwable t) {
        if (disabled) {
            return;
        }
        disabled = true;
        System.out.println(PREFIX + "projection disabled: " + t);
    }
}
