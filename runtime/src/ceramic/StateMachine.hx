package ceramic;

@:genericBuild(ceramic.macros.StateMachineMacro.buildGeneric())
class StateMachine<T> extends Entity {

    // Implementation is in StateMachineImpl (bound by genericBuild macro)

}
