package ceramic;

class Json {

    inline static public function stringify(value:Dynamic, ?replacer:(key:Dynamic, value:Dynamic) -> Dynamic, ?space:String):String {

        return haxe.Json.stringify(value, replacer, space);

    }

    inline static public function parse(text:String):Dynamic {

        return haxe.Json.parse(text);

    }

}