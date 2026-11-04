package backend;

#if !no_backend_docs
/**
 * The key repeat delay and interval of the system, for the key repeat that
 * the Unity backend synthesizes (Unity's Input System gives no repeated key
 * down events, and Unity does not expose these settings).
 *
 * - macOS: `NSEvent.keyRepeatDelay` and `NSEvent.keyRepeatInterval`
 *   (the keyboard settings of the user), read through the Objective-C runtime.
 * - Windows: `SystemParametersInfo` with `SPI_GETKEYBOARDDELAY` (0 to 3,
 *   250 ms steps from 250 ms) and `SPI_GETKEYBOARDSPEED` (0 to 31, about
 *   2.5 to 30 repeats per second).
 * - Elsewhere, or when the system cannot be read: 500 ms then 33 ms (the
 *   defaults of Windows).
 */
#end
@:classCode('
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
    [System.Runtime.InteropServices.DllImport("/usr/lib/libobjc.A.dylib")]
    static extern System.IntPtr objc_getClass(string name);

    [System.Runtime.InteropServices.DllImport("/usr/lib/libobjc.A.dylib")]
    static extern System.IntPtr sel_registerName(string name);

    // On arm64 and x86_64, a double is returned by objc_msgSend itself
    [System.Runtime.InteropServices.DllImport("/usr/lib/libobjc.A.dylib", EntryPoint = "objc_msgSend")]
    static extern double objc_msgSend_double(System.IntPtr receiver, System.IntPtr selector);
#endif

#if UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    static extern bool SystemParametersInfo(uint action, uint param, ref uint value, uint winIni);
#endif

    // 0: delay, 1: interval, in seconds; -1 when unknown
    public static double systemKeyRepeatValue(int which) {
        try {
#if UNITY_EDITOR_OSX || UNITY_STANDALONE_OSX
            System.IntPtr cls = objc_getClass("NSEvent");
            if (cls == System.IntPtr.Zero) return -1;
            return objc_msgSend_double(cls, sel_registerName(which == 0 ? "keyRepeatDelay" : "keyRepeatInterval"));
#elif UNITY_EDITOR_WIN || UNITY_STANDALONE_WIN
            uint v = 0;
            if (which == 0) {
                if (!SystemParametersInfo(0x0016, 0, ref v, 0)) return -1;
                return 0.25 * (v + 1);
            }
            if (!SystemParametersInfo(0x000A, 0, ref v, 0)) return -1;
            return 1.0 / (2.5 + v * (27.5 / 31.0));
#else
            return -1;
#endif
        }
        catch (System.Exception) {
            return -1;
        }
    }
')
class KeyRepeatSettings {

    /** Delay before the first repeat when the system cannot be read. */
    public static final DEFAULT_DELAY:Float = 0.5;

    /** Interval between repeats when the system cannot be read. */
    public static final DEFAULT_INTERVAL:Float = 0.033;

    /** The delay before the first repeat, in seconds. */
    public static function delay():Float {

        final value:Float = untyped __cs__('global::backend.KeyRepeatSettings.systemKeyRepeatValue(0)');
        return (value >= 0.05 && value <= 5.0) ? value : DEFAULT_DELAY;

    }

    /** The interval between two repeats, in seconds. */
    public static function interval():Float {

        final value:Float = untyped __cs__('global::backend.KeyRepeatSettings.systemKeyRepeatValue(1)');
        return (value >= 0.005 && value <= 2.0) ? value : DEFAULT_INTERVAL;

    }

}
