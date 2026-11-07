// Ported from gpui-kit 0.8.1: crates/component/src/inspector.rs (StyleMethods)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.inspector;

import glaze.FunctionReflection;
import glaze.StyleRefinement;
import glaze.StyledReflection;
import glaze.kit.base.StyledExtReflection;

/**
 * One entry of the table: the style a method sets on a default refinement,
 * and the method.
 */
@:structInit
class StyleMethodEntry {

    public final style:StyleRefinement;

    public final method:FunctionReflection<StyleRefinement>;

}

/**
 * The style methods the inspector knows (Rust `StyleMethods`): gpui-base's
 * `StyledExt` methods, then gpui's `Styled` methods of the form
 * `fn name(self) -> Self`, built once.
 */
class InspectorStyleMethods {

    static var instance:Null<InspectorStyleMethods> = null;

    public final table:Array<StyleMethodEntry> = [];

    public final map:Map<String, FunctionReflection<StyleRefinement>> = new Map();

    /**
     * The names of `map` in a fixed order (the order of `table`). Rust
     * iterates its `HashMap` in no particular order.
     */
    public final names:Array<String> = [];

    function new() {
        for (methods in [StyledExtReflection.methods(), StyledReflection.methods()]) {
            for (method in methods) {
                table.push({style: method.invoke(new StyleRefinement()), method: method});
            }
        }
        for (entry in table) {
            if (!map.exists(entry.method.name)) {
                names.push(entry.method.name);
            }
            map.set(entry.method.name, entry.method);
        }
    }

    public static function get():InspectorStyleMethods {
        if (instance == null) instance = new InspectorStyleMethods();
        return instance;
    }

}
