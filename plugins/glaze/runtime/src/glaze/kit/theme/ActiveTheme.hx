// Ported from gpui-kit 0.8.1: crates/component/src/theme/mod.rs (ActiveTheme)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.theme;

import glaze.AppContext;
import glaze.EntitySlot;

/**
 * `cx.theme()` on an `App` or a `Context<T>`, as a static extension:
 * `using glaze.kit.theme.ActiveTheme;`.
 *
 * Read during render, it subscribes the view to the global theme: the view
 * re-renders when `Theme.update` or `Theme.change` installs a new theme.
 */
class ActiveTheme {

    public static inline function theme(cx:AppContext):Theme {

        return Theme.global(cx);

    }

}

/**
 * `cx.theme()` on a `Context<T>` (Haxe static extensions do not follow the
 * implicit cast of `AppContext`).
 */
class ActiveThemeContext {

    public static inline function theme(cx:EntitySlot):Theme {

        return Theme.global(cx);

    }

}
