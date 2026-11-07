// Ported from gpui-kit 0.8.1: crates/component/src/searchable_list/delegate.rs (SearchableListItem defaults),
// crates/component/src/searchable_list/vec.rs (the String / SharedString / &'static str impls)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.searchablelist;

import gpui.AnyElement;
import gpui.App;
import gpui.IntoElement;
import gpui.Window;

/**
 * Calls of the `SearchableListItem` trait on any item: a `String` is its
 * own title and value (the Rust impls for `String`, `SharedString` and
 * `&'static str`), any other item must implement `SearchableListItem`.
 */
class SearchableListItems {

    public static function title(item:Any):String {
        if (Std.isOfType(item, String)) return (item:String);
        return (cast item:SearchableListItem).title();
    }

    public static function displayTitle(item:Any):Null<AnyElement> {
        if (Std.isOfType(item, String)) return null;
        return (cast item:SearchableListItem).displayTitle();
    }

    public static function render(item:Any, window:Window, cx:App):IntoElement {
        if (Std.isOfType(item, String)) return (item:String);
        return (cast item:SearchableListItem).render(window, cx);
    }

    public static function value(item:Any):Any {
        if (Std.isOfType(item, String)) return item;
        return (cast item:SearchableListItem).value();
    }

    public static function matches(item:Any, query:String):Bool {
        if (Std.isOfType(item, String)) return containsIgnoreCase((item:String), query);
        return (cast item:SearchableListItem).matches(query);
    }

    public static function disabled(item:Any):Bool {
        if (Std.isOfType(item, String)) return false;
        return (cast item:SearchableListItem).disabled();
    }

    /**
     * Rust `PartialEq` on item values: `==` for strings, numbers and booleans,
     * `Type.enumEq` for enum values, `equals` for a `SearchableValue`, and
     * identity otherwise.
     */
    public static function valueEquals(a:Any, b:Any):Bool {
        if (a == b) return true;
        if (a == null || b == null) return false;
        if (Reflect.isEnumValue(a)) return Reflect.isEnumValue(b) && Type.enumEq(a, b);
        if (Std.isOfType(a, SearchableValue)) return (cast a:SearchableValue).equals(b);
        return false;
    }

    /**
     * Equality of two items (the Rust `PartialEq` of the item type, used by
     * the selection tuples): strings by value, other items by their values.
     */
    public static function itemEquals(a:Any, b:Any):Bool {
        if (a == b) return true;
        if (a == null || b == null) return false;
        if (Std.isOfType(a, String) || Std.isOfType(b, String)) return false;
        return valueEquals(value(a), value(b));
    }

    /**
     * `haystack.to_lowercase().contains(&query.to_lowercase())`.
     */
    public static function containsIgnoreCase(haystack:String, query:String):Bool {
        return haystack.toLowerCase().indexOf(query.toLowerCase()) != -1;
    }

}

/**
 * An item value compared by `equals` rather than by identity (Rust
 * `PartialEq` on a custom `Value`).
 */
interface SearchableValue {
    function equals(other:Any):Bool;
}
