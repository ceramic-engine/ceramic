package ceramic;

#if (completion || display)

// We avoid relying on generic build stuff when simply doing code completion
// because haxe compiler doesn't seem to like it

class StateMachine<T> extends StateMachineImpl<T> {

}

#else

#if !macro
@:genericBuild(ceramic.macros.StateMachineMacro.buildGeneric())
#end
class StateMachine<T> {

    // Implementation is in StateMachineImpl (bound by genericBuild macro)

}

#end
