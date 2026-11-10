// New code for the Haxe port of GPUI (no GPUI origin): the runtime side of
// `Component` (see Component.hx and ComponentMacro.hx). See NOTICE.md.
package glaze;

import tracker.Autorun;

/**
 * Turns the placeholder returned by `X.component()` into an element or a
 * root view, in both modes of `Component`.
 */
class ComponentBuilder {

    /**
     * The element drawing `proto` (the value returned by `X.component()`).
     * Stateless: a `ViewElement` rendering it like a `RenderOnce`, under the
     * element id of its class (or its `.at(key)`). Persistent: a
     * `ComponentElement`, which finds or creates the instance when laid out.
     */
    public static function intoAnyElement(proto:Component):AnyElement {
        if (proto.__persistent()) {
            return new ComponentElement(proto).intoAnyElement();
        }
        return ViewElement.forGlazeComponent(proto).intoAnyElement();
    }

    /**
     * A root view showing `proto` (`new Glaze(AppView.component())`, or
     * `(window, cx) -> AppView.component()`). The component lives as long
     * as the host entity, which is destroyed with the window; a persistent
     * component is created right away and initialized with the window
     * (`Window.open`), or at its first render. The host is an entity of
     * `cx` when given (the app of the window being built), else of the app
     * that first reaches it (`Glaze.app` by default).
     */
    public static function rootView(proto:Component, ?cx:App):AnyView {
        final live = proto.__create();
        if (live != proto) {
            proto.__apply(live);
        }
        final host = new ComponentHost(live);
        if (cx != null) {
            cx.attachEntity(host);
        }
        return host;
    }

}

/**
 * The entity drawing a `Component` as a view: the component's `render` runs
 * in the host's tracker capture, so the observables it reads render it
 * again. Destroying the host disposes the component (`destroy()`), then
 * runs the destroy handlers of the component: the host carries the
 * lifecycle of the component as a `tracker.Owner`.
 */
class ComponentHost extends Model implements Render {

    /**
     * The live component.
     */
    public final instance:Component;

    var initialized:Bool = false;

    public function new(instance:Component) {
        super();
        this.instance = instance;
        instance.__attachHost(this);
        instance.__start();
    }

    /**
     * Calls the component's `init()` once, outside of any tracker capture.
     */
    @:allow(glaze)
    function ensureInit(window:Window, cx:App):Void {
        if (initialized)
            return;
        initialized = true;
        Autorun.unobserve();
        try {
            instance.init(window, cx);
        }
        catch (e:haxe.Exception) {
            Autorun.reobserve();
            throw glaze.util.Exceptions.rethrow(e);
        }
        Autorun.reobserve();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        ensureInit(window, cx.app);
        final instance = this.instance;
        instance.__window = window;
        instance.__viewId = entityId;
        return instance.render(window, cx.app);
    }

    override function destroy() {
        instance.__dispose();
        instance.__emitDestroy();
        super.destroy();
    }

}

/**
 * The element placed by `X.component()` for a persistent component: when
 * laid out, it finds the instance by its identity in the element states of
 * the window (or creates it), assigns the props of the placeholder, and
 * draws the instance as a view.
 */
class ComponentElement extends Element {

    final proto:Component;

    var rendered:Null<AnyElement> = null;

    public function new(proto:Component) {
        this.proto = proto;
    }

    public function requestLayout(id:Null<GlobalElementId>, window:Window, cx:App):LayoutId {
        final host = window.useComponent(proto, cx);
        final rendered = ViewElement.forView(host).intoAnyElement();
        this.rendered = rendered;
        return rendered.requestLayout(window, cx);
    }

    public function prepaint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        rendered.prepaint(window, cx);
    }

    public function paint(id:Null<GlobalElementId>, bounds:Bounds, window:Window, cx:App):Void {
        rendered.paint(window, cx);
    }

}
