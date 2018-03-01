package ceramic;

using ceramic.Extensions;

@editable
#if !macro
@:autoBuild(ceramic.macros.EntityMacro.build())
#end
@:rtti
class Entity implements Events implements Lazy {

/// Properties

    @lazy public var data:Dynamic<Dynamic> = {};

    public var id:String = null;

    public var destroyed:Bool = false;

/// Events

    @event function destroy();

/// Lifecycle

    public function destroy():Void {

        if (destroyed) return;
        destroyed = true;

        emitDestroy();

        // Destroy each linked component
        if (components != null) {
            for (name in components.keys()) {
                removeComponent(name);
            }
        }

    } //destroy

/// Autorun

    /** Creates a new `Autorun` instance with the given callback associated with the current entity.
        @param run The run callback
        @return The autorun instance */
    public function autorun(run:Void->Void):Autorun {

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

    /** Public components mapping. Does not contain components
        created separatelywith `component()` or macro-based components. */
    @editable
    public var components(default,set):ImmutableMap<String,Component> = null;
    function set_components(components:ImmutableMap<String,Component>):ImmutableMap<String,Component> {
        if (this.components == components) return components;

        // Remove older components
        if (this.components != null) {
            for (name in this.components.keys()) {
                if (components == null || !components.exists(name)) {
                    removeComponent(name);
                }
            }
        }

        // Add new components
        if (components != null) {
            for (name in components.keys()) {
                var newComponent = components.get(name);
                if (this.components != null) {
                    var existing = this.components.get(name);
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
        this.components = components;

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
                    existing.destroy();
                }
            }
            _components.set(name, component);
            component.setProperty('entity', this);
            component.onceDestroy(this, function() {
                if (component.getProperty('entity') == this) {
                    component.setProperty('entity', null);
                }
            });
            @:privateAccess component.init();
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
            existing.destroy();
        }

    } //removeComponent

#if editor

    /** If set to true, that means this entity is managed by editor. */
    public var edited:Bool = false;

#end

} //Entity
