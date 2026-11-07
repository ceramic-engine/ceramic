// Ported from gpui-pre 0.3.10: examples/drag_drop.rs (DragInfo, DragDrop, run_example)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package examples;

import gpui.App;
import gpui.Context;
import gpui.ElementId;
import gpui.Entity;
import gpui.Hsla;
import gpui.IntoElement;
import gpui.Model;
import gpui.Pixels;
import gpui.Point;
import gpui.Render;
import gpui.Window;

import gpui.Prelude.*;

/**
 * The dragged value, also the view rendering it while it is dragged. Rust
 * copies it (`Clone, Copy`): `position` returns a modified copy.
 */
class DragInfo extends Model implements Render {

    public final ix:Int;

    public final color:Hsla;

    public var position(default, null):Point;

    public function new(ix:Int, color:Hsla) {
        super();
        this.ix = ix;
        this.color = color;
        this.position = new Point(0, 0);
    }

    public function withPosition(pos:Point):DragInfo {
        final copy = new DragInfo(ix, color);
        copy.position = pos;
        return copy;
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        final size = gpui.Prelude.size(px(120.), px(50.));

        return div()
            .pl(px(position.x) - px(size.width).half())
            .pt(px(position.y) - px(size.height).half())
            .child(
                div()
                    .flex()
                    .justifyCenter()
                    .itemsCenter()
                    .w(px(size.width))
                    .h(px(size.height))
                    .bg(color.opacity(0.5))
                    .textColor(white())
                    .textXs()
                    .shadowMd()
                    .child('Item $ix')
            );
    }

}

class DragDrop extends Model implements Render {

    public static inline var WIDTH:Float = 800.0;

    public static inline var HEIGHT:Float = 600.0;

    @observe public var dropOn:Null<DragInfo>;

    public function new() {
        super();
        this.dropOn = null;
    }

    public function render(_window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<DragDrop> = cast cx;
        final items = [blue(), red(), green()];

        return div()
            .sizeFull()
            .flex()
            .flexCol()
            .gap5()
            .bg(white())
            .justifyCenter()
            .itemsCenter()
            .textColor(rgb(0x333333))
            .child(div().textXl().textCenter().child('Drop & Drop'))
            .child(
                div()
                    .wFull()
                    .mb10()
                    .justifyCenter()
                    .flex()
                    .flexRow()
                    .gap4()
                    .itemsCenter()
                    .children([for (ix => color in items) {
                        final dragInfo = new DragInfo(ix, color);
                        div()
                            .id(ElementId.NamedInteger('item', ix))
                            .size32()
                            .flex()
                            .justifyCenter()
                            .itemsCenter()
                            .border2()
                            .borderColor(color)
                            .textColor(color)
                            .cursorMove()
                            .hover(this_ -> this_.bg(color.opacity(0.2)))
                            .child('Item ($ix)')
                            .onDrag(dragInfo, (info:DragInfo, position:Point, _, cx:App) -> {
                                return cx.newEntity(_ -> info.withPosition(position));
                            });
                    }])
            )
            .child(
                div()
                    .id('drop-target')
                    .w128()
                    .h32()
                    .flex()
                    .justifyCenter()
                    .itemsCenter()
                    .border3()
                    .borderColor(dropOn != null ? dropOn.color : black())
                    .whenSome(dropOn, (this_, info) -> this_.bg(info.color.opacity(0.5)))
                    .onDrop(DragInfo, cx.listener((this_:DragDrop, info:DragInfo, _, _) -> {
                        this_.dropOn = info;
                    }))
                    .child('Drop items here')
            );
    }

    /**
     * The root view of `run_example`'s window.
     */
    public static function open(_window:Window, cx:App):Entity<DragDrop> {
        return cx.newEntity(_ -> new DragDrop());
    }

}
