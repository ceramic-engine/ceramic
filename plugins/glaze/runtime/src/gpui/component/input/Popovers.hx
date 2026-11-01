// Ported from gpui-kit 0.8.1: crates/component/src/input/popovers/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.input;

import gpui.App;
import gpui.Div;
import gpui.ElementIdArg;
import gpui.StyleBuilder;
import gpui.StyleRefinement;
import gpui.Window;
import gpui.component.text.TextView;
import gpui.component.text.TextViewStyle;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

using gpui.component.ThemeStyled;

/**
 * Helpers shared by the code editor's popovers (completion, code actions,
 * hover and diagnostics).
 */
class Popovers {

    /** The markdown of a hover, a diagnostic or a completion's documentation. */
    @:allow(gpui.component.input)
    static function renderMarkdown(id:ElementIdArg, markdown:String, _:Window, cx:App):TextView {
        final codeBlock = new StyleBuilder(new StyleRefinement())
            .bg(Theme.global(cx).transparent)
            .p0()
            .textSize(px(11.))
            .style();
        return TextView.markdown(id, markdown)
            .withStyle(TextViewStyle.defaultValue()
                .withParagraphGap(rems(0.5))
                .withHeadingFontSize((level, remSize) -> switch level {
                    case 1 | 2 | 3: remSize * 1;
                    case 4: remSize * 0.9;
                    case _: remSize * 0.8;
                })
                .withCodeBlock(codeBlock))
            .selectable(true);
    }

    /** The frame of an editor popover. */
    @:allow(gpui.component.input)
    static function editorPopover(id:ElementIdArg, cx:App):Div {
        return div()
            .id(id)
            .flexNone()
            .occlude()
            .popoverStyle(cx)
            .shadowMd()
            .textXs()
            .p1();
    }

}
