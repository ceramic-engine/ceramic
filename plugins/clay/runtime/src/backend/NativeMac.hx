package backend;

/**
 * Native macOS-specific functionality for the Clay backend.
 *
 * This extern class provides bindings to native macOS APIs through
 * C++ code (linc_NativeMac.h).
 *
 * The class is marked with @:keep to ensure it's not removed by DCE
 * (Dead Code Elimination) since it's referenced from native code.
 */
@:keep
@:include('linc_NativeMac.h')
#if !display
@:build(bindhx.Linc.touch())
@:build(bindhx.Linc.xml('NativeMac', './'))
#end
extern class NativeMac {

    /**
     * Enables or disables Apple's momentum scrolling behavior.
     *
     * Momentum scrolling provides the characteristic "bounce" effect
     * when scrolling past content boundaries on macOS. This can be
     * disabled for applications that want more direct scroll control.
     *
     * @param value true to enable momentum scrolling, false to disable
     */
    @:native('backend::NativeMac_setAppleMomentumScrollSupported')
    static function setAppleMomentumScrollSupported(value:Bool):Void;

}
