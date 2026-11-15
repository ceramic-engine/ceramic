// Ported from gpui-kit 0.8.1: crates/component/src/table/mod.rs (`init`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.table;

import glaze.App;
import glaze.AppContext;
import glaze.KeyBinding;
import glaze.kit.base.Actions.Cancel;
import glaze.kit.base.Actions.SelectDown;
import glaze.kit.base.Actions.SelectFirst;
import glaze.kit.base.Actions.SelectLast;
import glaze.kit.base.Actions.SelectNextColumn;
import glaze.kit.base.Actions.SelectPageDown;
import glaze.kit.base.Actions.SelectPageUp;
import glaze.kit.base.Actions.SelectPrevColumn;
import glaze.kit.base.Actions.SelectUp;

/**
 * The key bindings of `DataTable` (Rust `table::init`), in a module of their
 * own so that the kit registers them at startup without loading the table.
 */
class DataTableKeys {

    public static inline final CONTEXT:String = "DataTable";

    /** Rust `table::init` (`data_table::init`): binds the table keys. */
    public static function bindKeys(cx:AppContext):Void {
        (cx : App).bindKeys([
            new KeyBinding("escape", new Cancel(), CONTEXT),
            new KeyBinding("up", new SelectUp(), CONTEXT),
            new KeyBinding("down", new SelectDown(), CONTEXT),
            new KeyBinding("left", new SelectPrevColumn(), CONTEXT),
            new KeyBinding("right", new SelectNextColumn(), CONTEXT),
            new KeyBinding("home", new SelectFirst(), CONTEXT),
            new KeyBinding("end", new SelectLast(), CONTEXT),
            new KeyBinding("pageup", new SelectPageUp(), CONTEXT),
            new KeyBinding("pagedown", new SelectPageDown(), CONTEXT),
            new KeyBinding("tab", new SelectNextColumn(), CONTEXT),
            new KeyBinding("shift-tab", new SelectPrevColumn(), CONTEXT),
        ]);
    }

}
