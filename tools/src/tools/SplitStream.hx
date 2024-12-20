package tools;

class SplitStream {

    public var separator:Int;

    public var handler:(section:String)->Void;

    var buffer:StringBuf;

    public function new(separator:Int, handler:(section:String)->Void) {
        this.separator = separator;
        this.handler = handler;
        this.buffer = new StringBuf();
    }

    public function add(str:String):Void {
        for (i in 0...str.length) {
            final code = str.charCodeAt(i);
            inline addChar(code);
        }
    }

    public function addChar(code:Int):Void {
        if (code == separator) {
            handler(buffer.toString());
            buffer = new StringBuf();
        }
        else {
            buffer.addChar(code);
        }
    }

    public function flush():Void {
        if (buffer != null && buffer.length > 0) {
            handler(buffer.toString());
            buffer = null;
        }
    }

}
