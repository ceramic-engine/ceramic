// New code for the Haxe port of GPUI (no GPUI origin): replaces the `TypeId`
// of events used by `EventEmitter<E>` in gpui-pre 0.3.10. See NOTICE.md.
package gpui;

/**
 * The type of the events a subscriber listens to, given explicitly since Haxe
 * cannot dispatch on a type parameter: `cx.subscribe(emitter, MyEvent, ...)`.
 *
 * Accepts a class (matched with `Std.isOfType`, so subclasses match too) or an
 * enum (matched with `Type.getEnum`). An entity can emit several event types.
 */
abstract EventType<E>(EventTypeData) {

    inline function new(data:EventTypeData) {
        this = data;
    }

    @:from static inline function fromClass<E>(cls:Class<E>):EventType<E> {
        return new EventType(new EventTypeData(cls, null));
    }

    @:from static inline function fromEnum<E>(enm:Enum<E>):EventType<E> {
        return new EventType(new EventTypeData(null, enm));
    }

    /**
     * `true` if the given event is of this type.
     */
    public inline function matches(event:Dynamic):Bool {
        return this.matches(event);
    }

    public inline function toString():String {
        return this.toString();
    }

}

@:allow(gpui.EventType)
private class EventTypeData {

    final cls:Null<Class<Dynamic>>;

    final enm:Null<Enum<Dynamic>>;

    function new(cls:Null<Class<Dynamic>>, enm:Null<Enum<Dynamic>>) {
        this.cls = cls;
        this.enm = enm;
    }

    function matches(event:Dynamic):Bool {
        if (event == null)
            return false;
        if (cls != null)
            return Std.isOfType(event, cls);
        return Reflect.isEnumValue(event) && Type.getEnum(event) == enm;
    }

    function toString():String {
        return cls != null ? Type.getClassName(cls) : Type.getEnumName(enm);
    }

}
