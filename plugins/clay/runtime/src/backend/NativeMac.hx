package backend;

@:keep
@:include('linc_NativeMac.h')
#if !display
@:build(bindhx.Linc.touch())
@:build(bindhx.Linc.xml('NativeMac', './'))
#end
extern class NativeMac {

    @:native('backend::NativeMac_setAppleMomentumScrollSupported')
    static function setAppleMomentumScrollSupported(value:Bool):Void;

}
