package ceramic;

#if !macro
@:autoBuild(ceramic.macros.SerializableMacro.build())
#end
interface Serializable {

    @:noCompletion
    var _serializeId:String;

} //Serializable
