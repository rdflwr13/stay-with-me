package swmviewpointfix;

import java.lang.reflect.Method;

import me.zed_0xff.zombie_buddy.Patch;
import zombie.characters.IsoPlayer;
import zombie.characters.IsoZombie;
import zombie.iso.IsoGridSquare;

@Patch(className = "viewpoint.interact.LootTargets", methodName = "people", isAdvice = true, strictMatch = true)
public final class Patch_ViewpointTargets {
    public static final String PREFIX = "[SWM Viewpoint Fix] ";
    public static final int PERSON = 6;

    public static volatile boolean bound;
    public static volatile boolean disabled;
    public static volatile Method addMethod;
    public static volatile Method growMethod;

    private Patch_ViewpointTargets() {
    }

    @Patch.OnExit
    public static void exit(@Patch.Argument(0) IsoPlayer player, @Patch.Argument(1) IsoGridSquare sq) {
        if (disabled || player == null || sq == null) {
            return;
        }
        Object body = SwmCompanion.resolveBody();
        if (!(body instanceof IsoZombie)) {
            return;
        }
        IsoZombie z = (IsoZombie) body;
        if (z == (Object) player || z.isDead()) {
            return;
        }
        if (Math.abs(z.getZ() - sq.getZ()) > 0.5f) {
            return;
        }
        float dx = z.getX() - sq.getX();
        float dy = z.getY() - sq.getY();
        if (Math.abs(dx) > 2.0f || Math.abs(dy) > 2.0f) {
            return;
        }
        if (!player.CanSee(z)) {
            return;
        }
        try {
            Method add = addMethod();
            Method grow = growMethod();
            if (add == null || grow == null) {
                disable("missing LootTargets.add or LootBoxes.grow");
                return;
            }
            Object id = add.invoke(null, PERSON, null, z);
            if (!(id instanceof Integer)) {
                return;
            }
            float x = z.getX(), y = z.getY(), zz = z.getZ();
            grow.invoke(null, id, x - 0.3f, y - 0.3f, zz, x + 0.3f, y + 0.3f, zz + 1.6f);
            if (!bound) {
                bound = true;
                System.out.println(PREFIX + "patch active on viewpoint.interact.LootTargets.people");
            }
        } catch (Throwable t) {
            disable(t.toString());
        }
    }

    public static Method addMethod() {
        Method m = addMethod;
        if (m != null) {
            return m;
        }
        try {
            Class<?> cls = Class.forName("viewpoint.interact.LootTargets", false,
                    Patch_ViewpointTargets.class.getClassLoader());
            for (Method candidate : cls.getDeclaredMethods()) {
                if (candidate.getName().equals("add") && candidate.getParameterCount() == 3) {
                    candidate.setAccessible(true);
                    addMethod = candidate;
                    return candidate;
                }
            }
        } catch (Throwable t) {
            disable(t.toString());
        }
        return null;
    }

    public static Method growMethod() {
        Method m = growMethod;
        if (m != null) {
            return m;
        }
        try {
            Class<?> cls = Class.forName("viewpoint.interact.LootBoxes", false,
                    Patch_ViewpointTargets.class.getClassLoader());
            for (Method candidate : cls.getDeclaredMethods()) {
                if (candidate.getName().equals("grow") && candidate.getParameterCount() == 7) {
                    candidate.setAccessible(true);
                    growMethod = candidate;
                    return candidate;
                }
            }
        } catch (Throwable t) {
            disable(t.toString());
        }
        return null;
    }

    public static void disable(String why) {
        if (disabled) {
            return;
        }
        disabled = true;
        System.out.println(PREFIX + "target patch disabled: " + why);
    }
}
