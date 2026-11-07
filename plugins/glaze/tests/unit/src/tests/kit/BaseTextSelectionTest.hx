// Ported from gpui-kit 0.8.1: crates/base/src/text_selection.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.ContentMask;
import glaze.Context;
import glaze.Entity;
import glaze.Hitbox;
import glaze.HitboxBehavior;
import glaze.IntoElement;
import glaze.Model;
import glaze.Point;
import glaze.Range;
import glaze.Render;
import glaze.StyledText;
import glaze.TextLayout;
import glaze.Window;
import glaze.kit.base.SelectableText;
import glaze.kit.base.SelectableTextState;
import glaze.kit.base.TextSelection;
import glaze.kit.base.TextSelectionContentKey;
import glaze.kit.base.TextSelectionCoverage;
import glaze.kit.base.TextSelectionEndpoint;
import glaze.kit.base.TextSelectionEvent;
import glaze.kit.base.TextSelectionHandle;
import glaze.kit.base.TextSelectionLayer;
import glaze.kit.base.TextSelectionProjection;
import glaze.kit.base.TextSelectionRegistration;
import glaze.kit.base.TextSelectionRun;
import glaze.kit.base.TextSelectionScopeId;
import glaze.kit.base.TextSelectionSnapshot;
import glaze.kit.base.TextSelectionWindowPoints;
import glaze.kit.base.WindowSelectionState;
import glaze.util.Utf8;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.kit.base.ElementExt;

private class SelectionElementOnlyView extends Model implements Render {
    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .sizeFull()
            .child(new TextSelectionLayer())
            .child(div().sizeFull().onMouseDown(Left, (_, _, cx) -> glaze.kit.base.GlobalState.suppressTextSelection(cx)));
    }
}

private class PlainRunLayoutView extends Model implements Render {
    public final texts:Array<String>;
    public var layouts:Array<TextLayout> = [];

    public function new(texts:Array<String>) {
        super();
        this.texts = texts;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        layouts = [];
        final children:Array<IntoElement> = [];
        for (index in 0...texts.length) {
            final text = new StyledText(texts[index]);
            layouts.push(text.layout());
            children.push(div().absolute().top(px(index * 40.)).child(text));
        }
        return div().sizeFull().children(children);
    }
}

/** Rust `FakeParticipant`. */
private class FakeParticipant {
    public final selection:TextSelectionHandle;

    public function new(text:String, cx:App, ?selection:TextSelectionHandle) {
        this.selection = selection != null ? selection : TextSelectionHandle.create(text, cx);
    }

    public function register(selectionState:WindowSelectionState, y:Float, scope:TextSelectionScopeId, documentOrder:Int, cx:App):Void {
        final bounds = new Bounds(point(px(0.), px(y)), size(px(100.), px(10.)));
        selectionState.registerParticipant(selection, new TextSelectionRegistration(new Hitbox(-1, bounds, new ContentMask(bounds), HitboxBehavior.Normal), bounds)
            .withScope(scope)
            .withDocumentOrder(documentOrder)
            .withTextBounds([bounds]), cx);
    }
}

/**
 * Tests of the window text selection (Rust `text_selection.rs`).
 */
@:access(glaze.kit.base)
class BaseTextSelectionTest extends KitTestCase {

    final contexts:Array<VisualTestContext> = [];

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        super.teardown();
    }

    function addWindowView<V:Model & Render>(build:(Window, Context<V>) -> V):{view:Entity<V>, cx:VisualTestContext} {
        final result = VisualTestContext.addWindowView(app, dispatcher, build);
        contexts.push(result.cx);
        return result;
    }

    function laidOutRuns(texts:Array<String>):Array<{text:String, layout:TextLayout}> {
        final result = addWindowView((_, _) -> new PlainRunLayoutView(texts));
        result.cx.update((window, cx) -> {
            window.draw();
            return true;
        });
        final layouts = result.view.read(app).layouts;
        return [for (i in 0...texts.length) {text: texts[i], layout: layouts[i]}];
    }

    static function plainSnapshot(anchor:Point, cursor:Point):TextSelectionSnapshot {
        return TextSelectionSnapshot.create(new TextSelectionEndpoint(null, anchor), new TextSelectionEndpoint(null, cursor))
            .withWindowPoints(new TextSelectionWindowPoints(anchor, cursor));
    }

    static function textRun(order:Int, text:String, layout:TextLayout):TextSelectionRun {
        return new TextSelectionRun(text, layout, layout.bounds()).withDocumentOrder(order);
    }

    static function rangesToString(ranges:Array<Null<Range>>):String {
        return [for (range in ranges) range == null ? 'None' : '${range.start}..${range.end}'].join(',');
    }

    function testScopeStackIsCleanedAfterPanickingSubtree() {
        final result = addWindowView((_, _) -> new SelectionElementOnlyView());
        final windowId = result.cx.window.id;
        final scope = TextSelectionScopeId.fromRaw(41);
        app.update(cx -> {
            var failed = false;
            try {
                TextSelection.withTextSelectionScope(windowId, scope, cx, _ -> {
                    throw 'subtree failed';
                    return true;
                });
            }
            catch (e:Dynamic) {
                failed = true;
            }
            assertTrue(failed);
            assertEquals(null, TextSelection.currentTextSelectionScope(windowId, cx));
        });
    }

    function testReentrantScopeFromOneWindowDoesNotPolluteAnother() {
        final firstWindowId = addWindowView((_, _) -> new SelectionElementOnlyView()).cx.window.id;
        final secondWindowId = addWindowView((_, _) -> new SelectionElementOnlyView()).cx.window.id;
        final scope = TextSelectionScopeId.fromRaw(42);
        app.update(cx -> {
            TextSelection.withTextSelectionScope(firstWindowId, scope, cx, cx -> {
                assertEquals(null, TextSelection.currentTextSelectionScope(secondWindowId, cx));
                assertEquals(scope, TextSelection.currentTextSelectionScope(firstWindowId, cx));
                return true;
            });
        });
    }

    function testSelectionCallbackCanReenterItsSelectionState() {
        var called = false;
        var selectionState:Entity<WindowSelectionState> = null;
        var participant:FakeParticipant = null;
        app.update(cx -> {
            selectionState = cx.newEntity(_ -> new WindowSelectionState());
            final selectionStateForCallback = selectionState;
            participant = new FakeParticipant('participant', cx);
            participant.selection.subscribe((event, cx) -> {
                switch event {
                    case SelectionChanged(snapshot) if (snapshot != null):
                        selectionStateForCallback.update(cx, (_, _) -> called = true);
                    case _:
                }
            }, cx);
        });
        runUntilParked();
        app.update(cx -> {
            selectionState.update(cx, (selectionState, cx) -> {
                participant.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 0, cx.app);
                selectionState.begin(point(px(1.), px(1.)), false, cx.app);
                selectionState.updateGesture(point(px(20.), px(1.)), cx.app);
            });
        });
        runUntilParked();
        assertTrue(called);
    }

    function testSelectionEventsPreserveSnapshotThenClearOrder() {
        final observed:Array<Bool> = [];
        var selection:TextSelectionHandle = null;
        app.update(cx -> {
            selection = TextSelectionHandle.create('selection', cx);
            selection.subscribe((event, _) -> {
                switch event {
                    case SelectionChanged(snapshot): observed.push(snapshot != null);
                    case _:
                }
            }, cx);
        });
        runUntilParked();
        app.update(cx -> {
            selection.state.update(cx, (state, cx) -> {
                state.setSnapshot(plainSnapshot(point(px(1.), px(1.)), point(px(8.), px(1.))), cx);
                state.clearState(cx);
            });
        });
        runUntilParked();
        assertEquals('true,false', observed.join(','));
    }

    function testPublicSelectionDataUsesBuildersAndReaders() {
        final bounds = new Bounds(point(px(1.), px(2.)), size(px(30.), px(10.)));
        final hitbox = new Hitbox(-1, bounds, new ContentMask(bounds), HitboxBehavior.Normal);
        final scope = TextSelectionScopeId.fromRaw(7);
        final endpoint = new TextSelectionEndpoint(null, bounds.origin).withContentKey(new TextSelectionContentKey(11));
        final snapshot = TextSelectionSnapshot.create(endpoint, endpoint)
            .withSelecting(true)
            .withWindowPoints(new TextSelectionWindowPoints(bounds.origin, bounds.bottomRight()))
            .withCoverage(TextSelectionCoverage.Full);
        final registration = new TextSelectionRegistration(hitbox, bounds)
            .withScrollOffset(point(px(3.), px(4.)))
            .withScope(scope)
            .withDocumentOrder(9)
            .withTextBounds([bounds]);

        assertEquals(null, endpoint.entityId());
        assertTrue(endpoint.contentPoint().equals(bounds.origin));
        assertEquals(new TextSelectionContentKey(11), endpoint.contentKey());
        assertTrue(snapshot.anchor().equals(endpoint));
        assertTrue(snapshot.cursor().equals(endpoint));
        assertTrue(snapshot.isSelecting());
        assertEquals(TextSelectionCoverage.Full, snapshot.coverage());
        assertTrue(snapshot.windowPoints().equals(new TextSelectionWindowPoints(bounds.origin, bounds.bottomRight())));
        assertTrue(registration.bounds().equals(bounds));
        assertTrue(registration.scrollOffset().equals(point(px(3.), px(4.))));
        assertEquals(scope, registration.scope());
        assertEquals(9, registration.documentOrder());
        assertEquals(1, registration.textBounds().length);
        assertTrue(registration.textBounds()[0].equals(bounds));

        final run = laidOutRuns(["aé"]).pop();
        final textRun = new TextSelectionRun(run.text, run.layout, run.layout.bounds()).withDocumentOrder(3);
        assertEquals(3, textRun.documentOrder());
        assertEquals(run.text, textRun.text());
        assertEquals(run.layout.len(), textRun.layout().len());
        assertTrue(textRun.bounds().equals(run.layout.bounds()));

        final projection = new TextSelectionProjection([new Range(1, 3)], true);
        assertEquals('1..3', rangesToString(projection.ranges()));
        assertTrue(projection.isActive());
    }

    function testSelectionHandleIsThePublicAdapterSeam() {
        var selected = false;
        app.update(cx -> {
            final selection = TextSelectionHandle.create('initial', cx);
            final entityId = selection.entityId();
            selection.setFallbackCopyText('updated', cx);
            selection.setLocalSelection(true, cx);
            selection.subscribe((event, _) -> {
                switch event {
                    case SelectionChanged(snapshot): selected = snapshot != null;
                    case _:
                }
            }, cx);
            selection.focusWith((_, _) -> {}, cx);
            selection.copyWith(_ -> 'copied', cx);
            selection.resolveContentKeyWith((_, _) -> new TextSelectionContentKey(3), cx);

            assertEquals(entityId, selection.entityId());
            assertEquals(null, selection.snapshot(cx));
            assertTrue(selection.updateRuns([], cx).equals(new TextSelectionProjection([], false)));
        });
        assertFalse(selected);
    }

    function testPlainProjectionPreservesForwardReversedAndUnicodeRanges() {
        final run = laidOutRuns(["aé🙂z"]).pop();
        final textRun = textRun(0, run.text, run.layout);
        final start = run.layout.positionForIndex(1);
        final end = run.layout.positionForIndex(7);

        final forward = TextSelection.projectRanges(plainSnapshot(start, end), [textRun]);
        final reversed = TextSelection.projectRanges(plainSnapshot(end, start), [textRun]);

        assertEquals('1..7', rangesToString(forward.ranges()));
        assertEquals('1..7', rangesToString(reversed.ranges()));
        assertTrue(forward.isActive());
        assertTrue(reversed.isActive());
    }

    function testDoubleClickExpandsAPlainRunToTheInputWordBoundary() {
        final run = laidOutRuns(["one café, three"]).pop();
        final textRun = textRun(0, run.text, run.layout);
        final click = run.layout.positionForIndex(6);

        final carets = TextSelection.caretsForMultiClick([textRun], click, 2);
        final states = TextSelection.projectRanges(plainSnapshot(carets.start.origin, carets.end.origin), [textRun]);

        assertEquals('4..9', rangesToString(states.ranges()));
    }

    function testMultiClickUsesTextLayoutWindowCoordinatesAtANonzeroOrigin() {
        final runs = laidOutRuns(["above", "alpha beta"]);
        final run = runs.pop();
        assertTrue(run.layout.bounds().origin.y > 0.);
        final textRun = textRun(0, run.text, run.layout);
        final click = run.layout.positionForIndex(7);
        final carets = TextSelection.caretsForMultiClick([textRun], click, 2);
        final projection = TextSelection.projectRanges(plainSnapshot(carets.start.origin, carets.end.origin), [textRun]);
        assertEquals('6..10', rangesToString(projection.ranges()));
    }

    function testTripleClickExpandsToTheInputLogicalLineNotTheVisualRow() {
        final run = laidOutRuns(["second line"]).pop();
        final textRun = textRun(0, run.text, run.layout);
        final click = run.layout.positionForIndex(4);
        final carets = TextSelection.caretsForMultiClick([textRun], click, 4);
        final states = TextSelection.projectRanges(plainSnapshot(carets.start.origin, carets.end.origin), [textRun]);
        assertEquals('0..11', rangesToString(states.ranges()));
        final line = glaze.kit.base.input.TextBoundary.lineRangeAt("first line\nsecond line\nthird", 15);
        assertEquals('11..22', '${line.start}..${line.end}');
    }

    function testPlainProjectionSpansMultipleRunsAndLeavesEmptyGuttersUnselected() {
        final runs = laidOutRuns(["first", "", "second"]);
        final start = runs[0].layout.positionForIndex(2);
        final end = runs[2].layout.positionForIndex(3);
        final states = TextSelection.projectRanges(plainSnapshot(start, end), [
            textRun(2, runs[2].text, runs[2].layout),
            textRun(1, runs[1].text, runs[1].layout),
            textRun(0, runs[0].text, runs[0].layout),
        ]);
        assertEquals('0..3,None,2..5', rangesToString(states.ranges()));
        assertTrue(states.isActive());
    }

    function testPlainProjectionCachesMultipleParticipantCopiesInDocumentOrder() {
        final runs = laidOutRuns(["one", "two"]);
        final snapshot = plainSnapshot(runs[0].layout.positionForIndex(1), runs[1].layout.positionForIndex(2));
        app.update(cx -> {
            final selectionState = new WindowSelectionState();
            final first = new FakeParticipant("", cx);
            final second = new FakeParticipant("", cx);
            first.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 1, cx);
            second.register(selectionState, 20., TextSelectionScopeId.DEFAULT, 0, cx);

            first.selection.state.update(cx, (state, cx) -> state.setSnapshot(snapshot, cx));
            var projection = first.selection.updateRuns([textRun(0, runs[0].text, runs[0].layout)], cx);
            assertEquals('1..3', rangesToString(projection.ranges()));
            assertTrue(projection.isActive());
            second.selection.state.update(cx, (state, cx) -> state.setSnapshot(snapshot, cx));
            projection = second.selection.updateRuns([textRun(0, runs[1].text, runs[1].layout)], cx);
            assertEquals('0..2', rangesToString(projection.ranges()));
            assertTrue(projection.isActive());

            assertEquals("tw\nne", selectionState.selectedText(cx));
        });
    }

    function testPlainProjectionInvalidatesCachedCopyWhenTheSnapshotChanges() {
        final run = laidOutRuns(["first"]).pop();
        final firstSnapshot = plainSnapshot(run.layout.positionForIndex(1), run.layout.positionForIndex(3));
        final changedSnapshot = plainSnapshot(run.layout.positionForIndex(3), run.layout.positionForIndex(5));
        final textRun = textRun(0, run.text, run.layout);
        app.update(cx -> {
            final selectionState = new WindowSelectionState();
            final participant = new FakeParticipant("", cx);
            participant.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 0, cx);
            participant.selection.state.update(cx, (state, cx) -> {
                state.setSnapshot(firstSnapshot, cx);
                state.updateRuns([textRun]);
            });
            assertEquals("ir", selectionState.selectedText(cx));

            participant.selection.state.update(cx, (state, cx) -> state.setSnapshot(changedSnapshot, cx));
            assertEquals("", selectionState.selectedText(cx));

            participant.selection.updateRuns([textRun], cx);
            assertEquals("st", selectionState.selectedText(cx));
            selectionState.clear(cx);
            participant.selection.setLocalSelection(true, cx);
            assertEquals("", selectionState.selectedText(cx));
        });
    }

    function testPlainProjectionOrdersCachedRunsByFrameOrderNotInputOrder() {
        final runs = laidOutRuns(["one", "two"]);
        final snapshot = plainSnapshot(runs[0].layout.positionForIndex(1), runs[1].layout.positionForIndex(2));
        app.update(cx -> {
            final selectionState = new WindowSelectionState();
            final participant = new FakeParticipant("", cx);
            participant.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 0, cx);
            participant.selection.state.update(cx, (state, cx) -> {
                state.setSnapshot(snapshot, cx);
                state.updateRuns([textRun(1, runs[0].text, runs[0].layout), textRun(0, runs[1].text, runs[1].layout)]);
            });
            assertEquals("twne", selectionState.selectedText(cx));
        });
    }

    function testPlainProjectionSafelyRejectsATextLayoutLengthMismatch() {
        final run = laidOutRuns(["short"]).pop();
        final start = run.layout.positionForIndex(0);
        final end = run.layout.positionForIndex(5);
        final states = TextSelection.projectRanges(plainSnapshot(start, end), [textRun(0, "longer", run.layout)]);
        assertEquals('None', rangesToString(states.ranges()));
        assertTrue(states.isActive());
    }

    function testBeginUpdateAndEndPublishACrossParticipantSelection() {
        app.update(cx -> {
            final selectionState = new WindowSelectionState();
            final first = new FakeParticipant("first", cx);
            final second = new FakeParticipant("second", cx);
            first.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 0, cx);
            second.register(selectionState, 20., TextSelectionScopeId.DEFAULT, 1, cx);

            selectionState.begin(point(px(1.), px(1.)), false, cx);
            selectionState.updateGesture(point(px(1.), px(25.)), cx);
            assertTrue(selectionState.hasSelection(cx));
            assertEquals("first\nsecond", selectionState.selectedText(cx));

            selectionState.end(cx);
            assertFalse(selectionState.isSelectingNow());
        });
    }

    function testShiftExtensionKeepsItsOriginalAnchorWhenReversed() {
        app.update(cx -> {
            final selectionState = new WindowSelectionState();
            final participant = new FakeParticipant("participant", cx);
            participant.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 0, cx);

            selectionState.begin(point(px(2.), px(2.)), false, cx);
            selectionState.end(cx);
            selectionState.begin(point(px(8.), px(2.)), true, cx);
            selectionState.end(cx);
            final firstAnchor = selectionState.snapshot().anchor();

            selectionState.begin(point(px(0.), px(2.)), true, cx);
            selectionState.end(cx);
            final reversed = selectionState.snapshot();
            assertTrue(reversed.anchor().equals(firstAnchor));
            assertTrue(reversed.cursor().contentPoint().x < reversed.anchor().contentPoint().x);
        });
    }

    function testContentKeyResolverRunsOutsideTheWindowStateLease() {
        app.update(cx -> {
            final state = cx.newEntity(_ -> new WindowSelectionState());
            final participant = new FakeParticipant("virtual", cx);
            participant.selection.resolveContentKeyWith((_, cx) -> {
                state.read(cx).snapshot();
                return new TextSelectionContentKey(7);
            }, cx);
            state.update(cx, (state, cx) -> {
                participant.register(state, 0., TextSelectionScopeId.DEFAULT, 0, cx.app);
                state.begin(point(px(1.), px(1.)), false, cx.app);
                state.updateGesture(point(px(8.), px(1.)), cx.app);
            });

            WindowSelectionState.resolveContentKeys(state, cx);

            assertEquals(new TextSelectionContentKey(7), state.read(cx).snapshot().cursor().contentKey());
        });
    }

    function testActiveDndDoesNotMoveATextSelectionCursor() {
        final result = addWindowView((_, _) -> new SelectionElementOnlyView());
        result.cx.update((window, cx) -> {
            final state = new WindowSelectionState();
            final participant = new FakeParticipant("participant", cx);
            participant.register(state, 0., TextSelectionScopeId.DEFAULT, 0, cx);
            state.begin(point(px(1.), px(1.)), false, cx);
            final before = state.cursor.point;
            state.updateInWindowWithActiveDrag(point(px(80.), px(1.)), true, window, cx);
            assertTrue(state.cursor.point.equals(before));
            return true;
        });
    }

    function testShiftExtensionFallsBackWhenTheAnchorParticipantWasSwept() {
        app.update(cx -> {
            final selectionState = new WindowSelectionState();
            final first = new FakeParticipant("first", cx);
            final second = new FakeParticipant("second", cx);
            first.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 0, cx);
            selectionState.begin(point(px(1.), px(1.)), false, cx);
            selectionState.updateGesture(point(px(8.), px(1.)), cx);
            selectionState.end(cx);

            selectionState.finishFrame(cx);
            selectionState.finishFrame(cx);
            second.register(selectionState, 20., TextSelectionScopeId.DEFAULT, 1, cx);
            selectionState.begin(point(px(1.), px(21.)), true, cx);
            selectionState.updateGesture(point(px(8.), px(21.)), cx);
            selectionState.end(cx);

            assertEquals("second", selectionState.selectedText(cx));
        });
    }

    function testScopeAndSuppressionPreventUnrelatedParticipantsFromParticipating() {
        app.update(cx -> {
            final selectionState = new WindowSelectionState();
            final base = new FakeParticipant("base", cx);
            final modal = new FakeParticipant("modal", cx);
            base.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 0, cx);
            modal.register(selectionState, 20., TextSelectionScopeId.fromRaw(1), 1, cx);

            selectionState.setActiveScope(TextSelectionScopeId.fromRaw(1), cx);
            selectionState.begin(point(px(1.), px(21.)), false, cx);
            selectionState.updateGesture(point(px(8.), px(21.)), cx);
            selectionState.end(cx);
            assertEquals("modal", selectionState.selectedText(cx));

            selectionState.clear(cx);
            glaze.kit.base.GlobalState.init(cx);
            glaze.kit.base.GlobalState.suppressTextSelection(cx);
            selectionState.begin(point(px(1.), px(21.)), false, cx);
            selectionState.updateGesture(point(px(8.), px(21.)), cx);
            assertFalse(selectionState.hasSelection(cx));
        });
    }

    function testDeadParticipantsArePrunedAndEmptySelectionFallsBackSafely() {
        var selectionState:Entity<WindowSelectionState> = null;
        app.update(cx -> {
            selectionState = cx.newEntity(_ -> new WindowSelectionState());
            // The participant handle is dropped at the end of this update.
            final participant = new FakeParticipant("gone", cx);
            selectionState.update(cx, (state, cx) -> participant.register(state, 0., TextSelectionScopeId.DEFAULT, 0, cx.app));
            (participant.selection.state : SelectableTextState).destroy();
        });
        app.update(cx -> {
            selectionState.update(cx, (state, cx) -> {
                state.begin(point(px(1.), px(1.)), false, cx.app);
                state.updateGesture(point(px(8.), px(1.)), cx.app);
                state.end(cx.app);
                assertEquals("", state.selectedText(cx.app));
                assertFalse(state.hasSelection(cx.app));
            });
        });
    }

    function testTextSelectionNamespaceReportsCopiesEndsAndClearsSelection() {
        final result = addWindowView((_, _) -> new SelectionElementOnlyView());
        result.cx.update((window, cx) -> {
            final selection = TextSelectionHandle.create("copied", cx);
            final selectionState = WindowSelectionState.ensure(window, cx);
            selectionState.update(cx, (state, cx) -> {
                new FakeParticipant("", cx.app, selection).register(state, 0., TextSelectionScopeId.DEFAULT, 0, cx.app);
                state.begin(point(px(1.), px(1.)), false, cx.app);
                state.updateGesture(point(px(8.), px(1.)), cx.app);
            });

            assertTrue(TextSelection.hasSelection(window, cx));
            assertEquals("copied", TextSelection.selectedText(window, cx));
            TextSelection.end(window, cx);
            assertTrue(TextSelection.hasSelection(window, cx));
            TextSelection.clear(window, cx);
            assertFalse(TextSelection.hasSelection(window, cx));
            assertEquals("", TextSelection.selectedText(window, cx));
            return true;
        });
    }

    function testCopyCallbackCanReenterWindowAndHandleSelection() {
        final result = addWindowView((_, _) -> new SelectionElementOnlyView());
        result.cx.update((window, cx) -> {
            window.draw();
            final state = WindowSelectionState.existing(window, cx);
            final selection = TextSelectionHandle.create("fallback", cx);
            selection.copyWith(cx -> {
                state.update(cx, (state, _) -> assertTrue(state.snapshot() != null));
                assertTrue(selection.snapshot(cx) != null);
                selection.setFallbackCopyText("reentered", cx);
                return "reentrant copy";
            }, cx);
            state.update(cx, (state, cx) -> {
                new FakeParticipant("", cx.app, selection).register(state, 0., TextSelectionScopeId.DEFAULT, 0, cx.app);
                state.begin(point(px(1.), px(1.)), false, cx.app);
                state.updateGesture(point(px(8.), px(1.)), cx.app);
                state.end(cx.app);
            });

            assertEquals("reentrant copy", TextSelection.selectedText(window, cx));
            return true;
        });
    }

    function testCrossParticipantSelectionExcludesParticipantsOutsideItsDocumentInterval() {
        app.update(cx -> {
            final selectionState = new WindowSelectionState();
            final first = new FakeParticipant("first", cx);
            final second = new FakeParticipant("second", cx);
            final third = new FakeParticipant("third", cx);
            first.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 0, cx);
            second.register(selectionState, 20., TextSelectionScopeId.DEFAULT, 1, cx);
            third.register(selectionState, 40., TextSelectionScopeId.DEFAULT, 2, cx);

            selectionState.begin(point(px(1.), px(1.)), false, cx);
            selectionState.updateGesture(point(px(1.), px(25.)), cx);
            selectionState.end(cx);

            assertEquals("first\nsecond", selectionState.selectedText(cx));
            assertTrue(third.selection.snapshot(cx) == null);
        });
    }

    function testChangingScopeClearsThePreviousScopeSelection() {
        app.update(cx -> {
            final selectionState = new WindowSelectionState();
            final base = new FakeParticipant("base", cx);
            final modal = new FakeParticipant("modal", cx);
            base.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 0, cx);
            modal.register(selectionState, 20., TextSelectionScopeId.fromRaw(1), 1, cx);

            selectionState.begin(point(px(1.), px(1.)), false, cx);
            selectionState.updateGesture(point(px(8.), px(1.)), cx);
            selectionState.end(cx);
            selectionState.setActiveScope(TextSelectionScopeId.fromRaw(1), cx);

            assertFalse(selectionState.hasSelection(cx));
            assertTrue(base.selection.snapshot(cx) == null);
        });
    }

    function testBlankOnlyDragNeverPublishesOrCopiesSelection() {
        app.update(cx -> {
            final selectionState = new WindowSelectionState();
            final participant = new FakeParticipant("participant", cx);
            participant.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 0, cx);

            selectionState.begin(point(px(200.), px(1.)), false, cx);
            selectionState.updateGesture(point(px(200.), px(8.)), cx);
            selectionState.end(cx);

            assertFalse(selectionState.hasSelection(cx));
            assertEquals("", selectionState.selectedText(cx));
            assertTrue(participant.selection.snapshot(cx) == null);
        });
    }

    function testUnmountedSelectionDoesNotReviveWhenTheParticipantReturns() {
        app.update(cx -> {
            final selectionState = new WindowSelectionState();
            final participant = new FakeParticipant("stale", cx);
            participant.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 0, cx);
            selectionState.begin(point(px(1.), px(1.)), false, cx);
            selectionState.updateGesture(point(px(8.), px(1.)), cx);
            selectionState.end(cx);
            assertEquals("stale", selectionState.selectedText(cx));

            selectionState.finishFrame(cx);
            selectionState.finishFrame(cx);
            assertEquals("", selectionState.selectedText(cx));
            assertTrue(participant.selection.snapshot(cx) == null);
            participant.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 0, cx);
            assertEquals("", selectionState.selectedText(cx));
            assertTrue(participant.selection.snapshot(cx) == null);

            selectionState.begin(point(px(1.), px(1.)), false, cx);
            selectionState.updateGesture(point(px(8.), px(1.)), cx);
            selectionState.end(cx);
            assertEquals("stale", selectionState.selectedText(cx));
        });
    }

    function testRemovingAnUnselectedParticipantPreservesTheCurrentSelection() {
        app.update(cx -> {
            final selectionState = new WindowSelectionState();
            final selected = new FakeParticipant("selected", cx);
            final unrelated = new FakeParticipant("unrelated", cx);
            final scope = TextSelectionScopeId.DEFAULT;
            selected.register(selectionState, 0., scope, 0, cx);
            unrelated.register(selectionState, 20., scope, 1, cx);
            selectionState.begin(point(px(1.), px(1.)), false, cx);
            selectionState.updateGesture(point(px(8.), px(1.)), cx);
            selectionState.end(cx);
            assertEquals("selected", selectionState.selectedText(cx));

            selectionState.finishFrame(cx);
            selected.register(selectionState, 0., scope, 0, cx);
            selectionState.finishFrame(cx);
            assertEquals("selected", selectionState.selectedText(cx));
            unrelated.register(selectionState, 20., scope, 1, cx);
            assertEquals("selected", selectionState.selectedText(cx));
        });
    }

    function testRemovingEitherRangeEndpointDiscardsTheSharedSelection() {
        for (removeAnchor in [true, false]) {
            app.update(cx -> {
                final selectionState = new WindowSelectionState();
                final anchor = new FakeParticipant("anchor", cx);
                final cursor = new FakeParticipant("cursor", cx);
                final scope = TextSelectionScopeId.DEFAULT;
                anchor.register(selectionState, 0., scope, 0, cx);
                cursor.register(selectionState, 20., scope, 1, cx);
                selectionState.begin(point(px(1.), px(1.)), false, cx);
                selectionState.updateGesture(point(px(8.), px(21.)), cx);
                selectionState.end(cx);
                assertEquals("anchor\ncursor", selectionState.selectedText(cx));
                selectionState.finishFrame(cx);

                if (removeAnchor) {
                    cursor.register(selectionState, 20., scope, 1, cx);
                }
                else {
                    anchor.register(selectionState, 0., scope, 0, cx);
                }
                selectionState.finishFrame(cx);
                assertEquals("", selectionState.selectedText(cx));
                anchor.register(selectionState, 0., scope, 0, cx);
                cursor.register(selectionState, 20., scope, 1, cx);
                assertEquals("", selectionState.selectedText(cx));
            });
        }
    }

    function testClearOrUnmountStopsAutoScrollBeforeDiscardingTheAnchor() {
        for (unmount in [false, true]) {
            final commands:Array<Null<Float>> = [];
            var selectionState:WindowSelectionState = null;
            var participant:FakeParticipant = null;
            app.update(cx -> {
                selectionState = new WindowSelectionState();
                participant = new FakeParticipant("scroll", cx);
                participant.selection.subscribe((event, _) -> {
                    switch event {
                        case AutoScroll(delta): commands.push(delta);
                        case _:
                    }
                }, cx);
            });
            runUntilParked();
            app.update(cx -> {
                participant.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 0, cx);
                selectionState.begin(point(px(1.), px(1.)), false, cx);
                selectionState.updateGesture(point(px(1.), px(25.)), cx);
                if (unmount) {
                    selectionState.finishFrame(cx);
                    selectionState.finishFrame(cx);
                }
                else {
                    selectionState.clear(cx);
                }
            });
            runUntilParked();
            assertTrue(commands.filter(c -> c != null).length > 0, 'unmount: $unmount');
            assertEquals(null, commands[commands.length - 1]);
        }
    }

    function testDragAutoScrollStopsWhenTheContentMaskCollapses() {
        final result = addWindowView((_, _) -> new SelectionElementOnlyView());
        result.cx.update((window, cx) -> {
            final state = cx.newEntity(_ -> new WindowSelectionState());
            final participant = new FakeParticipant("participant", cx);
            state.update(cx, (state, cx) -> {
                participant.register(state, 0., TextSelectionScopeId.DEFAULT, 0, cx.app);
                state.begin(point(px(1.), px(1.)), false, cx.app);
            });
            // The scrollable ancestor got clipped away mid-drag, so the
            // refreshed registration carries a collapsed content mask.
            final collapsed = new Bounds(point(px(0.), px(0.)), size(px(100.), px(0.)));
            state.update(cx, (state, cx) -> {
                state.registerParticipant(participant.selection,
                    new TextSelectionRegistration(new Hitbox(-1, collapsed, new ContentMask(collapsed), HitboxBehavior.Normal), collapsed)
                        .withTextBounds([collapsed]), cx.app);
                state.updateInWindow(point(px(1.), px(50.)), window, cx);
                assertFalse(state.autoScroll.isActive());
                assertTrue(state.autoScroll.lastDragPosition == null);
            });
            return true;
        });
    }

    function testPointerMovesAfterAClickDoNotAutoScroll() {
        final result = addWindowView((_, _) -> new SelectionElementOnlyView());
        result.cx.update((window, cx) -> {
            final state = cx.newEntity(_ -> new WindowSelectionState());
            final participant = new FakeParticipant("participant", cx);
            state.update(cx, (state, cx) -> {
                participant.register(state, 0., TextSelectionScopeId.DEFAULT, 0, cx.app);
                // A click on text keeps its anchor so shift-click can extend it.
                state.begin(point(px(1.), px(1.)), false, cx.app);
                state.end(cx.app);
                assertTrue(state.anchor != null);

                state.updateInWindow(point(px(1.), px(50.)), window, cx);
                assertFalse(state.autoScroll.isActive());
            });
            return true;
        });
    }

    function testProxyEndpointsBreakEqualPositionTiesByDocumentOrder() {
        app.update(cx -> {
            final selectionState = new WindowSelectionState();
            final later = new FakeParticipant("later", cx);
            final earlier = new FakeParticipant("earlier", cx);
            later.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 2, cx);
            earlier.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 1, cx);

            selectionState.begin(point(px(1.), px(1.)), false, cx);
            selectionState.updateGesture(point(px(200.), px(25.)), cx);
            final endpoint = selectionState.snapshot().cursor();

            assertEquals(earlier.selection.entityId(), endpoint.entityId());
        });
    }

    function testEqualAreaHoveredParticipantsBreakTiesByDocumentOrder() {
        app.update(cx -> {
            for (_ in 0...64) {
                final selectionState = new WindowSelectionState();
                final later = new FakeParticipant("later", cx);
                final earliest = new FakeParticipant("earliest", cx);
                final middle = new FakeParticipant("middle", cx);
                later.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 30, cx);
                earliest.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 10, cx);
                middle.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 20, cx);

                selectionState.begin(point(px(1.), px(1.)), false, cx);
                selectionState.updateGesture(point(px(8.), px(1.)), cx);

                assertEquals(earliest.selection.entityId(), selectionState.snapshot().anchor().entityId());
            }
        });
    }

    function testTextSelectionNamespaceIsASafeNoOpUntilTheElementIsRendered() {
        final result = addWindowView((_, _) -> new EmptyView());
        result.cx.update((window, cx) -> {
            assertFalse(TextSelection.hasSelection(window, cx));
            assertEquals("", TextSelection.selectedText(window, cx));
            TextSelection.clear(window, cx);
            TextSelection.end(window, cx);
            assertFalse(TextSelection.hasSelection(window, cx));
            return true;
        });
    }

    function testUnitSelectionElementSupportsScopeAndRegistrationOnTheFirstFrame() {
        var selection:TextSelectionHandle = null;
        final result = addWindowView((_, cx) -> {
            selection = TextSelectionHandle.create("first frame", cx.app);
            return new FirstFrameScopedSelectionView(selection);
        });
        result.cx.update((window, cx) -> {
            window.draw();
            final state = WindowSelectionState.existing(window, cx);
            assertEquals(TextSelectionScopeId.fromRaw(23), state.read(cx).activeScope);
            assertTrue(state.read(cx).participants.exists(selection.entityId()));
            return true;
        });
    }

    function testLazyRegistrationDoesNotEnableQueriesWithoutTheElement() {
        final result = addWindowView((_, _) -> new EmptyView());
        result.cx.update((window, cx) -> {
            final selection = TextSelectionHandle.create("registered", cx);
            selection.setLocalSelection(true, cx);
            final bounds = new Bounds(point(px(0.), px(0.)), size(px(100.), px(20.)));
            selection.register(new TextSelectionRegistration(new Hitbox(-1, bounds, new ContentMask(bounds), HitboxBehavior.Normal), bounds).withTextBounds([bounds]), window, cx);
            assertEquals("", TextSelection.selectedText(window, cx));
            assertFalse(TextSelection.hasSelection(window, cx));
            TextSelection.clear(window, cx);
            assertEquals("", TextSelection.selectedText(window, cx));
            return true;
        });
    }


    // Retained text views

    function retainedRoot(texts:Array<String>):{view:Entity<RetainedSelectionRoot>, cx:VisualTestContext} {
        app.update(cx -> glaze.kit.base.Base.init(cx));
        return addWindowView((_, cx) -> new RetainedSelectionRoot([for (text in texts) RetainedSelectionText.create(text, cx.app)]));
    }

    static function drawSelectionFrame(cx:VisualTestContext):Void {
        cx.update((window, _) -> {
            window.draw();
            return true;
        });
        cx.runUntilParked();
    }

    /**
     * Dispatch the gesture and copy in the same update, before either paint or
     * the TextView's selection subscription can repair its copy cache.
     */
    function selectRetainedTexts(last:Int, release:Bool, cx:VisualTestContext):String {
        return cx.update((window, cx) -> {
            final state = WindowSelectionState.existing(window, cx);
            final bounds = [for (participant in state.read(cx).participants) participant.registration._textBounds[0]];
            bounds.sort((a, b) -> a.top() < b.top() ? -1 : (a.top() > b.top() ? 1 : 0));
            final start = point(bounds[0].left() + 0.1, bounds[0].center().y);
            final end = point(bounds[last].right() - 0.1, bounds[last].center().y);
            window.dispatchEvent(new glaze.MouseDownEvent(Left, start, glaze.Modifiers.none(), 1, false), cx);
            window.dispatchEvent(new glaze.MouseMoveEvent(end, Left, glaze.Modifiers.none()), cx);
            if (release) {
                window.dispatchEvent(new glaze.MouseUpEvent(Left, end, glaze.Modifiers.none(), 1), cx);
            }
            assertTrue(TextSelection.hasSelection(window, cx));
            return TextSelection.selectedText(window, cx);
        });
    }

    function testActiveSelectionFramePublicationVisitsParticipantsLinearly() {
        for (count in [4, 16]) {
            final result = retainedRoot([for (_ in 0...count) "text"]);
            final cx = result.cx;
            drawSelectionFrame(cx);
            drawSelectionFrame(cx);
            assertEquals("text", StringTools.trim(selectRetainedTexts(0, false, cx)));
            drawSelectionFrame(cx);
            drawSelectionFrame(cx);
            cx.update((window, cx) -> {
                final state = WindowSelectionState.existing(window, cx);
                state.read(cx).snapshotVisits = 0;
                window.refresh();
                window.draw();
                return true;
            });
            cx.runUntilParked();
            cx.update((window, cx) -> {
                final state = WindowSelectionState.existing(window, cx);
                final visits = state.read(cx).snapshotVisits;
                assertTrue(visits >= count, 'the frame must actually visit the participants');
                assertTrue(visits <= 3 * count, '$count participants required $visits snapshot visits');
                return true;
            });
        }
    }

    function testRetainedTextOrderSurvivesPartialFramesInsertionAndReordering() {
        final result = retainedRoot(["alpha", "bravo", "charlie"]);
        final cx = result.cx;
        drawSelectionFrame(cx);
        drawSelectionFrame(cx);
        function words(text:String):String {
            return [for (w in ~/\s+/g.split(StringTools.trim(text))) if (w.length > 0) w].join(',');
        }
        function selected():String return words(cx.update((window, cx) -> TextSelection.selectedText(window, cx)));
        assertEquals("alpha,bravo,charlie", words(selectRetainedTexts(2, true, cx)));
        final texts = result.view.read(app).texts.copy();
        for (_ in 0...3) {
            app.update(app -> texts[1].update(app, (_, cx) -> cx.notify()));
            drawSelectionFrame(cx);
            assertEquals("alpha,bravo,charlie", selected());
        }
        app.update(app -> result.view.update(app, (root, cx) -> {
            root.texts.insert(1, RetainedSelectionText.create("delta", cx.app));
            cx.notify();
        }));
        for (_ in 0...3) drawSelectionFrame(cx);
        assertEquals("alpha,delta,bravo,charlie", selected());
        app.update(app -> result.view.update(app, (root, cx) -> {
            final a = root.texts[1];
            root.texts[1] = root.texts[2];
            root.texts[2] = a;
            cx.notify();
        }));
        for (_ in 0...3) drawSelectionFrame(cx);
        assertEquals("alpha,bravo,delta,charlie", selected());
        // Keep the endpoint's entity alive after removing its element. A later
        // remount must not resurrect the retired window gesture.
        app.update(app -> result.view.update(app, (root, cx) -> {
            root.texts.pop();
            cx.notify();
        }));
        drawSelectionFrame(cx);
        drawSelectionFrame(cx);
        assertEquals("", selected());
        app.update(app -> result.view.update(app, (root, cx) -> {
            root.texts.push(texts[2]);
            cx.notify();
        }));
        drawSelectionFrame(cx);
        assertEquals("", selected());
    }

    function testRetainedSelectionStateReleasesAndDoesNotResurrectSelection() {
        var selection:TextSelectionHandle = null;
        final result = addWindowView((_, cx) -> {
            selection = TextSelectionHandle.create("local", cx.app);
            return new ToggleSelectionElementView(true, selection);
        });
        final cx = result.cx;
        cx.update((window, cx) -> {
            window.draw();
            selection.setLocalSelection(true, cx);
            assertTrue(TextSelection.hasSelection(window, cx));
            window.simulateNextFrame(cx);
            assertTrue(TextSelection.hasSelection(window, cx));
            window.draw();
            assertTrue(TextSelection.hasSelection(window, cx));
            return true;
        });
        app.update(app -> result.view.update(app, (view, cx) -> {
            view.enabled = false;
            cx.notify();
        }));
        cx.update((window, _) -> {
            window.draw();
            return true;
        });
        cx.update((window, cx) -> window.simulateNextFrame(cx));
        cx.update((window, cx) -> window.simulateNextFrame(cx));
        cx.runUntilParked();
        cx.update((window, cx) -> {
            assertFalse(TextSelection.hasSelection(window, cx));
            assertEquals("", TextSelection.selectedText(window, cx));
            assertFalse(selection.hasLocalSelection(cx));
            return true;
        });

        app.update(app -> result.view.update(app, (view, cx) -> {
            view.enabled = true;
            cx.notify();
        }));
        cx.update((window, cx) -> {
            window.draw();
            assertFalse(TextSelection.hasSelection(window, cx));
            assertEquals("", TextSelection.selectedText(window, cx));
            return true;
        });
    }

    function testMountedSelectionElementDoesNotKeepAnIdleFrameQueueAlive() {
        final result = addWindowView((_, _) -> new SelectionElementOnlyView());
        result.cx.update((window, cx) -> {
            window.draw();
            assertEquals(0, window.simulateNextFrame(cx));
            assertEquals(0, window.simulateNextFrame(cx));
            assertTrue(WindowSelectionState.existing(window, cx) != null);
            return true;
        });
    }

    function testSelectionElementInitializesSuppressionAndRespectsBubbleSuppression() {
        final result = addWindowView((_, _) -> new SelectionElementOnlyView());
        final cx = result.cx;
        cx.update((window, _) -> {
            window.draw();
            return true;
        });
        cx.simulateMouseDown(point(px(1.), px(1.)), Left);
        cx.simulateMouseUp(point(px(1.), px(1.)), Left);
        cx.update((window, cx) -> {
            assertTrue(glaze.kit.base.GlobalState.isTextSelectionSuppressed(cx));
            assertFalse(TextSelection.hasSelection(window, cx));
            return true;
        });
    }

    function testFrameSweepKeepsAParticipantRegisteredBeforeTheSelectionElementPaints() {
        app.update(cx -> {
            final selectionState = new WindowSelectionState();
            final participant = new FakeParticipant("painted first", cx);
            participant.register(selectionState, 0., TextSelectionScopeId.DEFAULT, 0, cx);
            selectionState.begin(point(px(1.), px(1.)), false, cx);
            selectionState.updateGesture(point(px(8.), px(1.)), cx);
            selectionState.end(cx);

            selectionState.finishFrame(cx);

            assertEquals("painted first", selectionState.selectedText(cx));
            assertTrue(participant.selection.snapshot(cx) != null);
        });
    }

    function testTwoSelectionElementsScheduleOnlyOnePostFrameSweep() {
        var selection:TextSelectionHandle = null;
        final result = addWindowView((_, cx) -> {
            selection = TextSelectionHandle.create("once", cx.app);
            return new DoubleSelectionElementView(selection);
        });
        result.cx.update((window, cx) -> {
            final selectionState = WindowSelectionState.ensure(window, cx);
            selectionState.update(cx, (state, cx) -> {
                new FakeParticipant("", cx.app, selection).register(state, 0., TextSelectionScopeId.DEFAULT, 0, cx.app);
                state.begin(point(px(1.), px(1.)), false, cx.app);
                state.updateGesture(point(px(8.), px(1.)), cx.app);
                state.end(cx.app);
            });

            window.draw();
            window.simulateNextFrame(cx);

            final items = selectionState.read(cx).copyItems(cx);
            assertEquals("once", TextSelection.resolveCopyItems(items, cx));
            return true;
        });
    }

    function testDuplicateSelectionElementsGateRealPointerGesturesAndReentrantClear() {
        var selection:TextSelectionHandle = null;
        final result = addWindowView((_, cx) -> {
            selection = TextSelectionHandle.create("once", cx.app);
            return new DoubleSelectionElementView(selection);
        });
        final cx = result.cx;
        var clearCount = 0;
        cx.update((window, cx) -> {
            final state = WindowSelectionState.ensure(window, cx);
            selection.subscribe((event, cx) -> {
                if (event.match(Cleared)) {
                    clearCount++;
                    state.read(cx).snapshot();
                }
            }, cx);
            window.draw();
            return true;
        });

        cx.simulateMouseDown(point(px(10.), px(10.)), Left);
        cx.simulateMouseUp(point(px(10.), px(10.)), Left);
        cx.simulateMouseDown(point(px(70.), px(10.)), Left, glaze.Modifiers.none().withShift(true));
        cx.simulateMouseUp(point(px(70.), px(10.)), Left);
        cx.update((window, cx) -> {
            assertTrue(TextSelection.hasSelection(window, cx));
            return true;
        });

        cx.simulateMouseDown(point(px(15.), px(10.)), Left);
        cx.simulateMouseMove(point(px(85.), px(10.)), Left);
        cx.simulateMouseUp(point(px(85.), px(10.)), Left);
        cx.update((window, cx) -> {
            assertTrue(TextSelection.hasSelection(window, cx));
            return true;
        });
        assertEquals(3, clearCount);
    }

    function testSelectionLayerHandlesRealDoubleAndTripleClickEvents() {
        final run = laidOutRuns(["alpha beta"]).pop();
        var selection:TextSelectionHandle = null;
        final result = addWindowView((_, cx) -> {
            selection = TextSelectionHandle.create("", cx.app);
            return new DoubleSelectionElementView(selection);
        });
        final cx = result.cx;
        cx.update((window, cx) -> {
            window.draw();
            selection.resolveContentKeyWith((_, _) -> new TextSelectionContentKey(17), cx);
            selection.updateRuns([textRun(0, run.text, run.layout)], cx);
            return true;
        });

        final position = run.layout.positionForIndex(7);
        cx.simulateEvent(new glaze.MouseDownEvent(Left, position, glaze.Modifiers.none(), 2, false));
        cx.simulateEvent(new glaze.MouseUpEvent(Left, position, glaze.Modifiers.none(), 2));
        cx.update((window, cx) -> {
            selection.updateRuns([textRun(0, run.text, run.layout)], cx);
            assertEquals("beta", TextSelection.selectedText(window, cx));
            final snapshot = selection.snapshot(cx);
            assertEquals(new TextSelectionContentKey(17), snapshot.anchor().contentKey());
            assertEquals(new TextSelectionContentKey(17), snapshot.cursor().contentKey());
            return true;
        });

        cx.simulateEvent(new glaze.MouseDownEvent(Left, position, glaze.Modifiers.none(), 3, false));
        cx.simulateEvent(new glaze.MouseUpEvent(Left, position, glaze.Modifiers.none(), 3));
        cx.update((window, cx) -> {
            selection.updateRuns([textRun(0, run.text, run.layout)], cx);
            assertEquals("alpha beta", TextSelection.selectedText(window, cx));
            return true;
        });
    }

    // SelectableText documents

    /** The middle of the character at `index` of `text`, as it was painted. */
    static function paintedPosition(text:String, index:Int, window:Window, cx:App):Point {
        final state = WindowSelectionState.existing(window, cx);
        for (registration in state.read(cx).participants) {
            final participant = registration.participant.upgrade();
            if (participant == null) continue;
            for (run in participant.read(cx).runs) {
                if (run._text != text) continue;
                final position = run._layout.positionForIndex(index);
                if (position == null) continue;
                return point(position.x + 1., position.y + run._layout.lineHeight() / 2.);
            }
        }
        throw 'no painted run of $text';
    }

    static function pressAt(text:String, index:Int, clickCount:Int, shift:Bool, cx:VisualTestContext):Point {
        final position = cx.update((window, cx) -> paintedPosition(text, index, window, cx));
        cx.simulateEvent(new glaze.MouseDownEvent(Left, position, glaze.Modifiers.none().withShift(shift), clickCount, false));
        return position;
    }

    static function dragTo(text:String, index:Int, cx:VisualTestContext):String {
        final position = cx.update((window, cx) -> paintedPosition(text, index, window, cx));
        cx.simulateEvent(new glaze.MouseMoveEvent(position, Left, glaze.Modifiers.none()));
        return paintedSelection(cx);
    }

    static function releaseAt(clickCount:Int, cx:VisualTestContext):Void {
        final position = cx.update((window, _) -> window.mousePosition());
        cx.simulateEvent(new glaze.MouseUpEvent(Left, position, glaze.Modifiers.none(), clickCount));
    }

    static function paintedSelection(cx:VisualTestContext):String {
        return cx.update((window, cx) -> {
            window.draw();
            return TextSelection.selectedText(window, cx);
        });
    }

    function selectableTexts(texts:Array<String>):VisualTestContext {
        app.update(cx -> glaze.kit.base.Base.init(cx));
        return addWindowView((_, _) -> new SelectableTextsView(texts)).cx;
    }

    function testDoubleClickDragExtendsTheSelectionByWords() {
        final cx = selectableTexts(["one two three", "four five six"]);
        paintedSelection(cx);

        pressAt("one two three", 5, 2, false, cx);
        assertEquals("two", paintedSelection(cx));
        assertEquals("two three", dragTo("one two three", 9, cx));
        // Backward, the whole of the word the drag started from stays.
        assertEquals("one two", dragTo("one two three", 1, cx));
        assertEquals("two three\nfour five", dragTo("four five six", 6, cx));
        releaseAt(2, cx);
        assertEquals("two three\nfour five", paintedSelection(cx));
    }

    function testTripleClickDragExtendsTheSelectionByLines() {
        final text = "first line\nsecond line\nthird line";
        final cx = selectableTexts([text]);
        paintedSelection(cx);

        pressAt(text, 13, 3, false, cx);
        assertEquals("second line", paintedSelection(cx));
        assertEquals("second line\nthird line", dragTo(text, 25, cx));
        assertEquals("first line\nsecond line", dragTo(text, 2, cx));
        releaseAt(3, cx);
        assertEquals("first line\nsecond line", paintedSelection(cx));
    }

    function testShiftClickAfterADoubleClickExtendsByWords() {
        final text = "one two three";
        final cx = selectableTexts([text]);
        paintedSelection(cx);

        pressAt(text, 5, 2, false, cx);
        releaseAt(2, cx);
        pressAt(text, 9, 1, true, cx);
        releaseAt(1, cx);
        assertEquals("two three", paintedSelection(cx));
        pressAt(text, 1, 1, true, cx);
        releaseAt(1, cx);
        assertEquals("one two", paintedSelection(cx));

        // A plain click ends the word selection: a drag from it is by characters.
        pressAt(text, 5, 1, false, cx);
        assertEquals("wo t", dragTo(text, 9, cx));
        releaseAt(1, cx);
    }

    // selectable_text.rs

    function testExplicitHandleConstructorPreservesDocumentContract() {
        app.update(cx -> {
            final handle = TextSelectionHandle.create("alpha beta", cx);
            SelectableText.withHandle("plain", handle, "alpha beta").documentOrder(42);
        });
        assertTrue(true);
    }

    function testLocalHandleParticipatesInWindowSelection() {
        final result = addWindowView((_, _) -> new SelectableTextTestView());
        final cx = result.cx;
        cx.update((window, _) -> {
            window.draw();
            return true;
        });
        cx.simulateMouseDown(point(px(1.), px(12.)), Left);
        cx.simulateMouseMove(point(px(220.), px(12.)), Left);
        cx.simulateMouseUp(point(px(220.), px(12.)), Left);
        cx.update((window, cx) -> {
            window.draw();
            assertEquals("alpha beta", TextSelection.selectedText(window, cx));
            return true;
        });
    }

    function testPaintDoesNotResolveWindowSelectedText() {
        var copies = 0;
        final handle = app.update(cx -> {
            final handle = TextSelectionHandle.create("gamma", cx);
            handle.copyWith(_ -> {
                copies++;
                return "gamma";
            }, cx);
            handle.setLocalSelection(true, cx);
            return handle;
        });
        final result = addWindowView((_, _) -> new CopyCallbackTestView(handle));
        result.cx.update((window, _) -> {
            window.draw();
            return true;
        });
        copies = 0;
        result.cx.update((window, _) -> {
            window.draw();
            return true;
        });
        assertEquals(0, copies);
    }

    function testWrappedSelectionPaintsFullWidthMiddleLines() {
        final bounds = new Bounds(point(px(10.), px(20.)), size(px(100.), px(100.)));
        final quads:Array<Bounds> = @:privateAccess SelectableText.selectionQuadBounds(point(px(40.), px(20.)), point(px(30.), px(80.)), bounds, 20.);
        final expected = [
            Bounds.fromCorners(point(px(40.), px(20.)), point(px(110.), px(40.))),
            Bounds.fromCorners(point(px(10.), px(40.)), point(px(110.), px(80.))),
            Bounds.fromCorners(point(px(10.), px(80.)), point(px(30.), px(100.))),
        ];
        assertEquals(expected.length, quads.length);
        for (i in 0...expected.length) assertTrue(quads[i].equals(expected[i]), quads[i].toString());
    }


    function testSelectionHandleCanSubscribeItsWindowToRefresh() {
        final result = addWindowView((_, _) -> new EmptyView());
        result.cx.update((window, cx) -> {
            final selection = TextSelectionHandle.create("refresh", cx);
            selection.refreshWindowOnChange(window, cx);
            return true;
        });
        assertTrue(true);
    }

    function testTwoWindowsIsolateSelectionCopyClearAndReleaseOwnership() {
        var firstSelection:TextSelectionHandle = null;
        var secondSelection:TextSelectionHandle = null;
        final first = addWindowView((_, cx) -> {
            firstSelection = TextSelectionHandle.create("first", cx.app);
            return new WindowOwnedSelectionView(firstSelection);
        });
        final second = addWindowView((_, cx) -> {
            secondSelection = TextSelectionHandle.create("second", cx.app);
            return new WindowOwnedSelectionView(secondSelection);
        });

        final firstState = first.cx.update((window, cx) -> {
            window.draw();
            firstSelection.setLocalSelection(true, cx);
            assertEquals("first", TextSelection.selectedText(window, cx));
            return WindowSelectionState.existing(window, cx).downgrade();
        });
        second.cx.update((window, cx) -> {
            window.draw();
            secondSelection.setLocalSelection(true, cx);
            assertEquals("second", TextSelection.selectedText(window, cx));
            return true;
        });

        first.cx.update((window, cx) -> {
            TextSelection.clear(window, cx);
            assertEquals("", TextSelection.selectedText(window, cx));
            return true;
        });
        second.cx.update((window, cx) -> {
            assertEquals("second", TextSelection.selectedText(window, cx));
            return true;
        });

        first.cx.update((window, _) -> {
            window.removeWindow();
            return true;
        });
        runUntilParked();

        assertTrue(firstState.upgrade() == null);
        second.cx.update((window, cx) -> {
            assertEquals("second", TextSelection.selectedText(window, cx));
            return true;
        });
        var registered = 0;
        for (_ in WindowSelectionState.globalOf(app, glaze.kit.base.WindowSelectionState.SelectionStateRegistry).map) registered++;
        assertEquals(1, registered);
    }

}

private class EmptyView extends Model implements Render {
    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div();
    }
}

private class FirstFrameScopedSelectionView extends Model implements Render {
    final selection:TextSelectionHandle;

    public function new(selection:TextSelectionHandle) {
        super();
        this.selection = selection;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final scope = TextSelectionScopeId.fromRaw(23);
        TextSelection.activateScope(scope, window, cx.app);
        final selection = this.selection;
        return div().child(new TextSelectionLayer()).child(
            glaze.kit.base.ElementExt.textSelectionScope(div().sizeFull().onPrepaint((bounds, window, cx) -> {
                final hitbox = window.insertHitbox(bounds, HitboxBehavior.Normal);
                selection.register(new TextSelectionRegistration(hitbox, bounds).withTextBounds([bounds]), window, cx);
            }), scope)
        );
    }
}

private class RetainedSelectionText extends Model implements Render {
    public final text:Entity<glaze.kit.base.text.TextViewState>;
    public var renders:Int = 0;
    public var scrollable:Bool = false;

    public function new(text:Entity<glaze.kit.base.text.TextViewState>) {
        super();
        this.text = text;
    }

    public static function create(text:String, cx:App):Entity<RetainedSelectionText> {
        final state = cx.newEntity(cx -> glaze.kit.base.text.TextViewState.markdown(text, cx));
        return cx.newEntity(_ -> new RetainedSelectionText(state));
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        renders++;
        return div().w(px(240.)).h(px(32.)).child(glaze.kit.base.text.TextView.create(text).scrollable(scrollable));
    }
}

private class RetainedSelectionRoot extends Model implements Render {
    public final texts:Array<Entity<RetainedSelectionText>>;

    public function new(texts:Array<Entity<RetainedSelectionText>>) {
        super();
        this.texts = texts;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().flex().flexCol().child(new TextSelectionLayer()).children([for (text in texts) (text : IntoElement)]);
    }
}

private class ToggleSelectionElementView extends Model implements Render {
    public var enabled:Bool;
    final selection:TextSelectionHandle;

    public function new(enabled:Bool, selection:TextSelectionHandle) {
        super();
        this.enabled = enabled;
        this.selection = selection;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final selection = this.selection;
        return div().when(enabled, el -> el.child(new TextSelectionLayer()).child(div().sizeFull().onPrepaint((bounds, window, cx) -> {
            final hitbox = window.insertHitbox(bounds, HitboxBehavior.Normal);
            selection.register(new TextSelectionRegistration(hitbox, bounds).withTextBounds([bounds]), window, cx);
        })));
    }
}

private class DoubleSelectionElementView extends Model implements Render {
    final selection:TextSelectionHandle;

    public function new(selection:TextSelectionHandle) {
        super();
        this.selection = selection;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final selection = this.selection;
        return div().sizeFull().child(new TextSelectionLayer()).child(new TextSelectionLayer()).onPrepaint((bounds, window, cx) -> {
            final hitbox = window.insertHitbox(bounds, HitboxBehavior.Normal);
            selection.register(new TextSelectionRegistration(hitbox, bounds).withTextBounds([bounds]), window, cx);
        });
    }
}

private class SelectableTextsView extends Model implements Render {
    final texts:Array<String>;

    public function new(texts:Array<String>) {
        super();
        this.texts = texts;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().child(new TextSelectionLayer()).child(
            div().w(px(400.)).children([for (ix in 0...texts.length) (SelectableText.create(glaze.ElementId.NamedInteger("text", ix), texts[ix]).documentOrder(ix) : IntoElement)])
        );
    }
}

private class SelectableTextTestView extends Model implements Render {
    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull().child(new TextSelectionLayer()).child(div().w(px(240.)).h(px(32.)).child(SelectableText.create("local", "alpha beta")));
    }
}

private class CopyCallbackTestView extends Model implements Render {
    final handle:TextSelectionHandle;

    public function new(handle:TextSelectionHandle) {
        super();
        this.handle = handle;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().sizeFull()
            .child(new TextSelectionLayer())
            .child(SelectableText.create("local", "alpha beta"))
            .child(SelectableText.withHandle("custom", handle, "gamma"));
    }
}

private class WindowOwnedSelectionView extends Model implements Render {
    final selection:TextSelectionHandle;

    public function new(selection:TextSelectionHandle) {
        super();
        this.selection = selection;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final selection = this.selection;
        return div().sizeFull().child(new TextSelectionLayer()).child(div().sizeFull().onPrepaint((bounds, window, cx) -> {
            final hitbox = window.insertHitbox(bounds, HitboxBehavior.Normal);
            selection.register(new TextSelectionRegistration(hitbox, bounds).withTextBounds([bounds]), window, cx);
        }));
    }
}
