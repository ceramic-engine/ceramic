// Ported from gpui-pre 0.3.10: examples/text_wrapper.rs (HelloWorld, run_example)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package examples;

import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.TextOverflow;
import gpui.Window;

import gpui.Prelude.*;

/**
 * The view of `text_wrapper.rs` (named `HelloWorld` there).
 */
class TextWrapper extends Model implements Render {

    public static inline var WIDTH:Float = 800.0;

    public static inline var HEIGHT:Float = 600.0;

    public function new() {
        super();
    }

    public function render(_window:Window, _cx:Context<Dynamic>):IntoElement {
        final text = "The longest word 你好世界这段是中文，こんにちはこの段落は日本語です in any of the major "
            + "English language dictionaries is pneumonoultramicroscopicsilicovolcanoconiosis, a word that "
            + "refers to a lung disease contracted from the inhalation of very fine silica particles, "
            + "a url https://github.com/zed-industries/zed/pull/35724?query=foo&bar=2, "
            + "specifically from a volcano; medically, it is the same as silicosis.";
        return div()
            .id('page')
            .sizeFull()
            .flex()
            .flexCol()
            .p2()
            .gap2()
            .bg(white())
            .child(
                div()
                    .flex()
                    .flexRow()
                    .flexShrink0()
                    .gap2()
                    .child(
                        div()
                            .flex()
                            .border1()
                            .borderColor(red())
                            .textEllipsis()
                            .child('longer text in flex 1')
                    )
                    .child(
                        div()
                            .flex()
                            .border1()
                            .borderColor(red())
                            .textEllipsis()
                            .child('short flex')
                    )
                    .child(
                        div()
                            .overflowHidden()
                            .border1()
                            .borderColor(red())
                            .textEllipsis()
                            .wFull()
                            .child('A short text in normal div')
                    )
            )
            .child(
                div()
                    .flexShrink0()
                    .textXl()
                    .truncate()
                    .border1()
                    .borderColor(blue())
                    .child('ELLIPSIS: ' + text)
            )
            .child(
                div()
                    .flexShrink0()
                    .textXl()
                    .overflowHidden()
                    .textEllipsis()
                    .lineClamp(2)
                    .border1()
                    .borderColor(blue())
                    .child('ELLIPSIS 2 lines: ' + text)
            )
            .child(
                div()
                    .flexShrink0()
                    .textXl()
                    .overflowHidden()
                    .textOverflow(TextOverflow.Truncate(''))
                    .border1()
                    .borderColor(green())
                    .child('TRUNCATE: ' + text)
            )
            .child(
                div()
                    .flexShrink0()
                    .textXl()
                    .overflowHidden()
                    .textOverflow(TextOverflow.Truncate(''))
                    .lineClamp(3)
                    .border1()
                    .borderColor(green())
                    .child('TRUNCATE 3 lines: ' + text)
            )
            .child(
                div()
                    .flexShrink0()
                    .textXl()
                    .whitespaceNowrap()
                    .overflowHidden()
                    .border1()
                    .borderColor(black())
                    .child('NOWRAP: ' + text)
            )
            .child(div().textXl().wFull().child(text));
    }

    /**
     * The root view of `run_example`'s window.
     */
    public static function open(_window:Window, cx:App):Entity<TextWrapper> {
        return cx.newEntity(_ -> new TextWrapper());
    }

}
