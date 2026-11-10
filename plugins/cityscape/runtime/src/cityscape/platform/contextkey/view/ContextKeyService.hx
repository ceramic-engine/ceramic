// Ported from vscode src/vs/platform/contextkey/browser/contextKeyService.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.contextkey.view;

import cityscape.base.common.Event;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle;
import cityscape.platform.contextkey.common.ContextKey;

/*
 * The context key services without the DOM: a scoped service is created
 * from its parent (Monaco attaches it to a DOM node and finds it again from
 * the focused element); the configuration aware root container (`config.*`
 * keys) is not ported, Cityscape has no configuration service.
 */

class Context implements IContext {

    var _parent:Null<Context>;
    final _value:Map<String, Any>;
    final _id:Int;

    public function new(id:Int, parent:Null<Context>) {
        this._id = id;
        this._parent = parent;
        this._value = new Map();
        this._value.set('_contextId', id);
    }

    public var value(get, never):Map<String, Any>;
    function get_value():Map<String, Any> {
        return this._value.copy();
    }

    /**
     * Cityscape: counts the changes of this context's own values (with
     * `parentContext`, a reader of `collectAllValues` knows when to read again).
     */
    public var version(default, null):Int = 0;

    /**
     * Cityscape: the parent context (null for a root).
     */
    public inline function parentContext():Null<Context> {
        return this._parent;
    }

    public function setValue(key:String, value:Any):Bool {
        if (!this._value.exists(key) || !JsCompare.strictEquals(this._value.get(key), value)) {
            this._value.set(key, value);
            this.version++;
            return true;
        }
        return false;
    }

    public function removeValue(key:String):Bool {
        if (this._value.exists(key)) {
            this._value.remove(key);
            this.version++;
            return true;
        }
        return false;
    }

    public function getValue(key:String):Any {
        final ret = this._value.get(key);
        if (ret == null && this._parent != null) {
            return this._parent.getValue(key);
        }
        return ret;
    }

    public function updateParent(parent:Context):Void {
        this._parent = parent;
    }

    public function collectAllValues():Map<String, Any> {
        final result = this._parent != null ? this._parent.collectAllValues() : new Map<String, Any>();
        for (key => value in this._value) {
            result.set(key, value);
        }
        result.remove('_contextId');
        return result;
    }

}

class NullContext extends Context {

    public static final INSTANCE = new NullContext();

    function new() {
        super(-1, null);
    }

    override public function setValue(key:String, value:Any):Bool {
        return false;
    }

    override public function removeValue(key:String):Bool {
        return false;
    }

    override public function getValue(key:String):Any {
        return null;
    }

    override public function collectAllValues():Map<String, Any> {
        return new Map();
    }

}

class ContextKey<T> implements IContextKey<T> {

    final _service:AbstractContextKeyService;
    final _key:String;
    final _defaultValue:Null<T>;

    public function new(service:AbstractContextKeyService, key:String, defaultValue:Null<T>) {
        this._service = service;
        this._key = key;
        this._defaultValue = defaultValue;
        this.reset();
    }

    public function set(value:T):Void {
        this._service.setContext(this._key, value);
    }

    public function reset():Void {
        if (this._defaultValue == null) {
            this._service.removeContext(this._key);
        }
        else {
            this._service.setContext(this._key, this._defaultValue);
        }
    }

    public function get():Null<T> {
        return this._service.getContextKeyValue(this._key);
    }

}

class SimpleContextKeyChangeEvent implements IContextKeyChangeEvent {

    public final key:String;

    public function new(key:String) {
        this.key = key;
    }

    public function affectsSome(keys:IReadableSet<String>):Bool {
        return keys.has(this.key);
    }

    public function allKeysContainedIn(keys:IReadableSet<String>):Bool {
        return this.affectsSome(keys);
    }

}

class ArrayContextKeyChangeEvent implements IContextKeyChangeEvent {

    public final keys:Array<String>;

    public function new(keys:Array<String>) {
        this.keys = keys;
    }

    public function affectsSome(keys:IReadableSet<String>):Bool {
        for (key in this.keys) {
            if (keys.has(key)) {
                return true;
            }
        }
        return false;
    }

    public function allKeysContainedIn(keys:IReadableSet<String>):Bool {
        for (key in this.keys) {
            if (!keys.has(key)) {
                return false;
            }
        }
        return true;
    }

}

class CompositeContextKeyChangeEvent implements IContextKeyChangeEvent {

    public final events:Array<IContextKeyChangeEvent>;

    public function new(events:Array<IContextKeyChangeEvent>) {
        this.events = events;
    }

    public function affectsSome(keys:IReadableSet<String>):Bool {
        for (e in this.events) {
            if (e.affectsSome(keys)) {
                return true;
            }
        }
        return false;
    }

    public function allKeysContainedIn(keys:IReadableSet<String>):Bool {
        for (e in this.events) {
            if (!e.allKeysContainedIn(keys)) {
                return false;
            }
        }
        return true;
    }

}

/**
 * A set of strings (Monaco uses `Set<string>` as an `IReadableSet`).
 */
class StringSet implements IReadableSet<String> {

    final _set:Map<String, Bool> = new Map();

    public function new(?values:Array<String>) {
        if (values != null) {
            for (v in values) {
                _set.set(v, true);
            }
        }
    }

    public function add(value:String):Void {
        _set.set(value, true);
    }

    public function has(value:String):Bool {
        return _set.exists(value);
    }

}

/**
 * Monaco's `PauseableEmitter` with a `merge` function (the only use in the
 * context key service): events fired while paused are merged into one.
 */
private class PauseableChangeEmitter extends Emitter<IContextKeyChangeEvent> {

    var _isPaused = 0;
    var _eventQueue:Array<IContextKeyChangeEvent> = [];

    public function pause():Void {
        this._isPaused++;
    }

    public function resume():Void {
        if (this._isPaused != 0 && --this._isPaused == 0) {
            if (this._eventQueue.length > 0) {
                final events = this._eventQueue;
                this._eventQueue = [];
                super.fire(new CompositeContextKeyChangeEvent(events));
            }
        }
    }

    override public function fire(event:IContextKeyChangeEvent):Void {
        if (this._isPaused != 0) {
            this._eventQueue.push(event);
        }
        else {
            super.fire(event);
        }
    }

}

abstract class AbstractContextKeyService extends Disposable implements IContextKeyService {

    var _isDisposed:Bool;
    var _myContextId:Int;

    final _onDidChangeContext:PauseableChangeEmitter;

    public var onDidChangeContext(get, never):Event<IContextKeyChangeEvent>;
    function get_onDidChangeContext():Event<IContextKeyChangeEvent> {
        return this._onDidChangeContext.event;
    }

    public function new(myContextId:Int) {
        super();
        this._onDidChangeContext = this._register(new PauseableChangeEmitter());
        this._isDisposed = false;
        this._myContextId = myContextId;
    }

    public var contextId(get, never):Int;
    function get_contextId():Int {
        return this._myContextId;
    }

    public function createKey<T>(key:String, defaultValue:Null<T>):IContextKey<T> {
        if (this._isDisposed) {
            throw 'AbstractContextKeyService has been disposed';
        }
        return new ContextKey<T>(this, key, defaultValue);
    }

    public function bufferChangeEvents(callback:() -> Void):Void {
        this._onDidChangeContext.pause();
        try {
            callback();
        }
        catch (e:Dynamic) {
            this._onDidChangeContext.resume();
            throw e;
        }
        this._onDidChangeContext.resume();
    }

    public function createScoped(target:Any):IScopedContextKeyService {
        if (this._isDisposed) {
            throw 'AbstractContextKeyService has been disposed';
        }
        return new ScopedContextKeyService(this);
    }

    public function createOverlay(overlay:Array<{key:String, value:Any}>):IContextKeyService {
        if (this._isDisposed) {
            throw 'AbstractContextKeyService has been disposed';
        }
        return new OverlayContextKeyService(this, overlay);
    }

    public function contextMatchesRules(rules:Null<ContextKeyExpression>):Bool {
        if (this._isDisposed) {
            throw 'AbstractContextKeyService has been disposed';
        }
        final context = this.getContextValuesContainer(this._myContextId);
        final result = (rules != null ? rules.evaluate(context) : true);
        return result;
    }

    public function getContextKeyValue<T>(key:String):Null<T> {
        if (this._isDisposed) {
            return null;
        }
        return this.getContextValuesContainer(this._myContextId).getValue(key);
    }

    public function setContext(key:String, value:Any):Void {
        if (this._isDisposed) {
            return;
        }
        final myContext = this.getContextValuesContainer(this._myContextId);
        if (myContext == null) {
            return;
        }
        if (myContext.setValue(key, value)) {
            this._onDidChangeContext.fire(new SimpleContextKeyChangeEvent(key));
        }
    }

    public function removeContext(key:String):Void {
        if (this._isDisposed) {
            return;
        }
        if (this.getContextValuesContainer(this._myContextId).removeValue(key)) {
            this._onDidChangeContext.fire(new SimpleContextKeyChangeEvent(key));
        }
    }

    /**
     * The context of this service (Monaco finds the scope from a DOM node:
     * `target` is ignored).
     */
    public function getContext(target:Any):IContext {
        if (this._isDisposed) {
            return NullContext.INSTANCE;
        }
        return this.getContextValuesContainer(this._myContextId);
    }

    abstract public function getContextValuesContainer(contextId:Int):Context;
    abstract public function createChildContext(?parentContextId:Int):Int;
    abstract public function disposeContext(contextId:Int):Void;
    abstract public function updateParent(parentContextKeyService:IContextKeyService):Void;

    override public function dispose():Void {
        super.dispose();
        this._isDisposed = true;
    }

}

/**
 * The root context key service (one per `Cityscape` context).
 */
class ContextKeyService extends AbstractContextKeyService {

    var _lastContextId:Int;
    final _contexts = new Map<Int, Context>();

    /**
     * The number of contexts (the root and the scoped ones not disposed),
     * for the leak tests.
     */
    public function contextCount():Int {
        var count = 0;
        for (_ in _contexts) {
            count++;
        }
        return count;
    }

    public function new() {
        super(0);
        this._lastContextId = 0;

        final myContext = new Context(this._myContextId, null);
        this._contexts.set(this._myContextId, myContext);
    }

    public function getContextValuesContainer(contextId:Int):Context {
        if (this._isDisposed) {
            return NullContext.INSTANCE;
        }
        final context = this._contexts.get(contextId);
        return context != null ? context : NullContext.INSTANCE;
    }

    public function createChildContext(?parentContextId:Int):Int {
        if (parentContextId == null) {
            parentContextId = this._myContextId;
        }
        if (this._isDisposed) {
            throw 'ContextKeyService has been disposed';
        }
        final id = (++this._lastContextId);
        this._contexts.set(id, new Context(id, this.getContextValuesContainer(parentContextId)));
        return id;
    }

    public function disposeContext(contextId:Int):Void {
        if (!this._isDisposed) {
            this._contexts.remove(contextId);
        }
    }

    public function updateParent(_parentContextKeyService:IContextKeyService):Void {
        throw 'Cannot update parent of root ContextKeyService';
    }

}

class ScopedContextKeyService extends AbstractContextKeyService implements IScopedContextKeyService {

    var _parent:AbstractContextKeyService;

    final _parentChangeListener = new MutableDisposable<IDisposable>();

    public function new(parent:AbstractContextKeyService) {
        super(parent.createChildContext());
        this._register(this._parentChangeListener);
        this._parent = parent;
        this._updateParentChangeListener();
    }

    function _updateParentChangeListener():Void {
        // Forward parent events to this listener. Parent will change.
        this._parentChangeListener.value = this._parent.onDidChangeContext(e -> {
            final thisContainer = this._parent.getContextValuesContainer(this._myContextId);
            final thisContextValues = thisContainer.value;

            if (!e.allKeysContainedIn(new StringSet([for (k in thisContextValues.keys()) k]))) {
                this._onDidChangeContext.fire(e);
            }
        });
    }

    override public function dispose():Void {
        if (this._isDisposed) {
            return;
        }

        this._parent.disposeContext(this._myContextId);
        super.dispose();
    }

    public function getContextValuesContainer(contextId:Int):Context {
        if (this._isDisposed) {
            return NullContext.INSTANCE;
        }
        return this._parent.getContextValuesContainer(contextId);
    }

    public function createChildContext(?parentContextId:Int):Int {
        if (parentContextId == null) {
            parentContextId = this._myContextId;
        }
        if (this._isDisposed) {
            throw 'ScopedContextKeyService has been disposed';
        }
        return this._parent.createChildContext(parentContextId);
    }

    public function disposeContext(contextId:Int):Void {
        if (this._isDisposed) {
            return;
        }
        this._parent.disposeContext(contextId);
    }

    public function updateParent(parentContextKeyService:IContextKeyService):Void {
        final parent:AbstractContextKeyService = cast parentContextKeyService;
        if (this._parent == parent) {
            return;
        }

        final thisContainer = this._parent.getContextValuesContainer(this._myContextId);
        final oldAllValues = thisContainer.collectAllValues();
        this._parent = parent;
        this._updateParentChangeListener();
        final newParentContainer = this._parent.getContextValuesContainer(this._parent.contextId);
        thisContainer.updateParent(newParentContainer);

        final newAllValues = thisContainer.collectAllValues();
        final changedKeys:Array<String> = [];
        for (key => value in oldAllValues) {
            if (!newAllValues.exists(key) || !JsCompare.strictEquals(newAllValues.get(key), value)) {
                changedKeys.push(key);
            }
        }
        for (key => value in newAllValues) {
            if (!oldAllValues.exists(key) && changedKeys.indexOf(key) < 0) {
                changedKeys.push(key);
            }
        }

        this._onDidChangeContext.fire(new ArrayContextKeyChangeEvent(changedKeys));
    }

}

class OverlayContext implements IContext {

    final parent:IContext;
    final overlay:Map<String, Any>;

    public function new(parent:IContext, overlay:Map<String, Any>) {
        this.parent = parent;
        this.overlay = overlay;
    }

    public function getValue(key:String):Any {
        return this.overlay.exists(key) ? this.overlay.get(key) : this.parent.getValue(key);
    }

}

class OverlayContextKeyService implements IContextKeyService {

    final overlay:Map<String, Any>;
    final parent:IContextKeyService;

    public var contextId(get, never):Int;
    function get_contextId():Int {
        final p = Std.downcast(this.parent, AbstractContextKeyService);
        if (p != null) {
            return p.contextId;
        }
        return (cast this.parent : OverlayContextKeyService).contextId;
    }

    public var onDidChangeContext(get, never):Event<IContextKeyChangeEvent>;
    function get_onDidChangeContext():Event<IContextKeyChangeEvent> {
        return this.parent.onDidChangeContext;
    }

    public function new(parent:IContextKeyService, overlay:Array<{key:String, value:Any}>) {
        this.parent = parent;
        this.overlay = new Map();
        if (overlay != null) {
            for (entry in overlay) {
                this.overlay.set(entry.key, entry.value);
            }
        }
    }

    public function bufferChangeEvents(callback:() -> Void):Void {
        this.parent.bufferChangeEvents(callback);
    }

    public function createKey<T>(key:String, defaultValue:Null<T>):IContextKey<T> {
        throw 'Not supported.';
    }

    public function getContext(target:Any):IContext {
        return new OverlayContext(this.parent.getContext(target), this.overlay);
    }

    public function getContextValuesContainer(contextId:Int):IContext {
        final p = Std.downcast(this.parent, AbstractContextKeyService);
        final parentContext:IContext = p != null ? p.getContextValuesContainer(contextId) : (cast this.parent : OverlayContextKeyService).getContextValuesContainer(contextId);
        return new OverlayContext(parentContext, this.overlay);
    }

    public function contextMatchesRules(rules:Null<ContextKeyExpression>):Bool {
        final context = this.getContextValuesContainer(this.contextId);
        final result = (rules != null ? rules.evaluate(context) : true);
        return result;
    }

    public function getContextKeyValue<T>(key:String):Null<T> {
        return this.overlay.exists(key) ? this.overlay.get(key) : this.parent.getContextKeyValue(key);
    }

    public function createScoped(target:Any):IScopedContextKeyService {
        throw 'Not supported.';
    }

    public function createOverlay(overlay:Array<{key:String, value:Any}>):IContextKeyService {
        return new OverlayContextKeyService(this, overlay);
    }

    public function updateParent(parentContextKeyService:IContextKeyService):Void {
        throw 'Not supported.';
    }

}
