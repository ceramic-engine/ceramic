// Ported from gpui-pre 0.3.10: src/window.rs (`TypeId` of element states)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Integer ids of the element state types: Rust keys element states by
 * `(GlobalElementId, TypeId)`, the port by the interned path and this id.
 * A class gets its id the first time it is used.
 */
class ElementStateType {

    // Created on first use: a static initializer of another class may run first
    static var ids:Null<haxe.ds.ObjectMap<Dynamic, Int>> = null;

    static var names:Null<Array<String>> = null;

    static var lastClass:Null<Class<Dynamic>> = null;

    static var lastId:Int = -1;

    /**
     * The id of the given state class.
     */
    public static function of(type:Class<Dynamic>):Int {
        if (type == lastClass) {
            return lastId;
        }
        if (ids == null) {
            ids = new haxe.ds.ObjectMap();
            names = [];
        }
        var id = ids.get(type);
        if (id == null) {
            id = names.length;
            names.push(Type.getClassName(type));
            ids.set(type, id);
        }
        lastClass = type;
        lastId = id;
        return id;
    }

    /**
     * The class name of a state type id (debugging).
     */
    public static function name(id:Int):String {
        return names[id];
    }

}
