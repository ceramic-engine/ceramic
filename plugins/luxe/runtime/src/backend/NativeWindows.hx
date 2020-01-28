package backend;

@:keep
@:include('linc_NativeWindows.h')
#if !display
@:build(bind.Linc.touch())
@:build(bind.Linc.xml('NativeWindows', './'))
#end
extern class NativeWindows {

    @:native('backend::NativeWindows_init')
    static function init():Void;

}
