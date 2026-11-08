#!/data/data/com.termux/files/usr/bin/bash
# Screen panel on/off buttons - setup for Termux
set -e
echo "== Installing tools =="
yes | pkg update -y
pkg install -y openjdk-21 dx android-tools

echo "== Connecting to this phone's adb on port 5555 =="
adb connect localhost:5555
echo ">> If a 'Allow USB debugging?' popup appears on the phone, tick 'Always allow' and tap Allow."
for i in $(seq 1 30); do
  adb -s localhost:5555 get-state 2>/dev/null | grep -q device && break
  sleep 2
done
adb -s localhost:5555 get-state | grep -q device || { echo "!! Not authorised. Re-run this script after allowing."; exit 1; }

echo "== Building DisplayToggle =="
mkdir -p ~/displaytoggle && cd ~/displaytoggle
cat > DisplayToggle.java <<'JAVA'
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;

/**
 * Powers the physical display panel off/on while Android keeps running
 * (same technique scrcpy uses). Run via: app_process / DisplayToggle <0|2>
 *   0 = panel off, 2 = panel on (normal)
 */
public final class DisplayToggle {

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            System.err.println("usage: DisplayToggle <0=off | 2=on>");
            System.exit(1);
        }
        int mode = Integer.parseInt(args[0]);
        int sdk = Class.forName("android.os.Build$VERSION").getField("SDK_INT").getInt(null);

        Class<?> surfaceControl = Class.forName("android.view.SurfaceControl");
        Class<?> iBinder = Class.forName("android.os.IBinder");
        Method setPowerMode = surfaceControl.getMethod("setDisplayPowerMode", iBinder, int.class);

        int done = 0;
        for (Object token : displayTokens(surfaceControl, sdk)) {
            if (token != null) {
                setPowerMode.invoke(null, token, mode);
                done++;
            }
        }
        System.out.println((mode == 0 ? "Panel OFF" : "Panel ON") + " (" + done + " display(s), SDK " + sdk + ")");
    }

    private static List<Object> displayTokens(Class<?> sc, int sdk) throws Exception {
        List<Object> tokens = new ArrayList<Object>();

        if (sdk >= 34) { // Android 14+: hidden display APIs moved to DisplayControl in services.jar
            Class<?> dc = loadDisplayControl();
            long[] ids = (long[]) dc.getMethod("getPhysicalDisplayIds").invoke(null);
            Method getToken = dc.getMethod("getPhysicalDisplayToken", long.class);
            for (long id : ids) tokens.add(getToken.invoke(null, id));
            return tokens;
        }
        try { // Android 10-11
            tokens.add(sc.getMethod("getInternalDisplayToken").invoke(null));
            return tokens;
        } catch (NoSuchMethodException ignored) { }
        try { // Android 12-13
            long[] ids = (long[]) sc.getMethod("getPhysicalDisplayIds").invoke(null);
            Method getToken = sc.getMethod("getPhysicalDisplayToken", long.class);
            for (long id : ids) tokens.add(getToken.invoke(null, id));
            return tokens;
        } catch (NoSuchMethodException ignored) { }
        tokens.add(sc.getMethod("getBuiltInDisplay", int.class).invoke(null, 0)); // Android 9 and older
        return tokens;
    }

    private static Class<?> loadDisplayControl() throws Exception {
        Class<?> factory = Class.forName("com.android.internal.os.ClassLoaderFactory");
        Method create = factory.getDeclaredMethod("createClassLoader", String.class, String.class, String.class,
                ClassLoader.class, int.class, boolean.class, String.class);
        ClassLoader loader = (ClassLoader) create.invoke(null, "/system/framework/services.jar", null, null,
                ClassLoader.getSystemClassLoader(), 0, true, null);
        Class<?> dc = loader.loadClass("com.android.server.display.DisplayControl");
        Method loadLib = Runtime.class.getDeclaredMethod("loadLibrary0", Class.class, String.class);
        loadLib.setAccessible(true);
        loadLib.invoke(Runtime.getRuntime(), dc, "android_servers");
        return dc;
    }
}
JAVA
javac --release 8 -Xlint:-options DisplayToggle.java
dx --dex --output=DisplayToggle.dex DisplayToggle.class
adb -s localhost:5555 push DisplayToggle.dex /data/local/tmp/DisplayToggle.dex

echo "== Creating widget buttons =="
mkdir -p ~/.shortcuts
for pair in "Screen-Off:0" "Screen-On:2"; do
  name=${pair%%:*}; mode=${pair##*:}
  cat > ~/.shortcuts/$name <<SH
#!/data/data/com.termux/files/usr/bin/bash
adb connect localhost:5555 >/dev/null
adb -s localhost:5555 shell CLASSPATH=/data/local/tmp/DisplayToggle.dex app_process / DisplayToggle $mode
SH
  chmod +x ~/.shortcuts/$name
done

echo
echo "DONE. Test now:  ~/.shortcuts/Screen-Off   then   ~/.shortcuts/Screen-On"
echo "Then add the Termux:Widget widget to your home screen."
