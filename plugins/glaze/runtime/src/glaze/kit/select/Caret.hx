// Ported from gpui-kit 0.8.1: crates/component/src/select.rs (Caret)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.select;

import gpui.App;
import gpui.Hsla;
import gpui.IntoElement;
import gpui.RenderOnce;
import gpui.Window;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.Size;

/**
 * The chevron of a select trigger, sized for its trigger. The rest of
 * `select.rs` comes with the select component.
 */
class Caret implements RenderOnce {

    final size:Size;

    var color:Null<Hsla> = null;

    /**
     * Create a select caret sized for its trigger.
     */
    public function new(size:Size) {
        this.size = size;
    }

    /**
     * Set the caret color.
     */
    public function textColor(color:Hsla):Caret {
        this.color = color;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final icon = new Icon(IconName.ChevronDown).withSize(switch size {
            case XSmall: XSmall;
            case Small: Small;
            case _: Medium;
        });
        if (color != null) icon.textColor(color);
        return icon;
    }

}
