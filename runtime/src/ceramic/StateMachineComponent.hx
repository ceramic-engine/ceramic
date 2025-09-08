package ceramic;

/**
 * A state machine that can be attached to entities as a component.
 *
 * StateMachineComponent extends StateMachine with the ability to be attached
 * to entities as a component. It provides direct access to the parent entity
 * and automatically manages its lifecycle as part of the entity.
 *
 * This is useful when you want to add state machine behavior to existing
 * entities without subclassing them.
 *
 * Example usage:
 * ```haxe
 * // Define states for a player entity
 * enum PlayerState {
 *     IDLE;
 *     RUNNING;
 *     JUMPING;
 * }
 *
 * // Create a state machine component for the player
 * var playerStateMachine = new StateMachineComponent<PlayerState, Player>();
 * playerStateMachine.set(IDLE, new IdleState());
 * playerStateMachine.set(RUNNING, new RunningState());
 * playerStateMachine.set(JUMPING, new JumpingState());
 *
 * // Attach to player entity
 * player.component(playerStateMachine);
 *
 * // Alternatively, on entity fields marked as component, you can just write `StateMachine`
 * // as it will be automatically replaced by `StateMachineComponent` at compile time
 * @component public var machine:StateMachine<PlayerState, Player>;
 *
 * // States can access the entity
 * class IdleState extends State {
 *     override function update(delta:Float) {
 *         var player = cast(machine, StateMachineComponent<PlayerState, Player>).entity;
 *         if (player.velocity.x != 0) {
 *             machine.state = RUNNING;
 *         }
 *     }
 * }
 * ```
 *
 * @see StateMachine
 * @see Component
 * @see Entity
 */
#if (completion || display || documentation)

// We avoid relying on generic build stuff when simply doing code completion
// because haxe compiler doesn't seem to like it

class StateMachineComponent<T,E:ceramic.Entity> extends StateMachineImpl<T> {

    /**
     * The entity this state machine is attached to.
     * Set automatically when added as a component.
     */
    public var entity(default, null):E;

}

#else

/**
 * State machine component that can be attached to entities.
 * 
 * StateMachineComponent extends the base StateMachine functionality to work
 * as a component that can be attached to any Entity. The generic type parameters
 * are T for state type and E for the entity type.
 * 
 * @param T The type representing states (typically an enum)
 * @param E The entity type this component will be attached to
 * @see StateMachine
 * @see Component
 */
#if !macro
@:genericBuild(ceramic.macros.StateMachineMacro.buildGeneric())
#end
class StateMachineComponent<T,E> {

    // Implementation is in StateMachineImpl (bound by genericBuild macro)

}

#end
