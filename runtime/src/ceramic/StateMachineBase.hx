package ceramic;

import tracker.Observable;

class StateMachineBase extends Entity implements Observable implements Component {

    /**
     * A way to assign null state to generic classes and let final target do what is best as a cast
     */
    static final NO_STATE:Dynamic = null;

    @:noCompletion @entity var rawEntity:ceramic.Entity;

    @:allow(ceramic.StateMachineSystem)
    function _updateState(delta:Float):Void {

        // Override in subclasses

    }

    function bindAsComponent():Void {

        // Nothing to do

    }

}
