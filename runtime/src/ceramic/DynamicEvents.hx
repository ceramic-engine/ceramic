package ceramic;

/** Fire and listen to dynamic events. Works similarly to static events, but dynamic.
    If you can know the event names at compile time, using static events (`@event function myEvent();`) is preferred. */
class DynamicEvents<T> extends Entity {

    var dispatcher:EventDispatcher;

    var mapping:Map<String,Int>;

    var nextIndex:Int = 0;

    public function new() {

        super();

        dispatcher = new EventDispatcher();
        mapping = new Map();

    } //new

    function eventToString(event:T):String {

        var name:Dynamic = event;
        return name.toString();

    } //keyToString

    function indexForEvent(event:T):Int {

        var name = eventToString(event);
        if (mapping.exists(name)) {
            return mapping.get(name);
        }
        else {
            var index = nextIndex++;
            mapping.set(name, index);
            return index;
        }

    } //indexForEvent

    /// Publi API

    public function emit(event:T, ?args:Array<Dynamic>):Void {

        var index = indexForEvent(event);
        var numArgs = args != null ? args.length : 0;
        if (numArgs == 0) {
            dispatcher.emit(index, 0);
        }
        else if (numArgs == 1) {
            dispatcher.emit(index, 1, args[0]);
        }
        else if (numArgs == 2) {
            dispatcher.emit(index, 2, args[0], args[1]);
        }
        else if (numArgs == 3) {
            dispatcher.emit(index, 3, args[0], args[1], args[2]);
        }
        else {
            dispatcher.emit(index, -1, args);
        }

    } //emit

    public function on(event:T, #if ceramic_optional_owner ?owner:Entity #else owner:Entity #end, cb:Dynamic):Void {

        var index = indexForEvent(event);
        dispatcher.on(index, owner, cb);

    } //on

    public function once(event:T, #if ceramic_optional_owner ?owner:Entity #else owner:Entity #end, cb:Dynamic):Void {

        var index = indexForEvent(event);
        dispatcher.once(index, owner, cb);

    } //once

    public function off(event:T, ?cb:Dynamic):Void {

        var index = indexForEvent(event);
        dispatcher.off(index, cb);

    } //off

    public function listens(event:T):Bool {

        var index = indexForEvent(event);
        return dispatcher.listens(index);

    } //listens

} //DynamicEvents
