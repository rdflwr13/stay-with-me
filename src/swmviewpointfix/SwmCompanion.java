package swmviewpointfix;

import java.lang.reflect.Field;
import java.util.Map;

import se.krka.kahlua.vm.KahluaTable;
import zombie.Lua.LuaManager;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoZombie;

public final class SwmCompanion {
    private static final String PREFIX = "[SWM Viewpoint Fix] ";

    private static volatile Object requested;
    private static volatile Object companion;
    private static volatile Object requestedPuppet;
    private static volatile Object puppet;
    private static volatile Object forced;
    private static volatile boolean announced;
    private static volatile boolean announcedPuppet;
    private static volatile boolean disabled;
    private static volatile Field dueField;
    private static volatile Map<?, ?> layeredMap;
    private static volatile boolean layeredProbeFailed;
    private static volatile int restoreLogs;

    private SwmCompanion() {
    }

    public static boolean isDisabled() {
        return disabled;
    }

    public static Object companion() {
        return companion;
    }

    public static boolean isCompanion(Object c) {
        return c != null && (c == companion || c == puppet);
    }

    public static void updateFromGame() {
        if (disabled) {
            return;
        }
        try {
            requested = resolveBody();
            requestedPuppet = resolvePuppet();
        } catch (Throwable t) {
            disable(t);
        }
    }

    public static void beginCapture() {
        if (disabled) {
            return;
        }
        try {
            Object current = requested;
            if (current != companion) {
                if (companion != null) {
                    logLayered(companion);
                    restore(companion);
                }
                companion = current;
                if (current != null && !announced) {
                    announced = true;
                    System.out.println(PREFIX + "companion registered");
                }
            }
            Object currentPuppet = requestedPuppet;
            if (currentPuppet != puppet) {
                if (puppet != null) {
                    logLayered(puppet);
                    restore(puppet);
                }
                puppet = currentPuppet;
                if (currentPuppet != null && !announcedPuppet) {
                    announcedPuppet = true;
                    System.out.println(PREFIX + "seat puppet registered");
                }
            }
        } catch (Throwable t) {
            disable(t);
        }
    }

    public static void force(IsoGameCharacter c) {
        if (disabled || c == null) {
            return;
        }
        if (c == forced) {
            return;
        }
        try {
            Field f = field();
            if (f == null) {
                return;
            }
            f.setBoolean(c, true);
            forced = c;
        } catch (Throwable t) {
            disable(t);
        }
    }

    public static boolean due(IsoGameCharacter c) {
        if (disabled || c == null) {
            return false;
        }
        try {
            Field f = field();
            return f != null && f.getBoolean(c);
        } catch (Throwable t) {
            disable(t);
            return false;
        }
    }

    private static Object resolveBody() {
        KahluaTable env = LuaManager.env;
        Object bridge = env == null ? null : env.rawget("Bridge");
        Object body = bridge instanceof KahluaTable ? ((KahluaTable) bridge).rawget("body") : null;
        return body instanceof IsoZombie ? body : null;
    }

    private static Object resolvePuppet() {
        KahluaTable env = LuaManager.env;
        Object seat = env == null ? null : env.rawget("BridgeSeatPuppet");
        Object p = seat instanceof KahluaTable ? ((KahluaTable) seat).rawget("p") : null;
        return p instanceof IsoZombie ? p : null;
    }

    public static void restore(Object o) {
        try {
            Map<?, ?> map = layeredMap();
            boolean present = map != null && map.containsKey(o);
            boolean removed = map != null && map.remove(o) != null;
            if (restoreLogs < 10) {
                restoreLogs++;
                System.out.println(PREFIX + "restore present=" + present + " removed=" + removed);
            }
            if (o instanceof IsoGameCharacter) {
                Field f = field();
                if (f != null) {
                    f.setBoolean(o, true);
                }
            }
        } catch (Throwable t) {
            disable(t);
        }
    }

    private static void logLayered(Object o) {
        if (layeredProbeFailed) {
            return;
        }
        try {
            Map<?, ?> map = layeredMap();
            if (map != null) {
                System.out.println(PREFIX + "layered entry present=" + map.containsKey(o));
            }
        } catch (Throwable t) {
            layeredProbeFailed = true;
            System.out.println(PREFIX + "layered probe failed: " + t);
        }
    }

    private static Map<?, ?> layeredMap() throws ReflectiveOperationException {
        Map<?, ?> map = layeredMap;
        if (map != null) {
            return map;
        }
        Class<?> cls = Class.forName("viewpoint.models.CharacterLooks", false, SwmCompanion.class.getClassLoader());
        Field f = cls.getDeclaredField("layered");
        f.setAccessible(true);
        Object value = f.get(null);
        if (!(value instanceof Map)) {
            layeredProbeFailed = true;
            return null;
        }
        map = (Map<?, ?>) value;
        layeredMap = map;
        return map;
    }

    private static Field field() throws NoSuchFieldException {
        Field f = dueField;
        if (f != null) {
            return f;
        }
        f = IsoGameCharacter.class.getDeclaredField("updateModelTextures");
        f.setAccessible(true);
        dueField = f;
        return f;
    }

    private static void disable(Throwable t) {
        if (disabled) {
            return;
        }
        disabled = true;
        companion = null;
        requested = null;
        puppet = null;
        requestedPuppet = null;
        System.out.println(PREFIX + "disabled: " + t);
    }
}
