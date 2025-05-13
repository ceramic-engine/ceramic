package backend;

@:keep
@:include('linc_NativeWindows.h')
#if !display
@:build(bindhx.Linc.touch())
@:build(bindhx.Linc.xml('NativeWindows', './'))
#end
extern class NativeWindows {

    @:native('backend::NativeWindows_init')
    static function init():Void;

}
