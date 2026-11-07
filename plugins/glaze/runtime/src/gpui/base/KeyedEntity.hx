// New code for the Haxe port of gpui-kit (no Rust origin). See NOTICE.md.
package gpui.base;

import gpui.App;
import gpui.Context;
import gpui.ElementIdArg;
import gpui.Entity;
import gpui.Model;
import gpui.Window;

/**
 * Rust's `window.use_keyed_state(key, cx, |window, cx| State::new(..))`
 * returns an `Entity<State>` that lives as long as the element is rendered in
 * consecutive frames. The port's `Window.useKeyedState` wraps any value in a
 * `StateModel`: this keeps an entity in it, destroyed with the keyed state
 * (Rust drops it with the element state).
 */
class KeyedEntity {

    public static function use<T:Model>(window:Window, key:ElementIdArg, cx:App, build:(Window, Context<T>) -> T):Entity<T> {
        final holder = window.useKeyedState(key, cx, window -> {
            final entity:Entity<T> = cx.newEntity((entityCx:Context<T>) -> build(window, entityCx));
            entity;
        });
        final state = holder.read(cx);
        final entity = state.value;
        if (!state.destroyed && !(entity : T).destroyed && !bound.exists(state)) {
            bound.set(state, true);
            state.onDestroy(entity, _ -> {
                bound.remove(state);
                if (!(entity : T).destroyed) (entity : T).destroy();
            });
        }
        return entity;
    }

    /**
     * Like GPUI's `use_keyed_state`: the entity is kept in the element state
     * of `key` under its own class (Rust keys element states by type, so two
     * states of different types can share a key), and the view rendering it
     * is notified when the entity is notified. For states that call
     * `cx.notify()` instead of using observable fields. The entity is
     * destroyed with the element state.
     */
    public static function useObserved<T:Model>(window:Window, key:ElementIdArg, type:Class<T>, cx:App, build:(Window, Context<T>) -> T):Entity<T> {
        final currentView = window.currentView();
        return window.withGlobalId(key, (globalId, window) -> {
            return window.withElementState(globalId, type, (box, window) -> {
                if (box.value != null) {
                    return (box.value : Entity<T>);
                }
                final entity:Entity<T> = cx.newEntity((entityCx:Context<T>) -> build(window, entityCx));
                cx.observe(entity, (_, cx) -> cx.notify(currentView));
                box.value = (entity : T);
                return entity;
            });
        });
    }

    static final bound:haxe.ds.ObjectMap<Model, Bool> = new haxe.ds.ObjectMap();

}
