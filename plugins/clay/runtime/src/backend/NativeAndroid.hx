package backend;

#if android
@:buildXml("
<files id='haxe'>
    <compilerflag value='-I${ANDROID_NDK_ROOT}/sources/android/cpufeatures/' />
    <file name='${ANDROID_NDK_ROOT}/sources/android/cpufeatures/cpu-features.c' />
</files>
")
@:keep
class NativeAndroid {

    @:keep public static function init():Void {}

}
#end
