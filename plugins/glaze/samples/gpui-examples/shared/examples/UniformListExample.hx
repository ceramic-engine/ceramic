// Ported from gpui-pre 0.3.10: examples/uniform_list.rs (UniformListExample, run_example)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package examples;

import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.Window;

import gpui.Prelude.*;

class UniformListExample extends Model implements Render {

    public static inline var WIDTH:Float = 300.0;

    public static inline var HEIGHT:Float = 300.0;

    /**
     * Where `println!` goes (the console by default).
     */
    public static var println:(String) -> Void = line -> trace(line);

    public function new() {
        super();
    }

    public function render(_window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<UniformListExample> = cast cx;
        return div().sizeFull().bg(rgb(0xffffff)).child(
            uniformList(
                'entries',
                50,
                // `cx.processor(|_this, range, _window, _cx| ..)`: ranges are
                // `start, end` arguments in the port
                (start, end, _window, _cx) -> {
                    final items:Array<IntoElement> = [];
                    for (ix in start...end) {
                        final item = ix + 1;

                        items.push(
                            div()
                                .id(ix)
                                .px2()
                                .cursorPointer()
                                .onClick((_event, _window, _cx) -> {
                                    println('clicked Item $item');
                                })
                                .child('Item $item')
                        );
                    }
                    return items;
                }
            )
            .hFull()
        );
    }

    /**
     * The root view of `run_example`'s window.
     */
    public static function open(_window:Window, cx:App):Entity<UniformListExample> {
        return cx.newEntity(_ -> new UniformListExample());
    }

}
