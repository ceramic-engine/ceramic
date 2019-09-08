package ceramic;

using ceramic.Extensions;

@editable
#if (!macro && !display && !completion)
@:autoBuild(ceramic.macros.EntityMacro.build())
#end
@:rtti
class Entity implements Events implements Lazy {

/// Properties

    public var data(get,null):Dynamic = null;
    function get_data():Dynamic {
        if (data == null) data = {};
        return data;
    }

    public var id:String = null;

    /** Internal flag to keep track of current entity state:
     - 0: Entity is not destroyed, can be used normally
     - -1: Entity is marked destroyed still allowing calls to super.destroy()
     - -2: Entity is marked destroyed and additional calls to destroy() are ignored
     - -3: Entity root is destroyed (Entity.destroy() was called). Additional calls to destroy() are ignored
     */
    var _lifecycleState:Int = 0;

    public var destroyed(get,never):Bool;
    inline function get_destroyed():Bool {
        return _lifecycleState < 0;
    }

/// Events

    @event function destroy();

/// Lifecycle

    /** Create a new entity */
    public function new() {

        // Default implementation

    } //new

    /** Destroy this entity. This method is automatically protected from duplicate calls. That means
        calling multiple times an entity's `destroy()` method will run the destroy code only one time.
        As soon as `destroy()` is called, the entity is marked `destroyed=true`, even when calling `destroy()`
        method on a subclass (a macro is inserting a code to marke the object
        as destroyed at the beginning of every `destroy()` override function. */
    public function destroy():Void {

        if (_lifecycleState <= -2) return;
        _lifecycleState = -3; // `Entity.destroy() called` = true

        emitDestroy();

        clearComponents();

    } //destroy

/// Autorun

    /** Creates a new `Autorun` instance with the given callback associated with the current entity.
        @param run The run callback
        @return The autorun instance */
    public function autorun(run:Void->Void #if ceramic_debug_autorun , ?pos:haxe.PosInfos #end):Autorun {

        if (destroyed) return null;

#if ceramic_debug_autorun
        if (pos != null) {
            var _run = run;
            run = function() {
                haxe.Log.trace('autorun', pos);
                _run();
            };
        }
#end

        var _autorun = new Autorun(run);

        var _selfDestroy = function() {
            _autorun.destroy();
        };
        onceDestroy(this, _selfDestroy);
        _autorun.onceDestroy(this, function() {
            offDestroy(_selfDestroy);
        });

        return _autorun;

    } //autorun

/// Tween

    public function tween(?id:Int, ?easing:TweenEasing, duration:Float, fromValue:Float, toValue:Float, update:Float->Float->Void):Tween {

        return Tween.start(this, id, easing, duration, fromValue, toValue, update);

    } //tween

/// Print

    public function className():String {

        var className = Type.getClassName(Type.getClass(this));
        var dotIndex = className.lastIndexOf('.');
        if (dotIndex != -1) className = className.substr(dotIndex + 1);
        return className;

    } //className

    function toString():String {

        var className = className();

        if (id != null) {
            return '$className($id)';
        } else {
            return '$className';
        }

    } //toString

/// Components

    inline public function clearComponents() {

        // Destroy each linked component
        if (components != null) {
            var toRemove:Array<String> = null;
            for (name in components.keys()) {
                if (toRemove == null) toRemove = [name];
                else toRemove.push(name);
            }
            if (toRemove != null) {
                for (name in toRemove) {
                    removeComponent(name);
                }
            }
        }

    } //clearComponents

    /** Public components mapping. Contain components
        created separately with `component()` or macro-based components as well. */
    @editable
    public var components(get,set):ImmutableMap<String,Component>;
    inline function get_components():ImmutableMap<String,Component> {
        return _components;
    }
    function set_components(components:ImmutableMap<String,Component>):ImmutableMap<String,Component> {
        if (_components == components) return components;

        // Remove older components
        if (_components != null) {
            for (name in _components.keys()) {
                if (components == null || !components.exists(name)) {
                    removeComponent(name);
                }
            }
        }

        // Add new components
        if (components != null) {
            for (name in components.keys()) {
                var newComponent = components.get(name);
                if (_components != null) {
                    var existing = _components.get(name);
                    if (existing != null) {
                        if (existing != newComponent) {
                            removeComponent(name);
                            component(name, newComponent);
                        }
                    } else {
                        component(name, newComponent);
                    }
                } else {
                    component(name, newComponent);
                }
            }
        }

        // Update mapping
        _components = components;

        return components;
    }

    /** Internal components representation. */
    var _components:Map<String,Component> = null;

    public function component(name:String, ?component:Component):Component {

        if (component != null) {
            if (_components == null) {
                _components = new Map();
            }
            else {
                var existing = _components.get(name);
                if (existing != null) {
                    var existingAsEntity:Entity = cast existing;
                    existingAsEntity.destroy();
                }
            }
            _components.set(name, component);
            component.setProperty('entity', this);
            var componentAsEntity:Entity = cast component;
            componentAsEntity.onceDestroy(this, function() {
                // Remove entity reference from component
                if (component.getProperty('entity') == this) {
                    component.setProperty('entity', null);
                }
                // Remove component reference from entity
                if (!destroyed) {
                    var existing = _components.get(name);
                    if (existing == component) {
                        _components.remove(name);
                    }
                }
            });
            @:privateAccess component.bindAsComponent();
            return component;

        } else {
            if (_components == null) return null;
            return _components.get(name);
        }

    } //component

    public function hasComponent(name:String):Bool {

        return component(name) != null;

    } //hasComponent

    public function removeComponent(name:String):Void {

        var existing = _components.get(name);
        if (existing != null) {
            _components.remove(name);
            var existingAsEntity:Entity = cast existing;
            existingAsEntity.destroy();
        }

    } //removeComponent

#if editor

    /** If set to true, that means this entity is managed by editor. */
    public var edited:Bool = false;

#end

} //Entity
