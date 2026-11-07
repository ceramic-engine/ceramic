// Ported from gpui-pre 0.3.10: src/element.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

import haxe.ds.IntMap;
import glaze.Window.ElementStateBox;

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
 *
 * GPUI does not intern its ids, so it has no growth: here ids that change
 * every frame would grow the trie without bound. `ElementIdTrie.endFrame()`
 * stamps the frame on each visited node and, once the trie is large and has
 * doubled since the last sweep, drops the nodes not visited for two frames
 * that hold no element state and have no live child (bottom up, so a node
 * with a state or with a descendant holding one is always kept).
 */
class GlobalElementId {

    static var nextId:Int = 1;

    /** The trie this node belongs to (frame counter and node count) */
    @:allow(glaze)
    final trie:ElementIdTrie;

    /** The last frame of the trie that reached this node through `child()` */
    @:allow(glaze)
    var lastVisit:Int = 0;

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
    @:allow(glaze)
    var states:Null<Array<ElementStateBox<Dynamic>>> = null;

    function new(trie:ElementIdTrie, parent:Null<GlobalElementId>, segment:Null<ElementId>) {
        #if glaze_count_allocations glaze.util.AllocationCounters.globalElementIds++; #end
        this.id = nextId++;
        this.trie = trie;
        this.parent = parent;
        this.segment = segment;
        this.depth = parent != null ? parent.depth + 1 : 0;
        this.lastVisit = trie.frame;
        trie.nodeCount++;
    }

    /**
     * The root of a new trie (the empty path).
     */
    public static function root():GlobalElementId {
        return new GlobalElementId(new ElementIdTrie(), null, null);
    }

    /**
     * The interned node of this path followed by `id`.
     */
    public function child(id:ElementId):GlobalElementId {
        final node = lookupChild(id);
        node.lastVisit = trie.frame;
        return node;
    }

    function lookupChild(id:ElementId):GlobalElementId {
        switch id {
            case View(entityId):
                var map = viewChildren;
                if (map == null) map = viewChildren = new IntMap();
                var node = map.get(entityId);
                if (node == null) {
                    node = new GlobalElementId(trie, this, id);
                    map.set(entityId, node);
                }
                return node;
            case Integer(value):
                var map = integerChildren;
                if (map == null) map = integerChildren = new IntMap();
                var node = map.get(value);
                if (node == null) {
                    node = new GlobalElementId(trie, this, id);
                    map.set(value, node);
                }
                return node;
            case Name(name):
                var map = nameChildren;
                if (map == null) map = nameChildren = new Map();
                var node = map.get(name);
                if (node == null) {
                    node = new GlobalElementId(trie, this, id);
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
                    node = new GlobalElementId(trie, this, id);
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
                    node = new GlobalElementId(trie, this, id);
                    byInt.set(line, node);
                }
                return node;
            case NamedChild(parentId, name):
                var base = namedChildBase;
                if (base == null) base = namedChildBase = new GlobalElementId(trie, null, null);
                // `base.lookupChild(parentId)` is a helper node too: it is never a path
                final helper = base.lookupChild(parentId);
                var map = helper.nameChildren;
                if (map == null) map = helper.nameChildren = new Map();
                var node = map.get(name);
                if (node == null) {
                    node = new GlobalElementId(trie, this, id);
                    map.set(name, node);
                }
                return node;
        }
    }

    /**
     * The element state box of the given type id on this path, or `null`.
     */
    @:allow(glaze)
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

    @:allow(glaze)
    function addState(box:ElementStateBox<Dynamic>):Void {
        if (states == null) states = [];
        states.push(box);
    }

    @:allow(glaze)
    function removeState(box:ElementStateBox<Dynamic>):Void {
        if (states != null) states.remove(box);
    }

    /**
     * Drops the stale descendants of this node (not visited since `minVisit`,
     * without element state, without a kept child) and returns whether this
     * node is stale itself (the caller detaches it).
     */
    @:allow(glaze)
    function sweep(minVisit:Int):Bool {
        var live = false;
        if (viewChildren != null && !sweepIntMap(viewChildren, minVisit)) live = true;
        if (integerChildren != null && !sweepIntMap(integerChildren, minVisit)) live = true;
        if (nameChildren != null && !sweepStringMap(nameChildren, minVisit)) live = true;
        if (namedIntegerChildren != null && !sweepNestedMap(namedIntegerChildren, minVisit)) live = true;
        if (codeLocationChildren != null && !sweepNestedMap(codeLocationChildren, minVisit)) live = true;
        if (namedChildBase != null) {
            if (namedChildBase.sweep(minVisit)) {
                namedChildBase.detach();
                namedChildBase = null;
            }
            else {
                live = true;
            }
        }
        if (live || lastVisit >= minVisit || (states != null && states.length > 0)) {
            return false;
        }
        return true;
    }

    /** Sweeps the nodes of a map; returns true when the map is empty afterwards */
    static function sweepIntMap(map:IntMap<GlobalElementId>, minVisit:Int):Bool {
        var empty = true;
        var swept:Null<Array<Int>> = null;
        for (key => node in map) {
            if (node.sweep(minVisit)) {
                if (swept == null) swept = [];
                swept.push(key);
                node.detach();
            }
            else {
                empty = false;
            }
        }
        // Removed after the iteration: maps are not changed while iterated
        if (swept != null) {
            for (key in swept) map.remove(key);
        }
        return empty;
    }

    static function sweepStringMap(map:Map<String, GlobalElementId>, minVisit:Int):Bool {
        var empty = true;
        var swept:Null<Array<String>> = null;
        for (key => node in map) {
            if (node.sweep(minVisit)) {
                if (swept == null) swept = [];
                swept.push(key);
                node.detach();
            }
            else {
                empty = false;
            }
        }
        if (swept != null) {
            for (key in swept) map.remove(key);
        }
        return empty;
    }

    static function sweepNestedMap(map:Map<String, IntMap<GlobalElementId>>, minVisit:Int):Bool {
        var empty = true;
        var swept:Null<Array<String>> = null;
        for (key => byInt in map) {
            if (sweepIntMap(byInt, minVisit)) {
                if (swept == null) swept = [];
                swept.push(key);
            }
            else {
                empty = false;
            }
        }
        if (swept != null) {
            for (key in swept) map.remove(key);
        }
        return empty;
    }

    /** Called on a swept node: it is no longer counted (its children were swept before it) */
    function detach():Void {
        trie.nodeCount--;
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

/**
 * The bookkeeping shared by the nodes of one trie (one per window): the
 * frame counter stamped on visited nodes, the node count and the sweep
 * thresholds.
 */
class ElementIdTrie {

    /** Sweep only above this many nodes */
    public static inline final MIN_SWEEP_NODES = 4096;

    /** A node not visited for this many frames is stale */
    public static inline final STALE_FRAMES = 2;

    /** The current frame (advanced by `endFrame()`) */
    public var frame:Int = 0;

    /** Live nodes (the root, the paths and the `NamedChild` helper nodes) */
    public var nodeCount:Int = 0;

    /** Node count after the last sweep (or at the start) */
    public var lastSweepCount:Int = 0;

    /** Number of sweeps run (tests) */
    public var sweeps:Int = 0;

    public function new() {}

    /**
     * Ends the frame drawn with `root` as the empty path: nodes created or
     * reached from now on carry the next frame, and the trie is swept when
     * it holds more than `MIN_SWEEP_NODES` nodes and twice the nodes it had
     * after the last sweep.
     */
    public function endFrame(root:GlobalElementId):Void {
        frame++;
        if (nodeCount > MIN_SWEEP_NODES && nodeCount > lastSweepCount * 2) {
            // The frame just drawn is `frame - 1`: stale means not visited by it nor by the one before
            root.sweep(frame - STALE_FRAMES);
            lastSweepCount = nodeCount;
            sweeps++;
        }
    }

}
