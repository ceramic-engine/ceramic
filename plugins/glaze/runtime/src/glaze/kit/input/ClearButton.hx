// Ported from gpui-kit 0.8.1: crates/component/src/input/clear_button.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.input;

import glaze.App;
import glaze.kit.I18n;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.button.Button.Button;

/**
 * The clear button of a cleanable input (Rust `clear_button`).
 */
class ClearButton {

    @:allow(glaze.kit)
    static function clearButton(cx:App):Button {
        return new Button("clean")
            .icon(new Icon(IconName.Close))
            // Icon-only: screen readers have nothing else to announce.
            .accessibilityLabel(I18n.t("Input.Clear"))
            .text()
            .xsmall()
            .tabStop(false);
    }

}
