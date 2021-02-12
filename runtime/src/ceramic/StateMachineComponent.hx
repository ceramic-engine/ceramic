package ceramic;

#if (completion || display)

// We avoid relying on generic build stuff when simply doing code completion
// because haxe compiler doesn't seem to like it

class StateMachineComponent<T,E:ceramic.Entity> extends StateMachineImpl<T> {

    public var entity(default, null):E;

}

#else

#if !macro
@:genericBuild(ceramic.macros.StateMachineMacro.buildGeneric())
#end
class StateMachineComponent<T,E> {

    // Implementation is in StateMachineImpl (bound by genericBuild macro)

}

#end
