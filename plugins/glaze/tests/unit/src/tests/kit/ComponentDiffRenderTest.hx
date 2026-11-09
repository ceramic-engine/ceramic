// Ported from gpui-kit 0.8.1: crates/component/src/diff/header_tests.rs, scroll_tests.rs
// and decoration_tests.rs (`gutter_markers_activate_without_selecting_lines`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.ElementId;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Point;
import glaze.Render;
import glaze.ScrollDelta;
import glaze.ScrollEvent;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.diff.Diff;
import glaze.kit.diff.DiffAnnotation;
import glaze.kit.diff.DiffDecoration;
import glaze.kit.diff.DiffFile;
import glaze.kit.diff.DiffGutterMarker;
import glaze.kit.diff.DiffLinePosition;
import glaze.kit.diff.DiffLineRange;
import glaze.kit.diff.DiffSide;
import glaze.kit.diff.DiffState;
import testing.TestCase;
import testing.VisualTestContext;
import tests.kit.ComponentDiffFixture as Fixture;

import glaze.Prelude.*;

/**
 * The tests of gpui-kit's diff that build or render the component.
 */
class ComponentDiffRenderTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.update(cx -> {
            // The tests run without system fonts: use the bundled monospace font.
            glaze.kit.theme.Theme.globalMut(cx).monoFontFamily = 'JetBrains Mono';
        });
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts)
            cx.destroy();
        contexts.resize(0);
        ceramic.App.app.flushImmediate();
    }

    static function draw(cx:VisualTestContext):Void {
        cx.runUntilParked();
        cx.update((window, _) -> {
            window.draw();
            return null;
        });
    }

    function newState(files:Array<DiffFile>):Entity<DiffState> {
        var state:Entity<DiffState> = null;
        app.update(cx -> state = cx.newEntity(cx -> new DiffState(files, cx)));
        return state;
    }

    // header_tests.rs

    function testDiffBuilder() {
        final document = Fixture.document(['before.rs', 'let value = 1;\n'], ['after.rs', 'let value = 2;\n']);
        final state = newState([document]);
        final defaults = Diff.component(state);
        assertEquals(state.entityId(), @:privateAccess defaults.state.entityId());
        assertTrue(@:privateAccess defaults.headerVisibleProp && @:privateAccess defaults.lineNumberProp);
        assertTrue(@:privateAccess defaults.syntaxHighlightProp);
        assertEquals(0, @:privateAccess defaults._annotations.items.length);
        assertNull(@:privateAccess defaults.header.content);
        assertNull(@:privateAccess defaults.renderAnnotationProp);

        final headerCalls:Array<String> = [];
        final position = new DiffLinePosition('after.rs', Modified, 1);
        final annotation = DiffAnnotation.line(ElementId.Name('review-comment'), position);
        final annotationCalls:Array<DiffLinePosition> = [];
        final diff = Diff.component(state)
            .headerVisible(false)
            .lineNumber(false)
            .syntaxHighlight(false)
            .annotations([annotation])
            .renderHeader((document, _, _) -> {
                headerCalls.push(document.originalPath() + ' ' + document.modifiedPath());
                return div().child('header');
            })
            .renderAnnotation((annotation, _, _) -> {
                assertTrue(Type.enumEq(ElementId.Name('review-comment'), annotation.id()));
                annotationCalls.push(annotation.position());
                return div().child('Review comment');
            });

        assertEquals(state.entityId(), @:privateAccess diff.state.entityId());
        assertTrue(!@:privateAccess diff.headerVisibleProp && !@:privateAccess diff.lineNumberProp);
        assertFalse(@:privateAccess diff.syntaxHighlightProp);
        final items = @:privateAccess diff._annotations.items;
        assertEquals(1, items.length);
        assertTrue(Type.enumEq(annotation.id(), items[0].id()));
        assertTrue(position.equals(items[0].position()));
        assertEquals('0', @:privateAccess diff._annotations.lines.get(position.key()).join(','));

        // Existing consumers keep the original builder spellings.
        final compatibility = Diff.component(state)
            .headerWith((_, _, _) -> div().child('header'))
            .headerPrefix((_, _, _) -> div().child('prefix'))
            .headerTitleSuffix((_, _, _) -> div().child('title suffix'))
            .headerSuffix((_, _, _) -> div().child('suffix'))
            .annotationContentWith((_, _, _) -> div().child('annotation'));
        assertNotNull(@:privateAccess compatibility.header.content);
        assertNotNull(@:privateAccess compatibility.header.prefix);
        assertNotNull(@:privateAccess compatibility.header.titleSuffix);
        assertNotNull(@:privateAccess compatibility.header.suffix);
        assertNotNull(@:privateAccess compatibility.renderAnnotationProp);

        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new Blank(), 640, 480);
        contexts.push(opened.cx);
        opened.cx.update((window, cx) -> {
            @:privateAccess diff.header.content(document, window, cx);
            @:privateAccess diff.renderAnnotationProp(items[0], window, cx);
            return null;
        });
        assertEquals('before.rs after.rs', headerCalls.join('|'));
        assertEquals(1, annotationCalls.length);
        assertTrue(position.equals(annotationCalls[0]));
    }

    // scroll_tests.rs

    /** Every line changed, so the unified patch is two rows per line. */
    static inline final LINES = 300;

    function longPatch():{state:Entity<DiffState>, cx:VisualTestContext} {
        final original = [for (ix in 0...LINES) 'old $ix\n'].join('');
        final modified = [for (ix in 0...LINES) 'new $ix\n'].join('');
        final state = newState([Fixture.modified('long.txt', original, modified)]);
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new ScrollHost(state), 640, 480);
        contexts.push(opened.cx);
        // The body records its size on the first paint and lays out again.
        for (_ in 0...3)
            draw(opened.cx);
        return {state: state, cx: opened.cx};
    }

    function testTheWholePatchKeepsItsHeightAfterTheFirstLayout() {
        final patch = longPatch();
        final list = @:privateAccess patch.state.read(app).list();
        final max = list.maxOffsetForScrollbar().y;
        final viewport = list.viewportBounds().size.height;
        // Rows past the viewport have not been rendered; without their hinted
        // height the patch would read as barely taller than one screen.
        assertTrue(max > viewport * 10., 'max offset $max for a $viewport viewport');
    }

    function testTheWheelScrollsPastTheRowsRenderedSoFar() {
        final patch = longPatch();
        for (_ in 0...50) {
            patch.cx.simulateEvent(new ScrollEvent(new Point(100., 120.), ScrollDelta.Pixels(new Point(0., -40.))));
            draw(patch.cx);
        }
        final top = @:privateAccess patch.state.read(app).list().logicalScrollTop().itemIx;
        // 2000 px of wheel travel crosses far more than the first screen of rows.
        assertTrue(top > 40, 'scrolled to row $top');
    }

    // decoration_tests.rs

    function testGutterMarkersActivateWithoutSelectingLines() {
        final state = newState([Fixture.modified('file.txt', 'one\ntwo\nthree\n', 'one\nTWO\nthree\n')]);
        final clicked:Array<DiffLinePosition> = [];
        final markers = new Map<String, Bounds>();
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _) -> new MarkerHost(state, clicked, markers), 640, 480);
        contexts.push(opened.cx);
        final cx = opened.cx;
        for (_ in 0...3)
            draw(cx);

        assertFalse(markers.exists('second'));
        final marker = markers.get('first');
        assertNotNull(marker, 'the first marker on the line is shown');
        if (marker == null)
            return;
        cx.simulateClick(marker.center());
        draw(cx);
        assertEquals(1, clicked.length);
        assertTrue(clicked.length == 1 && clicked[0].equals(new DiffLinePosition('file.txt', Modified, 2)));
        assertNull(state.read(app).selectedLines());
    }

}

private class Blank extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div();
    }

}

private class ScrollHost extends Model implements Render {

    final state:Entity<DiffState>;

    public function new(state:Entity<DiffState>) {
        super();
        this.state = state;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().w(px(400.)).h(px(200.)).child(Diff.component(state).sizeFull());
    }

}

private class MarkerHost extends Model implements Render {

    final state:Entity<DiffState>;

    final clicked:Array<DiffLinePosition>;

    final markers:Map<String, Bounds>;

    public function new(state:Entity<DiffState>, clicked:Array<DiffLinePosition>, markers:Map<String, Bounds>) {
        super();
        this.state = state;
        this.clicked = clicked;
        this.markers = markers;
    }

    static function position(side:DiffSide, line:Int):DiffLinePosition {
        return new DiffLinePosition('file.txt', side, line);
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final clicked = this.clicked;
        final markers = this.markers;
        return div().w(px(600.)).h(px(400.)).child(Diff.component(state)
            .sizeFull()
            .decorations([new DiffDecoration(new DiffLineRange('file.txt', Modified, 1, 3))])
            .gutterMarkers([
                new DiffGutterMarker(ElementId.Name('first'), position(Modified, 2)).withLabel('Open comment'),
                // A second marker on the same line is not shown.
                new DiffGutterMarker(ElementId.Name('second'), position(Modified, 2)),
            ])
            .renderGutterMarker((marker, _, _) -> {
                final target = marker.position();
                final name = switch (marker.id()) {
                    case Name(name): name;
                    default: Std.string(marker.id());
                }
                // Rust looks the marker up with `debug_selector`; the port
                // records its painted bounds instead.
                return div()
                    .id(marker.id())
                    .size3()
                    .child(canvas((bounds, _, _) -> {
                        markers.set(name, bounds);
                        return null;
                    }, (_, _, _, _) -> {}).absolute().sizeFull())
                    .onClick((_, _, _) -> clicked.push(target));
            }));
    }

}
