// New code for the Haxe port of GPUI (no GPUI origin): components in the
// spirit of Wisdom, built on `RenderOnce`, views and element states. See NOTICE.md.
package glaze;

/**
 * A piece of interface written as a class: it reads the models of the app,
 * receives props from its parent, and may hold its own observable state.
 *
 * ```haxe
 * class Switch extends Component {
 *     @prop var value:Bool = false;
 *     @prop var onChange:(value:Bool) -> Void = null;
 *
 *     function render(window:Window, cx:App):IntoElement {
 *         return div().id('switch').onClick(() -> if (onChange != null) onChange(!value))
 *             .child(div().left(px(value ? 22 : 2)));
 *     }
 * }
 *
 * // In a parent's render
 * Switch.component().value(prefs.wordWrap).onChange(on -> prefs.wordWrap = on)
 * ```
 *
 * Every `@prop` field gets a chained setter of the same name (unless the
 * class defines that method itself), and the class gets a static
 * `component(...)` with the parameters of its constructor, `.at(key)`,
 * `.child(...)` and `.children(...)`. Inside the class the prop is read by
 * its own name (`value`); the field itself is stored as `valueProp`.
 *
 * **Stateless component**: a class with only `@prop` fields and methods. It
 * is built and rendered at each render of its parent, like a `RenderOnce`:
 * the instance returned by `component()` is the one rendered, and its props
 * are plain fields.
 *
 * **Persistent component**: a class with `@observe`, `@compute` or
 * `@autorun` fields, an `init()` or `destroy()` override, or the class
 * metadata `@persist`. `component()` returns a light placeholder (no
 * constructor runs) carrying the props; when the parent's element tree is
 * laid out, the instance is found by its identity (the position of the
 * `component()` call in the code and its class, or the key given to
 * `.at(key)`, needed when the same call runs in a loop), or
 * created the first time (constructor, props, autoruns, then `init()`).
 * Its props are assigned (an equal value changes nothing), and it is drawn
 * as a view: it renders again only when a data prop changed, when it was
 * given children, or when an observable it read changed. When its parent
 * stops rendering it, it is destroyed: `destroy()` runs. Data props are
 * observable (tracker `@observe`); function typed props and
 * `@prop(unobserved)` props are plain fields, so a new closure at each
 * parent render does not render the component again. Props the parent did
 * not set in a render keep their current value.
 *
 * Not an entity: a stateless instance costs what a `RenderOnce` builder
 * costs. A persistent instance is drawn through a small carrier entity
 * (`ComponentBuilder.ComponentHost`).
 *
 * **Owner**: a persistent component is a `tracker.Owner`, its lifecycle
 * being the one of its host. `this` is a valid owner for tracker events
 * (`model.onChange(this, ...)`), `Timer.interval(this, ...)`, tweens and
 * immediates: what it owns ends when it leaves the tree. A stateless
 * component is rebuilt at every render and owns nothing: passing `this` as
 * an owner there is refused at compile time (the members of `tracker.Owner`
 * below throw if reached anyway).
 */
@:autoBuild(glaze.ComponentMacro.build())
abstract class Component implements tracker.Owner {

    /**
     * The children given by the parent with `.child(...)` / `.children(...)`,
     * `null` when it gave none. Read as `children` in the class (the macro
     * renames it, as it does for the props: the chained method `children()`
     * has the same name), placed with `div().children(children)`.
     */
    @:noCompletion public var childrenProp:Null<Array<IntoElement>> = null;

    /**
     * The identity of this component in its parent (`.at(key)`, or the
     * position of the `component()` call for a persistent component). For
     * a stateless component, the element id isolating its element states.
     */
    @:noCompletion public var __key:Null<ElementId> = null;

    public function new() {}

    /**
     * Render this component into an element tree.
     */
    public abstract function render(window:Window, cx:App):IntoElement;

    /**
     * Called once, when a persistent component is created, before its first
     * render (with the props of that first render assigned).
     */
    public function init(window:Window, cx:App):Void {}

    /**
     * Called when a persistent component leaves the element tree (its parent
     * stopped rendering it) or when its window is destroyed.
     */
    public function destroy():Void {}

    /**
     * `true` for a persistent component class (generated).
     */
    @:noCompletion public function __persistent():Bool {
        return false;
    }

    /**
     * The element id naming this component class (generated).
     */
    @:noCompletion public abstract function __elementId():ElementId;

    /**
     * Creates the instance of a persistent component from the placeholder
     * returned by `component()` (generated: runs the constructor with the
     * arguments given to `component()`).
     */
    @:noCompletion public function __create():Component {
        return this;
    }

    /**
     * Assigns the props and children set on this placeholder to `target`,
     * the live instance (generated for the props). Returns `true` when the
     * target must render again regardless of its observable props (its
     * children changed).
     */
    @:noCompletion public function __apply(target:Component):Bool {
        final children = this.childrenProp;
        if (children != null || target.childrenProp != null) {
            target.childrenProp = children;
            return true;
        }
        return false;
    }

    /**
     * Starts the `@autorun` methods (generated).
     */
    @:noCompletion public function __start():Void {}

    /**
     * Stops the autoruns and calls `destroy()`.
     */
    @:noCompletion public function __dispose():Void {
        destroy();
    }

    /**
     * The element drawing this component (stateless: rendered now like a
     * `RenderOnce`; persistent: found or created by identity when laid out).
     */
    @:noCompletion public function __intoAnyElement():AnyElement {
        return ComponentBuilder.intoAnyElement(this);
    }

/// Owner (generated in persistent components)

    /**
     * Whether this component left the tree (persistent component: its host
     * was destroyed). A stateless component is not an owner.
     */
    public var destroyed(get, never):Bool;
    function get_destroyed():Bool {
        throw notAnOwner();
    }

    /**
     * Calls `handler` once, when this persistent component leaves the tree
     * (after its `destroy()`), with the component.
     */
    public function onceDestroy(#if tracker_optional_owner ?owner:tracker.Owner #else owner:Null<tracker.Owner> #end, handler:(tracker.Owner) -> Void #if tracker_debug_events , ?pos:haxe.PosInfos #end):Void {
        throw notAnOwner();
    }

    /**
     * Removes a handler bound with `onceDestroy()` (all of them without
     * argument).
     */
    public function offDestroy(?handler:(tracker.Owner) -> Void):Void {
        throw notAnOwner();
    }

    /**
     * Gives the persistent instance its host, whose lifecycle it carries
     * (generated).
     */
    @:noCompletion public function __attachHost(host:ComponentBuilder.ComponentHost):Void {}

    /**
     * Runs the destroy handlers, once the host is destroyed (generated).
     */
    @:noCompletion public function __emitDestroy():Void {}

    function notAnOwner():haxe.Exception {
        return new haxe.Exception('${Type.getClassName(Type.getClass(this))} is a stateless component: it is rebuilt at every render and cannot own handlers (make it persistent with @persist)');
    }

}
