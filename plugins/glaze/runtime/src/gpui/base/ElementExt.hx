// Ported from gpui-kit 0.8.1: crates/base/src/element_ext.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.App;
import gpui.Bounds;
import gpui.ParentElement;
import gpui.Window;

import gpui.Prelude.*;

/**
 * Extends a GPUI parent element with post-layout prepaint observation, as a
 * static extension: `using gpui.base.ElementExt;`.
 *
 */
class ElementExt {

    /**
     * Invokes `callback` during prepaint with this element's resolved bounds.
     */
    public static function onPrepaint<T:ParentElement>(self:T, callback:(Bounds, Window, App) -> Void):T {
        self.extend([
            canvas((bounds, window, cx) -> {
                callback(bounds, window, cx);
                return null;
            }, (_, _, _, _) -> {})
                // Without an inset, an absolute child starts after the padding but
                // is still sized to the padding box, overhanging the far edges.
                .absolute()
                .top0()
                .left0()
                .sizeFull()
                .intoAnyElement()
        ]);
        return self;
    }

    /**
     * Runs this element inside the opaque text selection `scope`: text
     * selection participants it contains register in that scope.
     */
    public static function textSelectionScope<T:gpui.Element>(self:T, scope:TextSelectionScopeId):gpui.IntoElement {
        return TextSelection.textSelectionScope(scope, self);
    }

}
