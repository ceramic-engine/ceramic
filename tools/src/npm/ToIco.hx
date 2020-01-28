package npm;

#if (haxe_ver < 4)
import js.Promise;
#else
import js.lib.Promise;
#end

extern class ToIco {

    inline static function toIco(input:Array<js.node.Buffer>, ?options:{?resize:Bool, ?sizes:Array<Int>}):Promise<js.node.Buffer> {
        return options != null
        ? js.Node.require('to-ico')(input, options)
        : js.Node.require('to-ico')(input);
    }

}
