package ceramic;

import tracker.Autorun;
import tracker.Events;

using ceramic.Extensions;
#if ceramic_entity_dynamic_events
import tracker.DynamicEvents;
#end


#if (!macro && !display && !completion)
@:autoBuild(ceramic.macros.EntityMacro.build())
#end
#if (!macro && (display || completion))
@:autoBuild(ceramic.macros.EntityMacro.buildForCompletion())
#end
#if ceramic_entity_field_info
@autoFieldInfo
#end
class Entity #if ceramic_entity_base extends EntityBase #end implements Events implements Lazy {

/// Statics

    #if (ceramic_entity_field_info && (!macro && !display && !completion))
    /**
     * Field info
     */
    @:noCompletion public static var _fieldInfo(default, null) = {
        components: {
            type: 'ceramic.ReadOnlyMap<String,ceramic.Component>',
            index: 1
        },
        scriptContent: {
            type: 'ceramic.ScriptContent',
            index: 2
        }
    };
    #end

/// Properties

    @:noCompletion var _data:Dynamic = null;

    public var hasData(get,never):Bool;
    inline function get_hasData():Bool {
        return _data != null;
    }

    public var data(get,set):Dynamic;
    function get_data():Dynamic {
        if (_data == null) _data = {};
        return _data;
    }
    function set_data(data:Dynamic):Dynamic {
        return _data = data;
    }

    public var id:String = null;

    /**
     * Internal flag to keep track of current entity state:
     *  - 0: Entity is not destroyed, can be used normally
     *  - -1: Entity is marked destroyed still allowing calls to super.destroy()
     *  - -2: Entity is marked destroyed and additional calls to destroy() are ignored
     *  - -3: Entity root is destroyed (Entity.destroy() was called). Additional calls to destroy() are ignored
     */
    @:noCompletion var _lifecycleState:Int = 0;

#if plugin_script
    public var scriptContent(get,set):ScriptContent;
    function get_scriptContent():ScriptContent {
        var comp = component('script');
        var content:ScriptContent = null;
        if (comp != null && Std.isOfType(comp, Script)) {
            var scriptComp:Script = cast comp;
            content = scriptComp.content;
        }
        return content;
    }
    function set_scriptContent(content:ScriptContent):ScriptContent {
        var prevContent = get_scriptContent();
        if (prevContent != content) {
            if (content == null) {
                removeComponent('script');
            }
            else {
                component('script', new Script(content));
            }
        }
        return content;
    }

    public var script(get,set):Script;
    function get_script():Script {
        var comp = component('script');
        if (comp != null && Std.isOfType(comp, Script)) {
            return cast comp;
        }
        return null;
    }
    function set_script(script:Script):Script {
        if (script == null) {
            removeComponent('script');
        }
        else {
            component('script', script);
        }
        return script;
    }
#end

#if ceramic_entity_dynamic_events
    public var events(get,never):DynamicEvents<String>;
    function get_events():DynamicEvents<String> {
        var eventsComp:DynamicEvents<String> = cast component('events');
        if (eventsComp == null) {
            eventsComp = new DynamicEvents<String>();
            component('events', eventsComp);
        }
        return eventsComp;
    }
#end

    public var destroyed(get,never):Bool;
    #if !haxe_server inline #end function get_destroyed():Bool {
        return _lifecycleState < 0;
    }

    public var disposed(get,never):Bool;
    #if !haxe_server inline #end function get_disposed():Bool {
        return _lifecycleState == 1;
    }

    #if ceramic_debug_entity_allocs
    var posInfos:haxe.PosInfos;
    var reusedPosInfos:haxe.PosInfos;
    var recycledPosInfos:haxe.PosInfos;

    static var debugEntityAllocsInitialized = false;
    static var numEntityAliveInMemoryByClass = new Map<String,Int>();
    #if cpp
    static var numEntityDestroyedButInMemoryByClass = new Map<String,Int>();
    static var destroyedWeakRefs = new Map<String,Array<cpp.vm.WeakRef<Entity>>>();
    #end
    #end

/// Events

    @event function dispose(entity:ceramic.Entity);

    @event function destroy(entity:ceramic.Entity);

/// Lifecycle

    /**
     * Create a new entity
     */
    public function new(#if ceramic_debug_entity_allocs ?pos:haxe.PosInfos #end) {

        // Default implementation

        #if ceramic_debug_num_entities
        @:privateAccess ceramic.App._entities.push(this);
        #end

        #if ceramic_debug_entity_allocs
        this.posInfos = pos;

        /*if (!debugEntityAllocsInitialized) {
            debugEntityAllocsInitialized = true;
            Timer.interval(null, 5.0, function() {
                #if cpp
                cpp.vm.Gc.run(true);
                #end

                var allClasses:Array<String> = [];
                var usedKeys = new Map<String, Int>();
                if (numEntityAliveInMemoryByClass != null) {
                    for (key in numEntityAliveInMemoryByClass.keys()) {
                        if (!usedKeys.exists(key)) {
                            allClasses.push(key);
                            usedKeys.set(key, numEntityAliveInMemoryByClass.get(key));
                        }
                        else {
                            usedKeys.set(key, usedKeys.get(key) + numEntityAliveInMemoryByClass.get(key));
                        }
                    }
                }
                if (numEntityDestroyedButInMemoryByClass != null) {
                    for (key in numEntityDestroyedButInMemoryByClass.keys()) {
                        if (!usedKeys.exists(key)) {
                            allClasses.push(key);
                            usedKeys.set(key, numEntityDestroyedButInMemoryByClass.get(key));
                        }
                        else {
                            usedKeys.set(key, usedKeys.get(key) + numEntityDestroyedButInMemoryByClass.get(key));
                        }
                    }
                }
                allClasses.sort(function(a:String, b:String) {
                    var numA = 0;
                    if (numEntityDestroyedButInMemoryByClass.exists(a)) {
                        numA = numEntityDestroyedButInMemoryByClass.get(a);
                    }
                    var numB = 0;
                    if (numEntityDestroyedButInMemoryByClass.exists(b)) {
                        numB = numEntityDestroyedButInMemoryByClass.get(b);
                    }
                    return numA - numB;
                });
                ceramic.Shortcuts.log.info(' - entities in memory -');
                for (clazz in allClasses) {
                    ceramic.Shortcuts.log.info('    $clazz / ${usedKeys.get(clazz)} / alive=${numEntityAliveInMemoryByClass.get(clazz)} destroyed=${numEntityDestroyedButInMemoryByClass.get(clazz)}');

                    var weakRefs = destroyedWeakRefs.get(clazz);
                    if (weakRefs != null) {
                        var hasRefs = false;
                        var pathStats = new Map<String,Int>();
                        var newRefs = [];
                        var allPaths:Array<String> = [];
                        for (weakRef in weakRefs) {
                            var entity:Entity = weakRef.get();
                            if (entity != null) {
                                if (Std.isOfType(entity, ceramic.Autorun)) {
                                    var autor:ceramic.Autorun = cast entity;
                                    if (@:privateAccess autor.onRun != null) {
                                        throw "AUTORUN onRun is not null!!!!";
                                    }
                                }
                                newRefs.push(weakRef);
                                var posInfos = entity.posInfos;
                                if (posInfos != null) {
                                    var path = posInfos.fileName + ':' + posInfos.lineNumber;
                                    if (pathStats.exists(path)) {
                                        pathStats.set(path, pathStats.get(path) + 1);
                                    }
                                    else {
                                        pathStats.set(path, 1);
                                        allPaths.push(path);
                                    }
                                }
                            }
                            else {
                                numEntityDestroyedButInMemoryByClass.set(clazz, numEntityDestroyedButInMemoryByClass.get(clazz) - 1);
                            }
                        }
                        weakRefs.splice(0, weakRefs.length);
                        for (weakRef in newRefs) {
                            weakRefs.push(weakRef);
                        }
                        allPaths.sort(function(a, b) {
                            return pathStats.get(a) - pathStats.get(b);
                        });
                        if (allPaths.length > 0) {
                            var limit = 8;
                            var i = allPaths.length - 1;
                            var numLogged = 0;
                            while (limit > 0 && i >= 0) {
                                var path = allPaths[i];
                                var num = pathStats.get(path);
                                numLogged += num;
                                ceramic.Shortcuts.log.info('        leak ${num} x $path');
                                i--;
                                limit--;
                            }
                            if (i > 0) {
                                var total = 0;
                                for (path in allPaths) {
                                    total += pathStats.get(path);
                                }
                                ceramic.Shortcuts.log.info('        leak ${total - numLogged} x ...');
                            }
                        }
                    }
                }
            });
        }

        var clazz = '' + Type.getClass(this);

        #if cpp
        if (numEntityAliveInMemoryByClass.exists(clazz)) {
            numEntityAliveInMemoryByClass.set(clazz, numEntityAliveInMemoryByClass.get(clazz) + 1);
        }
        else {
            numEntityAliveInMemoryByClass.set(clazz, 1);
        }

        //cpp.vm.Gc.setFinalizer(this, cpp.Function.fromStaticFunction(__finalizeEntity));
        #end*/

        #end

    }

    #if (cpp && ceramic_debug_entity_allocs)
    @:void public static function __finalizeEntity(o:Entity):Void {

        var clazz = '' + Type.getClass(o);
        if (o._lifecycleState == -3) {
            numEntityDestroyedButInMemoryByClass.set(clazz, numEntityDestroyedButInMemoryByClass.get(clazz) - 1);
        }
        else {
            numEntityAliveInMemoryByClass.set(clazz, numEntityAliveInMemoryByClass.get(clazz) - 1);
        }

    }
    #end

    /**
     * Destroy this entity. This method is automatically protected from duplicate calls. That means
     * calling multiple times an entity's `destroy()` method will run the destroy code only one time.
     * As soon as `destroy()` is called, the entity is marked `destroyed=true`, even when calling `destroy()`
     * method on a subclass (a macro is inserting a code to mark the object
     * as destroyed at the beginning of every `destroy()` override function.
     */
    public function destroy():Void {

        if (_lifecycleState <= -2) return;
        _lifecycleState = -3; // `Entity.destroy() called` = true

        #if ceramic_debug_num_entities
        @:privateAccess ceramic.App._entities.remove(this);
        #end

        /*#if ceramic_debug_entity_allocs
        var clazz = '' + Type.getClass(this);
        numEntityAliveInMemoryByClass.set(clazz, numEntityAliveInMemoryByClass.get(clazz) - 1);
        if (numEntityDestroyedButInMemoryByClass.exists(clazz)) {
            numEntityDestroyedButInMemoryByClass.set(clazz, numEntityDestroyedButInMemoryByClass.get(clazz) + 1);
        }
        else {
            numEntityDestroyedButInMemoryByClass.set(clazz, 1);
        }

        #if cpp
        var weakRef = new cpp.vm.WeakRef(this);
        if (destroyedWeakRefs.exists(clazz)) {
            destroyedWeakRefs.get(clazz).push(weakRef);
        }
        else {
            destroyedWeakRefs.set(clazz, [weakRef]);
        }
        #end
        #end*/

        if (autoruns != null) {
            for (i in 0...autoruns.length) {
                var _autorun = autoruns[i];
                if (_autorun != null) {
                    autoruns[i] = null;
                    _autorun.destroy();
                }
            }
        }

        emitDestroy(this);

        clearComponents();
        unbindEvents();

    }

    /**
     * Schedules destroy, at the end of the current frame.
     */
    public function dispose():Void {

        if (_lifecycleState == 0) {
            _lifecycleState = 1; // Mark as disposed
            ceramic.App.app.disposedEntities.push(this);
        }

        emitDispose(this);

    }

    /**
     * Remove all events handlers from this entity.
     */
    public function unbindEvents():Void {

        // Events macro will automatically fill this method
        // and create overrides in subclasses to unbind any event

    }

/// Autorun

    public var autoruns(default, null):Array<Autorun> = null;

    /**
     * Creates a new `Autorun` instance with the given callback associated with the current entity.
     * @param run The run callback
     * @return The autorun instance
     */
    public function autorun(run:Void->Void, ?afterRun:Void->Void #if (ceramic_debug_autorun || ceramic_debug_entity_allocs) , ?pos:haxe.PosInfos #end):Autorun {
        /*
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
            //_autorun = null;
        };
        onceDestroy(this, _selfDestroy);
        _autorun.onceDestroy(this, function() {
            offDestroy(_selfDestroy);
            //_autorun = null;
        });

        return _autorun;
        //*/
        //*
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

        var _autorun = new Autorun(run, afterRun #if (ceramic_debug_entity_allocs && tracker_debug_entity_allocs) , pos #end);
        run = null;
        afterRun = null;

        if (autoruns == null) {
            autoruns = [_autorun];
        }
        else {
            var didAdd = false;
            for (i in 0...autoruns.length) {
                var existing = autoruns[i];
                if (existing == null) {
                    autoruns[i] = _autorun;
                    didAdd = true;
                    break;
                }
            }
            if (!didAdd) {
                autoruns.push(_autorun);
            }
        }
        _autorun.onDestroy(this, checkAutoruns);

        return _autorun;
        //*/

    }

    function checkAutoruns(_):Void {

        for (i in 0...autoruns.length) {
            var _autorun = autoruns[i];
            if (_autorun != null && _autorun.destroyed) {
                autoruns[i] = null;
            }
        }

    }

/// Tween

    public function tween(?easing:Easing, duration:Float, fromValue:Float, toValue:Float, update:Float->Float->Void #if ceramic_debug_entity_allocs , ?pos:haxe.PosInfos #end):Tween {

        return Tween.start(this, easing, duration, fromValue, toValue, update #if ceramic_debug_entity_allocs , pos #end);

    }

/// Print

    public function className():String {

        var className = Type.getClassName(Type.getClass(this));
        var dotIndex = className.lastIndexOf('.');
        if (dotIndex != -1) className = className.substr(dotIndex + 1);
        return className;

    }

    function toString():String {

        var className = className();

        if (id != null) {
            return '$className($id)';
        } else {
            return '$className';
        }

    }

/// Components

    #if !haxe_server inline #end public function clearComponents() {

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

    }

    /**
     * Public components mapping. Contain components
     * created separately with `component()` or macro-based components as well.
     */
    public var components(get,set):ReadOnlyMap<String,Component>;
    #if !haxe_server inline #end function get_components():ReadOnlyMap<String,Component> {
        return _components;
    }
    function set_components(components:ReadOnlyMap<String,Component>):ReadOnlyMap<String,Component> {
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

    /**
     * Internal components representation.
     */
    @:noCompletion var _components:Map<String,Component> = null;

    public function component<C:Component>(?name:String, ?component:C, hasField:Bool = false):C {

        if (name == null && component == null) {
            throw 'Invalid component() call: either `name` or `component` should be provided at least.';
        }

        if (name == null) {
            name = Type.getClassName(Type.getClass(component));
            if (_components != null && _components.exists(name)) {
                var baseName = name;
                var n = 1;
                name = baseName + '#' + n;
                while (_components.exists(name)) {
                    n++;
                    name = baseName + '#' + n;
                }
            }
        }

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
            @:privateAccess component.setEntity(this);

            // 2-step to Entity cast to avoid warning
            var componentAsAny:Any = component;
            var componentAsEntity:Entity = componentAsAny;

            componentAsEntity.onceDestroy(this, function(_) {
                // Remove entity reference from component
                if (@:privateAccess component.getEntity() == this) {
                    @:privateAccess component.setEntity(null);
                }
                // Remove component reference from entity
                if (!destroyed) {
                    var existing = _components.get(name);
                    if (existing == component) {
                        _components.remove(name);
                    }
                }
                // Set related field to null, if any
                if (hasField && name != null) {
                    Reflect.setProperty(this, name, null);
                }
            });
            @:privateAccess component.bindAsComponent();
            return component;

        } else {
            if (_components == null) return null;
            return cast _components.get(name);
        }

    }

    public function hasComponent(name:String):Bool {

        return component(name) != null;

    }

    public function removeComponent(name:String):Void {

        var existing = _components.get(name);
        if (existing != null) {
            _components.remove(name);
            var existingAsEntity:Entity = cast existing;
            existingAsEntity.destroy();
        }

    }

}
