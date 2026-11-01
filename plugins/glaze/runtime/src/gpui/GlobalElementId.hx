// Ported from gpui-pre 0.3.10: src/element.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * A globally unique identifier for an element: the path of element ids from
 * the root of the window. Rust hashes the path; here `key` is a string
 * built from it, used to store element state.
 */
class GlobalElementId {

    /** The element ids of the path, from the root. */
    public final ids:Array<ElementId>;

    /** Unique string key of this path. */
    public final key:String;

    public function new(ids:Array<ElementId>) {
        #if gpui_count_allocations gpui.util.AllocationCounters.globalElementIds++; #end
        this.ids = ids;
        final buf = new StringBuf();
        for (i in 0...ids.length) {
            if (i > 0)
                buf.add('.');
            buf.add(idToString(ids[i]));
        }
        this.key = buf.toString();
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

    public inline function equals(other:GlobalElementId):Bool {
        return other != null && key == other.key;
    }

    public function toString():String {
        return key;
    }

}
