package ceramic;

@:allow(ceramic.StateMachineImpl)
class State extends Entity {

    public var machine(default,null):StateMachine<Dynamic> = null;

    public function new() {

        super();

    }

    public function enter():Void {

        //

    }

    public function update(delta:Float):Void {

        //

    }

    public function exit():Void {

        //

    }

}
