// Ported from gpui-kit 0.8.1: crates/component/src/searchable_list/delegate.rs (SearchableListItem)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.searchablelist;

import gpui.AnyElement;
import gpui.App;
import gpui.IntoElement;
import gpui.Window;

/**
 * An item that can appear in a searchable list (Select, ComboBox).
 *
 * Rust implements the trait for `String`, `SharedString` and `&'static str`
 * too. Haxe strings cannot implement an interface, so the lists accept any
 * item type and go through `SearchableListItems` (`title`, `value`,
 * `matches`...), which treats a `String` as the Rust string impls do (its
 * own title and value) and calls this interface otherwise. Extend
 * `SearchableListItemBase` to get the trait defaults.
 *
 * `Value: Clone + PartialEq` becomes `Any`, compared with
 * `SearchableListItems.valueEquals`.
 */
interface SearchableListItem {

    /**
     * Short display label shown in the dropdown row and in the trigger by default.
     *
     * This is also what assistive technology reads as the committed value, so
     * it has to stand on its own as text even when `displayTitle` draws
     * something richer.
     */
    function title():String;

    /**
     * Override the trigger display element (e.g. "Country (US)" instead of just "United States").
     *
     * Returns `null` to fall back to `title()`. Presentation only: the
     * accessible value keeps reporting `title`.
     */
    function displayTitle():Null<AnyElement>;

    /**
     * Render this item's row content inside the dropdown.
     *
     * Override to add icons, avatars, secondary text, etc.
     * The default renders `title()`.
     */
    function render(window:Window, cx:App):IntoElement;

    /** The value that identifies this item. */
    function value():Any;

    /**
     * Whether this item matches the search query.
     *
     * Defaults to case-insensitive substring match on `title()`.
     */
    function matches(query:String):Bool;

    /** Whether this item should be shown as non-interactive (grayed-out, unclickable). */
    function disabled():Bool;

}

/**
 * The defaults of the Rust trait: implement `title` and `value`.
 */
abstract class SearchableListItemBase implements SearchableListItem {

    public abstract function title():String;

    public abstract function value():Any;

    public function displayTitle():Null<AnyElement> {
        return null;
    }

    public function render(window:Window, cx:App):IntoElement {
        return title();
    }

    public function matches(query:String):Bool {
        return SearchableListItems.containsIgnoreCase(title(), query);
    }

    public function disabled():Bool {
        return false;
    }

}
