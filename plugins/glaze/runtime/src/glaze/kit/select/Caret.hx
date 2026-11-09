// Ported from gpui-kit 0.8.1: crates/component/src/select.rs (Caret)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.select;

import glaze.App;
import glaze.Component;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Window;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Size;

/**
 * The chevron of a select trigger, sized for its trigger. The rest of
 * `select.rs` comes with the select component.
 */
class Caret extends Component {

    final size:Size;

    /**
     * Set the caret color.
     */
    @prop var textColor:Null<Hsla> = null;

    /**
     * Create a select caret sized for its trigger.
     */
    public function new(size:Size) {
        super();
        this.size = size;
    }

    public function render(window:Window, cx:App):IntoElement {
        final icon = Icon.component(IconName.ChevronDown).withSize(switch size {
            case XSmall: XSmall;
            case Small: Small;
            case _: Medium;
        });
        if (textColor != null) icon.textColor(textColor);
        return icon;
    }

}
