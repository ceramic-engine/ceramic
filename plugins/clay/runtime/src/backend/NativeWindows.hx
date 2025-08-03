package backend;

/**
 * Native Windows-specific functionality for the Clay backend.
 *
 * This extern class provides bindings to Windows-specific APIs through
 * C++ code (linc_NativeWindows.h). It handles platform-specific
 * initialization required for proper Windows application behavior.
 */
@:keep
@:include('linc_NativeWindows.h')
#if !display
@:build(bindhx.Linc.touch())
@:build(bindhx.Linc.xml('NativeWindows', './'))
#end
extern class NativeWindows {

    /**
     * Performs Windows-specific initialization.
     *
     * This typically includes:
     * - Setting up high DPI awareness for proper scaling
     * - Configuring console output for debug builds
     * - Initializing COM for certain Windows APIs
     * - Setting process-level Windows compatibility flags
     *
     * Should be called early in the application lifecycle.
     */
    @:native('backend::NativeWindows_init')
    static function init():Void;

}
