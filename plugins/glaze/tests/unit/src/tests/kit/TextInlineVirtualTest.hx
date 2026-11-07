// Ported from gpui-kit 0.8.1: crates/base/src/text/inline_virtual_tests.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.MouseButton;
import glaze.Point;
import glaze.Render;
import glaze.Window;
import glaze.kit.base.Base;
import glaze.kit.base.TextSelectionLayer;
import glaze.kit.base.text.InlineElement;
import glaze.kit.base.text.MarkdownNode;
import glaze.kit.base.text.SelectionFormat;
import glaze.kit.base.text.TextView;
import glaze.kit.base.text.TextViewState;
import testing.VisualTestContext;

import glaze.Prelude.*;

private class VirtualInlineRoot extends Model implements Render {

    public final view:Entity<TextViewState>;
    public var preparedSize:Int;
    public var fontScale:Float = 1.;
    public var sourceFormat:Bool = false;

    public function new(view:Entity<TextViewState>, preparedSize:Int) {
        super();
        this.view = view;
        this.preparedSize = preparedSize;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final root = this;
        final plugin = new TextTestInlinePlugin("math").parseWith((node, _) -> switch node {
            case InlineMath(math): new MarkdownNode("math", null).text('${math.value}²');
            case _: null;
        }).renderWith((_, context, _, _) -> {
            final extent:Float = context.fontSize() * (root.preparedSize / 16.);
            final image = glaze.Image.fromBytes(glaze.ImageFormat.Svg,
                haxe.io.Bytes.ofString('<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40"><path d="M0 0L40 40" stroke="black"/></svg>'));
            return new InlineElement(img(image).w(px(extent)).h(px(extent))).withBaseline(extent * 0.75);
        });
        return div()
            .w(px(400.))
            .h(px(200.))
            .overflowHidden()
            .textSize(rems(fontScale))
            .child(new TextSelectionLayer())
            .child(TextView.create(view)
                .scrollable(true)
                .selectionFormat(sourceFormat ? SelectionFormat.Source : SelectionFormat.Plain)
                .plugin(new glaze.kit.base.text.TextView.MarkdownTextViewPlugin(plugin)));
    }

}

/**
 * Tests of inline objects in a virtualized (scrollable) text view: resource
 * growth and zoom remeasure blocks that are offscreen, and copy keeps the
 * logical text of covered blocks (Rust `text/inline_virtual_tests.rs`).
 */
@:access(glaze.kit.base.text)
class TextInlineVirtualTest extends KitTestCase {

    static inline final BLOCKS = 24;

    final contexts:Array<VisualTestContext> = [];

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        super.teardown();
    }

    static function document():String {
        return [for (i in 0...BLOCKS) '第${i}段 $$x$$ $$y$$ English'].join("\n\n");
    }

    static function settle(cx:VisualTestContext):Void {
        cx.runUntilParked();
        cx.update((window, _) -> {
            window.draw();
            return true;
        });
        cx.runUntilParked();
    }

    static function totalHeight(root:Entity<VirtualInlineRoot>, cx:VisualTestContext, test:TextInlineVirtualTest):Float {
        return cx.update((_, app) -> {
            final list = root.read(app).view.read(app).listState;
            test.assertEquals(BLOCKS, list.itemCount());
            return list.maxOffsetForScrollbar().y + list.viewportBounds().size.height;
        });
    }

    function open(preparedSize:Int):{root:Entity<VirtualInlineRoot>, cx:VisualTestContext} {
        app.update(cx -> Base.init(cx));
        final result = VisualTestContext.addWindowView(app, dispatcher,
            (_, cx) -> new VirtualInlineRoot(cx.newEntity(cx -> TextViewState.markdown(document(), cx)), preparedSize));
        contexts.push(result.cx);
        return {root: result.view, cx: result.cx};
    }

    function textBounds(root:Entity<VirtualInlineRoot>, cx:VisualTestContext) {
        return cx.update((_, app) -> root.read(app).view.read(app).selectionAdapter.textBounds());
    }

    function testInlineVirtualResourceGrowthRemeasuresAllBlocksAndPreservesCopy() {
        final opened = open(16);
        final root = opened.root;
        final cx = opened.cx;
        settle(cx);
        final before = totalHeight(root, cx, this);
        var bounds = textBounds(root, cx);
        final first = bounds[0];
        var last = bounds[bounds.length - 1];
        final start = new Point(first.left() + 0.1, first.top() + first.size.height / 2.);
        var end = new Point(last.right() - 0.1, last.top() + last.size.height / 2.);
        cx.simulateMouseDown(start, MouseButton.Left);
        settle(cx);
        cx.simulateMouseMove(end, MouseButton.Left);
        settle(cx);
        cx.update((_, app) -> {
            root.update(app, (root, cx) -> {
                root.view.read(cx).listState.scrollToEnd();
                cx.notify();
            });
            return true;
        });
        settle(cx);
        bounds = textBounds(root, cx);
        last = bounds[bounds.length - 1];
        end = new Point(last.right() - 0.1, last.top() + last.size.height / 2.);
        cx.simulateMouseMove(end, MouseButton.Left);
        settle(cx);
        cx.simulateMouseUp(end, MouseButton.Left);
        settle(cx);
        final copyBefore = cx.update((_, app) -> root.read(app).view.read(app).selectedTextIn([0, BLOCKS - 1]));
        assertTrue(copyBefore.indexOf("第12段 x² y² English") >= 0, "offscreen covered blocks must use their logical text");
        cx.update((_, app) -> {
            root.update(app, (root, cx) -> {
                root.preparedSize = 96;
                root.view.update(cx, (state, cx) -> state.invalidateInlineLayout(cx));
            });
            return true;
        });
        settle(cx);
        final after = totalHeight(root, cx, this);
        assertTrue(after > before * 2., 'before=$before, after=$after');
        assertEquals(copyBefore, cx.update((_, app) -> root.read(app).view.read(app).selectedTextIn([0, BLOCKS - 1])));
        cx.update((_, app) -> {
            root.update(app, (root, cx) -> {
                root.sourceFormat = true;
                cx.notify();
            });
            return true;
        });
        settle(cx);
        final source = cx.update((_, app) -> root.read(app).view.read(app).selectedTextIn([0, BLOCKS - 1]));
        assertTrue(source.indexOf("第12段 $x$ $y$ English") >= 0);
    }

    function testInlineVirtualFontAndRemZoomRemeasureOffscreenBlocks() {
        final opened = open(40);
        final root = opened.root;
        final cx = opened.cx;
        settle(cx);
        final normal = totalHeight(root, cx, this);
        var zoomed = normal;
        for (scale in [1.5, 2.]) {
            cx.update((_, app) -> {
                root.update(app, (root, cx) -> {
                    root.fontScale = scale;
                    cx.notify();
                });
                return true;
            });
            settle(cx);
            zoomed = totalHeight(root, cx, this);
            assertTrue(zoomed > normal * (scale * 0.85), 'scale=$scale, normal=$normal, zoomed=$zoomed');
        }
        cx.update((window, app) -> {
            window.setRemSize(window.remSize() * 1.5);
            window.refresh();
            app.notify(root.entityId());
            return true;
        });
        settle(cx);
        final remZoomed = totalHeight(root, cx, this);
        assertTrue(remZoomed > zoomed * 1.3, 'zoomed=$zoomed, remZoomed=$remZoomed');
    }

}
