package ceramic;

// Current implementation is functionnaly correct,
// but it will be better to use genericBuild to avoid using
// too much dynamic access and make it efficient.
// (just like what we did for StateMachine)

//#if (completion || display || documentation)

// We avoid relying on generic build stuff when simply doing code completion
// because haxe compiler doesn't seem to like it

class InputMap<T> extends InputMapImpl<T> {

}

/*
#else

#if !macro
@:genericBuild(ceramic.macros.InputMapMacro.buildGeneric())
#end
class InputMap<T> {

    // Implementation is in InputMapImpl (bound by genericBuild macro)

}

#end
*/
