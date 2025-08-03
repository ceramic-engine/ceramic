package backend;

#if android
/**
 * Android-specific native build configuration for the Clay backend.
 *
 * This class configures the Android NDK build to include CPU feature
 * detection capabilities. The cpu-features library allows runtime
 * detection of CPU capabilities like:
 * - NEON SIMD instructions
 * - ARM architecture version
 * - CPU core count
 * - Cache sizes
 *
 * This information is used by SDL when building for Android.
 *
 * The @:buildXml metadata injects the necessary compiler flags and
 * source files into the native build process.
 */
@:buildXml("
<files id='haxe'>
    <compilerflag value='-I${ANDROID_NDK_ROOT}/sources/android/cpufeatures/' />
    <file name='${ANDROID_NDK_ROOT}/sources/android/cpufeatures/cpu-features.c' />
</files>
")
@:keep
class NativeAndroid {

    /**
     * Initialization placeholder to ensure the class is included in builds.
     * The actual initialization happens through the build configuration.
     */
    @:keep public static function init():Void {}

}
#end
