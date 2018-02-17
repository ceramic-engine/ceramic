package backend;

@:keep
@:include('linc_NativeMac.h')
#if !display
@:build(bind.Linc.touch())
@:build(bind.Linc.xml('NativeMac', './'))
#end
extern class NativeMac {

    @:native('backend::NativeMac_setAppleMomentumScrollSupported')
    static function setAppleMomentumScrollSupported(value:Bool):Void;

} //NativeMac
