package ceramic;

#if !macro
@:genericBuild(ceramic.macros.StateMachineMacro.buildGeneric())
#end
class StateMachine<T> extends Entity {

    // Implementation is in StateMachineImpl (bound by genericBuild macro)

}
