// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/search.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * One search over an input: the query, how the built-in panel shows it, and
 * its matches. Read it through `InputBaseState.searchSession()`; it is
 * written only through the input state's search methods.
 */
class SearchSession {

    /** The built-in search panel is showing. */
    public var open:Bool = false;

    public var replaceMode:Bool = false;

    public var caseInsensitive:Bool = true;

    public var query:String = '';

    public var replacement:String = '';

    public var anchorOffset:Null<Int> = null;

    public var matcher:SearchMatcher = new SearchMatcher();

    /**
     * A search is in progress and its matches are highlighted: the panel is
     * open, or a query was set without it and not closed since.
     */
    var active:Bool = false;

    public function new() {}

    public static inline function defaultValue():SearchSession {
        return new SearchSession();
    }

    public function clone():SearchSession {
        final result = new SearchSession();
        result.open = open;
        result.active = active;
        result.replaceMode = replaceMode;
        result.caseInsensitive = caseInsensitive;
        result.query = query;
        result.replacement = replacement;
        result.anchorOffset = anchorOffset;
        result.matcher = matcher.clone();
        return result;
    }

    /** Rust `open(replace_mode, replaceable)` (renamed: the field has that name) */
    public function openPanel(replaceMode:Bool, replaceable:Bool):Void {
        open = true;
        active = true;
        this.replaceMode = replaceMode && replaceable;
    }

    /**
     * Start a search without the built-in panel. A custom search UI drives
     * the session through `InputBaseState.setSearchQuery`, and the
     * editor highlights the matches the same way it does for the panel.
     */
    public function activate():Void {
        active = true;
    }

    public function close():Void {
        open = false;
        active = false;
    }

    /**
     * Whether a search is in progress: the built-in panel is open, or a
     * query was set without it and `InputBaseState.closeSearch` has not
     * run since. Matches are highlighted while this holds.
     */
    public inline function isActive():Bool {
        return active;
    }

    public function updateQuery(query:String, caseInsensitive:Bool):Void {
        if (this.query == query && this.caseInsensitive == caseInsensitive)
            return;

        this.query = query;
        this.caseInsensitive = caseInsensitive;
        matcher.updateQuery(this.query, caseInsensitive);
    }

}
