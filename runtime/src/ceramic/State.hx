package ceramic;

@:allow(ceramic.StateMachineImpl)
class State extends Entity {

    public var machine(default,null):StateMachine<Dynamic> = null;

    public function new() {

        super();

    } //new

    public function enter():Void {

        //

    } //enter

    public function update(delta:Float):Void {

        //

    } //update

    public function exit():Void {

        //

    } //exit

} //State
