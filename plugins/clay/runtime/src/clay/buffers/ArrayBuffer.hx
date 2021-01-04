package clay.buffers;

// Code imported from snowkit/snow (https://github.com/snowkit/snow/tree/fe93eb1ecfc82131a6143be1b3e3e0a274f4cf65)
// Credits go to its original author (@ruby0x1 on Github)

#if js

    typedef ArrayBuffer = js.lib.ArrayBuffer;

#else

    import haxe.io.BytesData;

    @:forward
    abstract ArrayBuffer(BytesData) from BytesData to BytesData {

        public var byteLength (get, never) : Int;

        public inline function new( byteLength:Int ) {
            this = new BytesData();
            if(byteLength>0) this[byteLength-1] = untyped 0;
        }

        inline function get_byteLength() {
            return this.length;
        }
    }

#end //!js
