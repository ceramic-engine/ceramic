package npm;

extern class ToIco {

    inline static function toIco(input:Array<js.node.Buffer>, ?options:{?resize:Bool, ?sizes:Array<Int>}):js.Promise<js.node.Buffer> {
        return options != null
        ? js.Node.require('to-ico')(input, options)
        : js.Node.require('to-ico')(input);
    }

} //ToIco
