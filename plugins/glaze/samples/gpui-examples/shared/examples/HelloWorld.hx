// Ported from gpui-pre 0.3.10: examples/hello_world.rs (HelloWorld, run_example)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package examples;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;

import glaze.Prelude.*;

class HelloWorld extends Model implements Render {

    public static inline var WIDTH:Float = 500.0;

    public static inline var HEIGHT:Float = 500.0;

    @observe public var text:String;

    public function new(text:String) {
        super();
        this.text = text;
    }

    public function render(_window:Window, _cx:Context<Dynamic>):IntoElement {
        return div()
            .flex()
            .flexCol()
            .gap3()
            .bg(rgb(0x505050))
            .size(px(500.0))
            .justifyCenter()
            .itemsCenter()
            .shadowLg()
            .border1()
            .borderColor(rgb(0x0000ff))
            .textXl()
            .textColor(rgb(0xffffff))
            .child('Hello, ${text}!')
            .child(
                div()
                    .flex()
                    .gap2()
                    .child(
                        div()
                            .size8()
                            .bg(red())
                            .border1()
                            .borderDashed()
                            .roundedMd()
                            .borderColor(white())
                    )
                    .child(
                        div()
                            .size8()
                            .bg(green())
                            .border1()
                            .borderDashed()
                            .roundedMd()
                            .borderColor(white())
                    )
                    .child(
                        div()
                            .size8()
                            .bg(blue())
                            .border1()
                            .borderDashed()
                            .roundedMd()
                            .borderColor(white())
                    )
                    .child(
                        div()
                            .size8()
                            .bg(yellow())
                            .border1()
                            .borderDashed()
                            .roundedMd()
                            .borderColor(white())
                    )
                    .child(
                        div()
                            .size8()
                            .bg(black())
                            .border1()
                            .borderDashed()
                            .roundedMd()
                            .roundedMd()
                            .borderColor(white())
                    )
                    .child(
                        div()
                            .size8()
                            .bg(white())
                            .border1()
                            .borderDashed()
                            .roundedMd()
                            .borderColor(black())
                    )
            );
    }

    /**
     * The root view of `run_example`'s window.
     */
    public static function open(_window:Window, cx:App):Entity<HelloWorld> {
        return cx.newEntity(_ -> new HelloWorld('World'));
    }

}
