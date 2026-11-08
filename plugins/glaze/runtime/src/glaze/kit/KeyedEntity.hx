// New code for the Haxe port of gpui-kit (no gpui-kit origin): the state of
// a kit control created by `X.component()` without a state. See NOTICE.md.
package glaze.kit;

import glaze.App;
import glaze.Droppable;
import glaze.Entity;
import glaze.EventType;
import glaze.Model;
import glaze.Subscription;

/**
 * The state entity that `Input.component()`, `Select.component()` and
 * `Slider.component()` create when no state is given: kept in the window's
 * element state (`Window.useKeyedState`) under the identity of the call
 * (its position in the code, or `.at(key)`), so it lives as long as the
 * component is rendered and is destroyed when it leaves the tree.
 *
 * It also keeps the latest change handler (`.onChange(f)`), replaced on
 * each render of the parent without invalidating anything, and the single
 * event subscription that calls it, plus a memo slot for what the
 * component applied to the state last (its options, for instance).
 */
class KeyedEntity<T:Model, H> implements Droppable {

    /** The state. */
    public final entity:Entity<T>;

    /** The latest handler given by `.onChange(f)`, `null` when none. */
    public var handler:Null<H> = null;

    /** What the component applied to the state last, for its own use. */
    public var memo:Null<Dynamic> = null;

    var subscription:Null<Subscription> = null;

    public function new(entity:Entity<T>) {
        this.entity = entity;
    }

    /**
     * Subscribes once to the events of the state. The listener reads
     * `handler` when an event arrives, so the handler of the latest render
     * is the one called.
     */
    public function subscribe<E>(cx:App, eventType:EventType<E>, onEvent:(Entity<T>, E, App) -> Void):Void {
        if (subscription != null) return;
        subscription = cx.subscribe(entity, eventType, onEvent);
    }

    /** The component left the tree: its state goes with it. */
    public function drop():Void {
        if (subscription != null) {
            subscription.dispose();
            subscription = null;
        }
        handler = null;
        memo = null;
        entity.intoAny().destroy();
    }

}
