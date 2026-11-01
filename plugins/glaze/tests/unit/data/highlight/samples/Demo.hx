package demo;

import haxe.ds.Map;

/** Doc comment. */
@:keep
class Demo<T> extends Base implements IDemo {
    static inline final MAX:Int = 0xFF;
    public var items(default, null):Array<T> = [];

    public function new() {
        super();
        final re = ~/^[a-z]+$/i;
        trace('items: ${items.length} ' + re.match("abc") + null);
    }

    override function toString():String return 'Demo';
}
