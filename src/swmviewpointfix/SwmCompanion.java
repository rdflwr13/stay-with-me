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
    private static volatile Object raised;
    private static volatile Object raisedPuppet;
    private static volatile boolean announced;
    private static volatile boolean announcedPuppet;
    private static volatile boolean disabled;
    private static volatile Field dueField;
    private static volatile Map<?, ?> layeredMap;

    private SwmCompanion() {
    }

    public static boolean isDisabled() {
        return disabled;
    }

    public static boolean isCompanion(Object c) {
        return c != null && (c == companion || c == puppet || c == requested || c == requestedPuppet);
    }

    public static void updateFromGame() {
        if (disabled) {
            return;
        }
        try {
            requested = resolveBody();
            requestedPuppet = resolvePuppet();
            if (requested != companion && requested != raised) {
                raised = requested;
                if (requested instanceof IsoGameCharacter) {
                    raise((IsoGameCharacter) requested);
                }
            }
            if (requestedPuppet != puppet && requestedPuppet != raisedPuppet) {
                raisedPuppet = requestedPuppet;
                if (requestedPuppet instanceof IsoGameCharacter) {
                    raise((IsoGameCharacter) requestedPuppet);
                }
            }
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
                    restore(companion);
                } else if (current != null && current != raised) {
                    restore(current);
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
                    restore(puppet);
                } else if (currentPuppet != null && currentPuppet != raisedPuppet) {
                    restore(currentPuppet);
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

    public static void raise(IsoGameCharacter c) {
        if (disabled || c == null) {
            return;
        }
        try {
            Field f = field();
            if (f != null) {
                f.setBoolean(c, true);
                c.checkUpdateModelTextures();
            }
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

    private static void restore(Object o) {
        try {
            Map<?, ?> map = layeredMap();
            if (map != null) {
                map.remove(o);
            }
            if (o instanceof IsoGameCharacter) {
                Field f = field();
                if (f != null) {
                    f.setBoolean(o, true);
                    ((IsoGameCharacter) o).checkUpdateModelTextures();
                }
            }
        } catch (Throwable t) {
            disable(t);
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
        raised = null;
        raisedPuppet = null;
        System.out.println(PREFIX + "disabled: " + t);
    }
}
