// Ported from gpui-pre 0.3.10: src/element.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import haxe.ds.IntMap;
import gpui.Window.ElementStateBox;

/**
 * A globally unique identifier for an element: the path of element ids from
 * the root of the window.
 *
 * Rust keeps the path and its hash, and hashes it on every element state
 * lookup. The port interns the paths of a window in a trie: a node is its
 * parent plus one `ElementId` segment, so pushing an id is one map step from
 * the current node and two equal paths are the same object. Element states
 * hang on their node (`states`), keyed by the integer id of their type: no
 * string is built and nothing is hashed on the hot path.
 *
 * Segments compare by value like Rust's `ElementId: Hash + Eq`: `View(5)` and
 * `Integer(5)` are different, `Name('a')` equals another `Name('a')`.
 */
class GlobalElementId {

    static var nextId:Int = 1;

    /** Stable integer id of this path (unique within the process). */
    public final id:Int;

    /** The node of the parent path, `null` for the root (the empty path). */
    public final parent:Null<GlobalElementId>;

    /** The last element id of the path, `null` for the root. */
    public final segment:Null<ElementId>;

    /** Number of element ids in the path. */
    public final depth:Int;

    /** Unique string key of this path, built once on first use (debugging, cold maps). */
    public var key(get, never):String;

    var _key:Null<String> = null;

    // Children by segment variant, created on first use
    var viewChildren:Null<IntMap<GlobalElementId>> = null;
    var integerChildren:Null<IntMap<GlobalElementId>> = null;
    var nameChildren:Null<Map<String, GlobalElementId>> = null;
    var namedIntegerChildren:Null<Map<String, IntMap<GlobalElementId>>> = null;
    var codeLocationChildren:Null<Map<String, IntMap<GlobalElementId>>> = null;
    /** Lookup helper for `NamedChild(parent, name)`: resolves `parent` as a segment of this helper, then `name` (never handed out as a path). */
    var namedChildBase:Null<GlobalElementId> = null;

    /**
     * The element state boxes of this path, one per state type, owned by one
     * of the two frames of the window (see `Window.elementStateBox`).
     */
    @:allow(gpui)
    var states:Null<Array<ElementStateBox<Dynamic>>> = null;

    function new(parent:Null<GlobalElementId>, segment:Null<ElementId>) {
        #if gpui_count_allocations gpui.util.AllocationCounters.globalElementIds++; #end
        this.id = nextId++;
        this.parent = parent;
        this.segment = segment;
        this.depth = parent != null ? parent.depth + 1 : 0;
    }

    /**
     * The root of a trie (the empty path).
     */
    public static function root():GlobalElementId {
        return new GlobalElementId(null, null);
    }

    /**
     * The interned node of this path followed by `id`.
     */
    public function child(id:ElementId):GlobalElementId {
        switch id {
            case View(entityId):
                var map = viewChildren;
                if (map == null) map = viewChildren = new IntMap();
                var node = map.get(entityId);
                if (node == null) {
                    node = new GlobalElementId(this, id);
                    map.set(entityId, node);
                }
                return node;
            case Integer(value):
                var map = integerChildren;
                if (map == null) map = integerChildren = new IntMap();
                var node = map.get(value);
                if (node == null) {
                    node = new GlobalElementId(this, id);
                    map.set(value, node);
                }
                return node;
            case Name(name):
                var map = nameChildren;
                if (map == null) map = nameChildren = new Map();
                var node = map.get(name);
                if (node == null) {
                    node = new GlobalElementId(this, id);
                    map.set(name, node);
                }
                return node;
            case NamedInteger(name, value):
                var map = namedIntegerChildren;
                if (map == null) map = namedIntegerChildren = new Map();
                var byInt = map.get(name);
                if (byInt == null) {
                    byInt = new IntMap();
                    map.set(name, byInt);
                }
                var node = byInt.get(value);
                if (node == null) {
                    node = new GlobalElementId(this, id);
                    byInt.set(value, node);
                }
                return node;
            case CodeLocation(file, line):
                var map = codeLocationChildren;
                if (map == null) map = codeLocationChildren = new Map();
                var byInt = map.get(file);
                if (byInt == null) {
                    byInt = new IntMap();
                    map.set(file, byInt);
                }
                var node = byInt.get(line);
                if (node == null) {
                    node = new GlobalElementId(this, id);
                    byInt.set(line, node);
                }
                return node;
            case NamedChild(parentId, name):
                var base = namedChildBase;
                if (base == null) base = namedChildBase = new GlobalElementId(null, null);
                // `base.child(parentId)` is a helper node too: it is never a path
                final helper = base.child(parentId);
                var map = helper.nameChildren;
                if (map == null) map = helper.nameChildren = new Map();
                var node = map.get(name);
                if (node == null) {
                    node = new GlobalElementId(this, id);
                    map.set(name, node);
                }
                return node;
        }
    }

    /**
     * The element state box of the given type id on this path, or `null`.
     */
    @:allow(gpui)
    inline function findState(typeId:Int):Null<ElementStateBox<Dynamic>> {
        final states = this.states;
        var result:Null<ElementStateBox<Dynamic>> = null;
        if (states != null) {
            for (i in 0...states.length) {
                final box = states[i];
                if (box.typeId == typeId) {
                    result = box;
                    break;
                }
            }
        }
        return result;
    }

    @:allow(gpui)
    function addState(box:ElementStateBox<Dynamic>):Void {
        if (states == null) states = [];
        states.push(box);
    }

    @:allow(gpui)
    function removeState(box:ElementStateBox<Dynamic>):Void {
        if (states != null) states.remove(box);
    }

    /**
     * The element ids of the path, from the root (rebuilt: for debugging).
     */
    public function ids():Array<ElementId> {
        final result:Array<ElementId> = [];
        var node = this;
        while (node.segment != null) {
            result.push(node.segment);
            node = node.parent;
        }
        result.reverse();
        return result;
    }

    function get_key():String {
        var key = _key;
        if (key == null) {
            key = segment == null ? '' : (parent.depth == 0 ? idToString(segment) : parent.key + '.' + idToString(segment));
            _key = key;
        }
        return key;
    }

    /**
     * The string key of a path given as an array of ids (what `key` returns
     * for the interned node of that path).
     */
    public static function keyOf(ids:Array<ElementId>):String {
        final buf = new StringBuf();
        for (i in 0...ids.length) {
            if (i > 0)
                buf.add('.');
            buf.add(idToString(ids[i]));
        }
        return buf.toString();
    }

    public static function idToString(id:ElementId):String {
        return switch id {
            case View(entityId): 'view-' + entityId;
            case Integer(id): '' + id;
            case Name(name): name;
            case NamedInteger(name, id): name + '-' + id;
            case CodeLocation(file, line): file + ':' + line;
            case NamedChild(parent, name): idToString(parent) + '/' + name;
        }
    }

    /** Interned paths are unique: equal paths are the same node. */
    public inline function equals(other:GlobalElementId):Bool {
        return this == other;
    }

    public function toString():String {
        return key;
    }

}
