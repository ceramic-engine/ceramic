// Ported from gpui-pre 0.3.10: src/inspector.rs (`Inspector`, `InspectorElementRegistry`)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

#if glaze_inspector

import glaze.util.Ref;

/**
 * Function set on `App` to render the inspector UI.
 */
typedef InspectorRenderer = (Inspector, Window, Context<Inspector>) -> AnyElement;

/**
 * Renders the inspector state of one type for the active element.
 */
typedef InspectorElementRenderer = (InspectorElementId, Dynamic, Window, App) -> AnyElement;

private class InspectedElement {

    public final id:InspectorElementId;

    /** States by type (Rust `TypeIdHashMap<Box<dyn Any>>`), keyed by class name */
    public final states:Map<String, Dynamic> = new Map();

    /** Keys of `states`, in insertion order */
    public final keys:Array<String> = [];

    public function new(id:InspectorElementId) {
        this.id = id;
    }

    public function remove(key:String):Dynamic {
        final value = states.get(key);
        if (states.remove(key)) {
            keys.remove(key);
        }
        return value;
    }

    public function insert(key:String, value:Dynamic):Void {
        if (!states.exists(key)) {
            keys.push(key);
        }
        states.set(key, value);
    }

}

/**
 * Manages inspector state - which element is currently selected and whether the inspector is
 * in picking mode.
 */
class Inspector extends Model implements Render {

    var activeElement:Null<InspectedElement> = null;

    @:allow(glaze)
    var pickDepth:Null<Float> = 0.0;

    final renderers:Map<String, InspectorElementRenderer> = new Map();

    @:allow(glaze)
    function new() {
        super();
    }

    @:allow(glaze)
    function select(id:InspectorElementId, window:Window):Void {
        setActiveElementId(id, window);
        pickDepth = null;
    }

    @:allow(glaze)
    function hover(id:InspectorElementId, window:Window):Void {
        if (isPicking()) {
            final changed = setActiveElementId(id, window);
            if (changed) {
                pickDepth = 0.0;
            }
        }
    }

    @:allow(glaze)
    function setActiveElementId(id:InspectorElementId, window:Window):Bool {
        final changed = !id.equals(activeElementId());
        if (changed) {
            activeElement = new InspectedElement(id);
            window.refresh();
        }
        return changed;
    }

    /**
     * ID of the currently hovered or selected element.
     */
    public function activeElementId():Null<InspectorElementId> {
        return activeElement != null ? activeElement.id : null;
    }

    /**
     * Runs `f` with the state of type `type` of the active element (the
     * box holds `null` when there is none, or no active element): a state
     * left in the box is stored back.
     */
    @:allow(glaze)
    function withActiveElementState<T, R>(type:Class<T>, window:Window, f:(Ref<Null<T>>, Window) -> R):R {
        final active = activeElement;
        if (active == null) {
            return f(new Ref<Null<T>>(null), window);
        }

        final key = Type.getClassName(type);
        final inspectorState = new Ref<Null<T>>(active.remove(key));

        final result = f(inspectorState, window);

        if (inspectorState.value != null) {
            active.insert(key, inspectorState.value);
        }

        return result;
    }

    /**
     * Starts element picking mode, allowing the user to select elements by clicking.
     */
    public function startPicking():Void {
        pickDepth = 0.0;
    }

    /**
     * Returns whether the inspector is currently in picking mode.
     */
    public function isPicking():Bool {
        return pickDepth != null;
    }

    /**
     * Renders elements for all registered inspector states of the active inspector element.
     */
    public function renderInspectorStates(window:Window, cx:Context<Inspector>):Array<AnyElement> {
        final elements:Array<AnyElement> = [];
        final active = activeElement;
        activeElement = null;
        if (active != null) {
            final app = cx.app;
            for (key in active.keys.copy()) {
                var renderer = renderers.get(key);
                if (renderer == null) {
                    final factory = app.inspectorElementRegistry.factoriesByTypeId.get(key);
                    if (factory == null) {
                        continue;
                    }
                    renderer = factory(window, app);
                    renderers.set(key, renderer);
                }
                elements.push(renderer(active.id, active.states.get(key), window, app));
            }

            activeElement = active;
        }

        return elements;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final app = cx.app;
        final inspectorRenderer = app.inspectorRenderer;
        if (inspectorRenderer != null) {
            app.inspectorRenderer = null;
            final result = inspectorRenderer(this, window, cast cx);
            app.inspectorRenderer = inspectorRenderer;
            return result;
        }
        else {
            return new Empty();
        }
    }

}

/**
 * The renderers registered for inspector states, by state type.
 */
class InspectorElementRegistry {

    @:allow(glaze)
    final factoriesByTypeId:Map<String, (Window, App) -> InspectorElementRenderer> = new Map();

    public function new() {}

    /**
     * Registers a renderer factory for the inspector states of type `type`.
     */
    public function register<T>(type:Class<T>, factory:(Window, App) -> ((InspectorElementId, T, Window, App) -> IntoElement)):Void {
        factoriesByTypeId.set(Type.getClassName(type), (window, cx) -> {
            final renderer = factory(window, cx);
            return (id:InspectorElementId, value:Dynamic, window:Window, cx:App) -> {
                if (!Std.isOfType(value, type)) {
                    throw 'registered inspector state type';
                }
                return (renderer(id, cast value, window, cx) : AnyElement);
            };
        });
    }

}

#end
