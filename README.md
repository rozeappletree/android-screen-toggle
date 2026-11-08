# Turning off the Galaxy S24 screen panel with one tap (touch and fingerprint keep working)

This setup cuts power to the phone's display panel with no wire. The phone keeps running. It uses the same method as `scrcpy --turn-screen-off`.

- The panel gets **no power**. This is not a black overlay.
- The touchscreen, the ultrasonic fingerprint sensor, apps, audio and calls all keep working.
- Two home-screen buttons: **Screen-Off** and **Screen-On**.

---

## 1. What you need

| Item | Where to get it |
|---|---|
| Windows PC with Android Studio, or just the Android SDK Platform-Tools | Already installed. adb is in `%LOCALAPPDATA%\Android\Sdk\platform-tools` |
| scrcpy (lets you see and control the phone from the PC) | `winget install Genymobile.scrcpy` |
| Termux | **F-Droid**, not the Play Store |
| Termux:Widget | **F-Droid** |
| `screen-toggle-setup.sh` | The setup script provided |
| USB cable | Needed only for setup, and once after each reboot |

---

## 2. One-time setup

### 2.1 Turn on USB debugging (phone)
1. Go to **Settings → About phone → Software information** and tap **Build number** 7 times.
2. Go to **Settings → Developer options** and turn on **USB debugging**.
3. Connect the USB cable and accept the **"Allow USB debugging?"** prompt.

### 2.2 Open PowerShell in the adb folder (PC)
```powershell
cd "$env:LOCALAPPDATA\Android\Sdk\platform-tools"
.\adb devices
```
The phone should be listed as `device`.

> In PowerShell, commands run from this folder need `.\` in front: `.\adb`, not `adb`.

### 2.3 Mirror the phone with scrcpy (PC)
```powershell
$env:ADB = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
scrcpy --turn-screen-off --stay-awake
```
The `$env:ADB` line makes scrcpy use the same adb as Android Studio, so they don't keep disconnecting each other.

### 2.4 Install the Termux apps (phone)
1. Install **Termux** and **Termux:Widget** from F-Droid.
2. Open Termux and run the line below. Tap **Allow** when it asks for storage access.
   ```bash
   termux-setup-storage
   ```

### 2.5 Copy the script and open port 5555 (PC)
Save `screen-toggle-setup.sh` to Downloads, then:
```powershell
.\adb push "$env:USERPROFILE\Downloads\screen-toggle-setup.sh" /sdcard/Download/
.\adb tcpip 5555
```
`tcpip 5555` lets the phone connect to its own adb without a wire. It resets the USB link, so scrcpy closes. Start scrcpy again.

### 2.6 Run the setup script (phone, in Termux)
```bash
bash /sdcard/Download/screen-toggle-setup.sh
```
- It installs Java, the dex compiler and adb, which takes a few minutes.
- When **"Allow USB debugging?"** appears, tick **Always allow** and tap **Allow**.
- It builds `DisplayToggle.dex`, copies it to `/data/local/tmp/`, and creates the two buttons.

### 2.7 Test (phone, in Termux)
```bash
~/.shortcuts/Screen-Off
~/.shortcuts/Screen-On
```

### 2.8 Add the widget (phone)
Long-press the home screen → **Widgets** → **Termux:Widget** → place it. It lists **Screen-Off** and **Screen-On**.

---

## 3. Daily use

| Action | How |
|---|---|
| Panel off | Tap **Screen-Off** on the widget |
| Panel on | Tap **Screen-On**, or press the power button twice (off, then on) |
| After the phone sleeps and wakes | The panel comes back on. Tap **Screen-Off** again |

---

## 4. After every reboot

The port 5555 connection is lost on reboot. Connect the USB cable once and run:
```powershell
cd "$env:LOCALAPPDATA\Android\Sdk\platform-tools"
.\adb tcpip 5555
```
Unplug. The buttons work again.

**Without a PC:** turn on **Developer options → Wireless debugging**, then in Termux:
```bash
adb pair localhost:<PAIR_PORT> <PAIR_CODE>   # from "Pair device with pairing code"
adb connect localhost:<PORT>                 # port on the main Wireless debugging screen
adb tcpip 5555
```

---

## 5. Commands reference

**From the PC (wired or Wi-Fi):**
```powershell
# Panel off / on (requires the dex already on the phone)
.\adb shell CLASSPATH=/data/local/tmp/DisplayToggle.dex app_process / DisplayToggle 0
.\adb shell CLASSPATH=/data/local/tmp/DisplayToggle.dex app_process / DisplayToggle 2

# scrcpy alternative
scrcpy --turn-screen-off --stay-awake      # Ctrl+O = off, Ctrl+Shift+O = on
```

**From Termux on the phone:**
```bash
~/.shortcuts/Screen-Off
~/.shortcuts/Screen-On
```

> Avoid `adb shell cmd display power-off 0`. It makes Android think the screen is off, so touch and mirroring input are ignored. If you used it, undo it with `adb shell cmd display power-reset 0`.

---

## 6. Troubleshooting

| Problem | Fix |
|---|---|
| `'adb' is not recognized` | `cd` into the platform-tools folder and use `.\adb`, or add the folder to PATH: `[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$env:LOCALAPPDATA\Android\Sdk\platform-tools", "User")`, then reopen PowerShell |
| `cannot stat 'file'` | The file isn't in the current folder. Use its full path |
| Button does nothing | Port 5555 was lost (reboot). See section 4 |
| `unauthorized` / `failed to authenticate` | Look for the "Allow USB debugging?" popup and allow it. Run `adb kill-server` in Termux and try again |
| Phone can't be controlled after the panel turns off | You used `cmd display power-off`. Run `power-reset`, then use the buttons instead |
| scrcpy and Android Studio keep disconnecting | Set `$env:ADB` as in 2.3 so both use the same adb |

---

## 7. How it works

- `DisplayToggle` is a small Java program run with `app_process` under the adb **shell** user, which has permission to control the display.
- It calls Android's hidden `SurfaceControl.setDisplayPowerMode(token, mode)`:
  - `0` = **OFF**: the panel and its driver get no power
  - `2` = **NORMAL**: the panel is on
- On Android 14+ the display tokens come from `com.android.server.display.DisplayControl`, which is loaded from `services.jar`.
- Android's power manager still believes the screen is on. That's why touch, the fingerprint sensor and input keep working, unlike `cmd display power-off`.
- The Termux buttons connect to the phone's own adb at `localhost:5555` and run the command.

---

## 8. Removing it

```bash
# in Termux
rm -rf ~/.shortcuts/Screen-Off ~/.shortcuts/Screen-On ~/displaytoggle
adb -s localhost:5555 shell rm /data/local/tmp/DisplayToggle.dex
adb -s localhost:5555 usb        # closes port 5555
```
Then turn off **USB debugging** and **Wireless debugging** if you no longer need them, and uninstall Termux / Termux:Widget.

---

## 9. Security note

While port 5555 is open (until reboot), adb listens on your Wi-Fi network. New computers still need your on-screen approval, but use it only on networks you trust.

---

## Appendix: DisplayToggle.java

The setup script builds this file automatically. It's included here in case you ever need to rebuild by hand:
```bash
javac --release 8 -Xlint:-options DisplayToggle.java
dx --dex --output=DisplayToggle.dex DisplayToggle.class
adb -s localhost:5555 push DisplayToggle.dex /data/local/tmp/
```

```java
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
```
