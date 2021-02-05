package ceramic;

#if !macro
@:genericBuild(ceramic.macros.StateMachineMacro.buildGeneric())
#end
class StateMachineComponent<T,E> {

    // Implementation is in StateMachineImpl (bound by genericBuild macro)

}
