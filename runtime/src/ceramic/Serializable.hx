package ceramic;

#if !macro
@:autoBuild(ceramic.macros.SerializableMacro.build())
#end
@:keep
@:keepSub
interface Serializable {

    @:noCompletion
    var _serializeId:String;

    private function willSerialize():Void;

    private function didDeserialize():Void;

}
