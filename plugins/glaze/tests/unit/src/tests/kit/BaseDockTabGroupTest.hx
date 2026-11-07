// Ported from gpui-kit 0.8.1: crates/base/src/dock/tab_group.rs (tests)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.AnyElement;
import gpui.AnyView;
import gpui.App;
import gpui.Bounds;
import gpui.Context;
import gpui.Div;
import gpui.Entity;
import gpui.MouseButton;
import gpui.Point;
import gpui.Size;
import gpui.TestDispatcher;
import gpui.Window;
import gpui.base.Base;
import gpui.base.Geometry.Placement;
import gpui.base.dock.AnyDrag;
import gpui.base.dock.DragPanel;
import gpui.base.dock.DropIndicator;
import gpui.base.dock.DropPlaceholderBounds;
import gpui.base.dock.InsertTarget;
import gpui.base.dock.NodeId;
import gpui.base.dock.PanelId;
import gpui.base.dock.PanelView;
import gpui.base.dock.TabGroup;
import gpui.base.dock.TabGroupConstraints;
import gpui.base.dock.TabGroupContext;
import gpui.base.dock.TabGroupEvent;
import gpui.base.dock.TabGroupRendererBase;
import tests.kit.DockTestSupport;
import testing.TestCase;
import testing.VisualTestContext;

import gpui.Prelude.*;

/**
 * The `#[cfg(test)]` tests of gpui-base's `TabGroup` (`tab_group.rs`).
 */
@:access(gpui.base.dock.TabGroup)
@:access(gpui.base.dock.DropPlaceholderBounds)
class BaseDockTabGroupTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    final contexts:Array<VisualTestContext> = [];

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        app.update(cx -> Base.init(cx));
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        for (cx in contexts) cx.destroy();
        contexts.resize(0);
        ceramic.App.app.flushImmediate();
    }

    function buildGroup(log:DockLog, names:Array<String>) {
        final built = DockTestSupport.buildGroup(app, dispatcher, log, names);
        contexts.push(built.cx);
        return built;
    }

    /** The node `buildGroup` gives its group. */
    static function groupNode():NodeId {
        return NodeId.fromU64(1);
    }

    static function elsewhere():NodeId {
        return NodeId.fromU64(7);
    }

    static function contentBounds():Bounds {
        return new Bounds(new Point(0, 0), new Size(400, 300));
    }

    /**
     * Collect the group's outgoing intents as readable strings, so an
     * assertion reads as the sentence the event means.
     */
    function recordEvents(group:Entity<TabGroup>, cx:VisualTestContext):Array<String> {
        final events:Array<String> = [];
        cx.update((_, cx) -> cx.subscribe(group, TabGroupEvent, (_, event, _) -> events.push(describe(event))).detach());
        return events;
    }

    static function option(value:Null<Int>):String {
        return value == null ? 'None' : 'Some($value)';
    }

    static function describe(event:TabGroupEvent):String {
        return switch event {
            case Drop(panel, source, target):
                switch target {
                    case Tabs(node, ix, activate):
                        'drop panel ${panel.asU64()} from ${source.asU64()} into tabs ${node.asU64()} at ${option(ix)} activate=$activate';
                    case Split(node, placement, _):
                        'drop panel ${panel.asU64()} from ${source.asU64()} split ${node.asU64()} $placement';
                }
            case DragDrop(_, target):
                'item onto ${target.node().asU64()} at ' + (target.placement() == null ? 'None' : 'Some(${target.placement()})');
            case ClosePanel(panel): 'close ${panel.asU64()}';
            case ActiveChanged(ix): 'active $ix';
            case ZoomIn: 'zoom in';
            case ZoomOut: 'zoom out';
        }
    }

    function testAGroupAnnouncesItsFirstPanelActive() {
        final log = new DockLog();
        final built = buildGroup(log, ['a']);
        built.cx.runUntilParked();

        assertEquals('a true', log.drainActive().join(', '));
    }

    function testSelectingAnotherTabDeactivatesThenActivates() {
        final log = new DockLog();
        final built = buildGroup(log, ['a', 'b']);
        final cx = built.cx;
        cx.runUntilParked();
        log.drainActive();

        cx.update((window, cx) -> built.group.update(cx, (group, gcx) -> group.selectTab(1, window, gcx)));
        cx.runUntilParked();

        assertEquals('a false, b true', log.drainActive().join(', '));
    }

    function testTheContextSnapshotsTheGroupState() {
        final log = new DockLog();
        final built = buildGroup(log, ['a', 'b']);

        final seen = built.cx.update((_, cx) -> {
            final context = built.group.read(cx).context(cx);
            '${context.panels().length} ${context.activeIx()} ${context.isZoomed()}';
        });

        assertEquals('2 0 false', seen);
    }

    /**
     * A panel hidden while it holds the displayed slot is still the panel told
     * it is active; only what gets drawn falls back to a visible one.
     */
    function testAHiddenDisplayedPanelIsStillTheActiveOne() {
        final log = new DockLog();
        final built = buildGroup(log, ['a', 'b']);
        final cx = built.cx;
        cx.update((_, cx) -> built.panels[0].update(cx, (panel, pcx) -> panel.setVisible(false, pcx)));
        cx.runUntilParked();

        assertEquals('a true', log.drainActive().join(', '));
        assertEquals('b', cx.update((_, cx) -> built.group.read(cx).activePanel(cx).panelName(cx)), 'rendering falls back to the first visible panel');
    }

    /**
     * `onRemoved` is a departing panel's deactivation signal, so the group
     * must not also announce `false` to it.
     */
    function testAPanelDroppedFromTheGroupIsNeverToldItWentInactive() {
        final log = new DockLog();
        final built = buildGroup(log, ['a', 'b']);
        final cx = built.cx;
        cx.runUntilParked();
        log.drain();

        cx.update((window, cx) -> {
            final remaining:Array<PanelView> = [DockTestSupport.view(built.panels[1])];
            built.group.update(cx, (group, gcx) -> group.syncFromTree(remaining, 0, window, gcx));
        });
        cx.runUntilParked();

        assertEquals('b true', log.drainActive().join(', '));
    }

    function testSelectingATabThatIsNotThereChangesNothing() {
        final log = new DockLog();
        final built = buildGroup(log, ['a', 'b']);
        final cx = built.cx;
        cx.runUntilParked();
        log.drainActive();
        final events = recordEvents(built.group, cx);

        cx.update((window, cx) -> built.group.update(cx, (group, gcx) -> group.selectTab(5, window, gcx)));
        cx.runUntilParked();

        assertEquals(0, cx.update((_, cx) -> built.group.read(cx).activeIx()));
        assertEquals(0, events.length);
        assertEquals(0, log.drainActive().length);
    }

    function testALockedGroupCanBeNeitherDraggedNorDroppedInto() {
        final log = new DockLog();
        final built = buildGroup(log, ['a', 'b']);
        final cx = built.cx;

        cx.update((window, cx) -> built.group.update(cx, (group, gcx) -> group.setConstraints(TabGroupConstraints.inSplit(false), window, gcx)));
        final unlocked = cx.update((_, cx) -> {
            final context = built.group.read(cx).context(cx);
            '${context.isDraggable()} ${context.isDroppable()}';
        });
        cx.update((window, cx) -> built.group.update(cx, (group, gcx) -> group.setConstraints(TabGroupConstraints.inSplit(false).dockLocked(true), window, gcx)));
        final locked = cx.update((_, cx) -> {
            final context = built.group.read(cx).context(cx);
            '${context.isDraggable()} ${context.isDroppable()}';
        });

        assertEquals('true true', unlocked);
        assertEquals('false false', locked);
    }

    /**
     * Zooming is a lock of its own: a zoomed group fills the dock, so there is
     * nothing beside it to drop against.
     */
    function testAZoomedGroupTakesNoDrops() {
        final log = new DockLog();
        final built = buildGroup(log, ['a', 'b']);
        final cx = built.cx;

        cx.update((window, cx) -> built.group.update(cx, (group, gcx) -> {
            group.setConstraints(TabGroupConstraints.inSplit(false), window, gcx);
            group.setZoomed(true, window, gcx);
        }));

        assertFalse(cx.update((_, cx) -> built.group.read(cx).context(cx).isDroppable()));
    }

    /**
     * Dragging the last visible panel out of the only group would leave the
     * dock empty and undroppable, so it is refused.
     */
    function testTheOnlyGroupsLastVisiblePanelCannotBeDraggedOut() {
        final log = new DockLog();
        final built = buildGroup(log, ['a']);
        final cx = built.cx;

        cx.update((window, cx) -> built.group.update(cx, (group, gcx) -> group.setConstraints(TabGroupConstraints.inSplit(true), window, gcx)));
        final alone = cx.update((_, cx) -> built.group.read(cx).context(cx).isDraggable());
        cx.update((window, cx) -> built.group.update(cx, (group, gcx) -> group.setConstraints(TabGroupConstraints.inSplit(false), window, gcx)));
        final besideOthers = cx.update((_, cx) -> built.group.read(cx).context(cx).isDraggable());

        assertFalse(alone);
        assertTrue(besideOthers);
    }

    function testAPanelFromAnotherGroupLandsAsOneMove() {
        final log = new DockLog();
        final built = buildGroup(log, ['a']);
        final cx = built.cx;
        final events = recordEvents(built.group, cx);

        final drag = new DragPanel(PanelId.fromU64(99), elsewhere());
        cx.update((_, cx) -> built.group.update(cx, (group, gcx) -> group.onDrop(drag, null, true, gcx)));
        cx.runUntilParked();

        assertEquals('drop panel 99 from 7 into tabs 1 at None activate=true', events.join(' | '));
    }

    function testDroppingAPanelBackOntoItsOwnGroupIsIgnored() {
        final log = new DockLog();
        final built = buildGroup(log, ['a', 'b']);
        final cx = built.cx;
        final events = recordEvents(built.group, cx);

        final drag = new DragPanel(DockTestSupport.panelId(built.panels[0]), groupNode());
        cx.update((_, cx) -> built.group.update(cx, (group, gcx) -> group.onDrop(drag, null, true, gcx)));
        cx.runUntilParked();

        assertEquals(0, events.length);
    }

    function testAHoveringSplitTurnsADropIntoASplit() {
        final log = new DockLog();
        final built = buildGroup(log, ['a']);
        final cx = built.cx;
        final events = recordEvents(built.group, cx);

        final drag = new DragPanel(PanelId.fromU64(99), elsewhere());
        cx.update((_, cx) -> built.group.update(cx, (group, gcx) -> {
            group.syncDropPlaceholder(contentBounds(), Placement.Right, drag.dragSessionId(), DropPlaceholderBounds.forPlacement(contentBounds(), null), gcx);
            group.onDrop(drag, null, true, gcx);
        }));
        cx.runUntilParked();

        assertEquals('drop panel 99 from 7 split 1 Right', events.join(' | '));
    }

    /**
     * The tab bar reports the slot a drop landed on, and a slot always means
     * "into these tabs" however the content area had resolved the cursor.
     */
    function testATabSlotOverridesTheHoveringSplit() {
        final log = new DockLog();
        final built = buildGroup(log, ['a']);
        final cx = built.cx;
        final events = recordEvents(built.group, cx);

        final drag = new DragPanel(PanelId.fromU64(99), elsewhere());
        cx.update((_, cx) -> built.group.update(cx, (group, gcx) -> {
            group.syncDropPlaceholder(contentBounds(), Placement.Right, drag.dragSessionId(), DropPlaceholderBounds.forPlacement(contentBounds(), null), gcx);
            group.onDrop(drag, 0, true, gcx);
        }));
        cx.runUntilParked();

        assertEquals('drop panel 99 from 7 into tabs 1 at Some(0) activate=true', events.join(' | '));
    }

    /**
     * A lone panel splitting out of its own group would empty that group and
     * refill it, which is no move at all.
     */
    function testALonePanelCannotSplitOutOfItsOwnGroup() {
        final log = new DockLog();
        final built = buildGroup(log, ['a']);
        final cx = built.cx;
        final events = recordEvents(built.group, cx);

        final drag = new DragPanel(DockTestSupport.panelId(built.panels[0]), groupNode());
        cx.update((_, cx) -> built.group.update(cx, (group, gcx) -> {
            group.syncDropPlaceholder(contentBounds(), Placement.Right, drag.dragSessionId(), DropPlaceholderBounds.forPlacement(contentBounds(), null), gcx);
            group.onDrop(drag, null, true, gcx);
        }));
        cx.runUntilParked();

        assertEquals(0, events.length);
    }

    function testThePlaceholderReplaysOnlyWhenTheTargetMoves() {
        final log = new DockLog();
        final built = buildGroup(log, ['a']);
        final cx = built.cx;
        final bounds = contentBounds();
        final source = new DropPlaceholderBounds(new Point(10, 10), new Size(96, 30));

        final sync = (placement:Null<Placement>) -> cx.update((_, cx) -> built.group.update(cx, (group, gcx) -> {
            group.syncDropPlaceholder(bounds, placement, 42, source, gcx);
            group.dropIndicator;
        }));

        final first = sync(Placement.Left);
        final again = sync(Placement.Left);
        final moved = sync(Placement.Right);

        assertEquals(0, first.epoch());
        assertTrue(first.from().equals(source), 'the first run flies in from the drag');
        assertEquals(0, again.epoch(), 'an unchanged target keeps animating');
        assertTrue(again.from().equals(source));
        assertEquals(1, moved.epoch(), 'a moved target replays from where it was');
        assertTrue(moved.from().equals(first.to()));
        assertTrue(moved.to().equals(DropPlaceholderBounds.forPlacement(bounds, Placement.Right)));
    }

    /**
     * The indicator is hit state, not a latch: a drag cancelled while hovering
     * must not leave the placeholder painted.
     */
    function testTheIndicatorIsWithheldWhenNoDragIsInFlight() {
        final log = new DockLog();
        final built = buildGroup(log, ['a']);
        final cx = built.cx;

        final result = cx.update((_, cx) -> built.group.update(cx, (group, gcx) -> {
            group.syncDropPlaceholder(contentBounds(), Placement.Top, 42, DropPlaceholderBounds.forPlacement(contentBounds(), null), gcx);
            {stored: group.dropIndicator != null, published: group.context(gcx.app).dropIndicator() != null};
        }));

        assertTrue(result.stored);
        assertFalse(result.published);
    }

    function testAHostDragReportsTheGroupAndTheEdgeItResolved() {
        final log = new DockLog();
        final built = buildGroup(log, ['a']);
        final cx = built.cx;
        final events = recordEvents(built.group, cx);

        cx.update((_, cx) -> built.group.update(cx, (group, gcx) -> group.emitDragDrop(new AnyDrag(7), Placement.Bottom, gcx)));
        cx.runUntilParked();

        assertEquals('item onto 1 at Some(Bottom)', events.join(' | '));
    }

    function testClosingAsksTheContainerRatherThanEditingTheGroup() {
        final log = new DockLog();
        final built = buildGroup(log, ['a', 'b']);
        final cx = built.cx;
        final events = recordEvents(built.group, cx);
        final panel = DockTestSupport.panelId(built.panels[1]);

        cx.update((_, cx) -> built.group.update(cx, (group, gcx) -> {
            group.closePanel(panel, gcx);
            // A panel that is not a member is not this group's to close.
            group.closePanel(PanelId.fromU64(4242), gcx);
        }));
        cx.runUntilParked();

        assertEquals('close ${panel.asU64()}', events.join(' | '));
        assertEquals(2, cx.update((_, cx) -> built.group.read(cx).panels().length),
            'the group still holds both panels until the container edits the tree');
    }

    function testZoomingTogglesAndTellsTheDisplayedPanel() {
        final log = new DockLog();
        final built = buildGroup(log, ['a']);
        final cx = built.cx;
        final events = recordEvents(built.group, cx);

        cx.update((window, cx) -> built.group.update(cx, (group, gcx) -> group.toggleZoom(window, gcx)));
        cx.runUntilParked();
        cx.update((window, cx) -> built.group.update(cx, (group, gcx) -> group.toggleZoom(window, gcx)));
        cx.runUntilParked();

        assertEquals('zoom in | zoom out', events.join(' | '));
        assertFalse(cx.update((_, cx) -> built.group.read(cx).isZoomed()));
        assertEquals('a true, a false', log.drainZoomed().join(', '),
            'the old TabPanel sent this to itself, where the default no-op swallowed it');
    }

    /**
     * A real drag over a locked group must resolve nothing: base installs no
     * drop handling on one, so the placement is never computed.
     */
    function testADragOverALockedGroupResolvesNothing() {
        final skinned = buildSkinnedGroup(['a', 'b']);
        final cx = skinned.cx;
        cx.update((window, cx) -> skinned.group.update(cx, (group, gcx) -> group.setConstraints(TabGroupConstraints.inSplit(false).dockLocked(true), window, gcx)));
        cx.update((window, _) -> window.draw());

        dragFromTheTabIntoTheContent(cx);

        assertTrue(cx.update((_, cx) -> skinned.group.read(cx).dropIndicator == null),
            'a locked group installs no drag-move listener, so nothing resolved');
    }

    /**
     * A dock's last group is marked unclosable so the dock cannot be emptied
     * out from under itself.
     */
    function testAGroupTheContainerSealedShutRefusesToClose() {
        final log = new DockLog();
        final built = buildGroup(log, ['a', 'b']);
        final cx = built.cx;
        final events = recordEvents(built.group, cx);
        final panel = DockTestSupport.panelId(built.panels[0]);

        cx.update((window, cx) -> built.group.update(cx, (group, gcx) -> {
            group.setConstraints(TabGroupConstraints.inSplit(false).closable(false), window, gcx);
            group.closePanel(panel, gcx);
        }));
        cx.runUntilParked();

        assertFalse(cx.update((_, cx) -> built.group.read(cx).context(cx).isClosable()));
        assertEquals(0, events.length);
    }

    /**
     * The last visible panel of the only group has nowhere to go, so it is
     * not closable either. Placing a sibling beside the group makes the same
     * panel closable again.
     */
    function testTheOnlyGroupsLastPanelIsNotClosable() {
        final log = new DockLog();
        final built = buildGroup(log, ['a']);
        final cx = built.cx;

        cx.update((window, cx) -> built.group.update(cx, (group, gcx) -> group.setConstraints(TabGroupConstraints.inSplit(true), window, gcx)));
        final alone = cx.update((_, cx) -> built.group.read(cx).context(cx).isClosable());
        cx.update((window, cx) -> built.group.update(cx, (group, gcx) -> group.setConstraints(TabGroupConstraints.inSplit(false), window, gcx)));
        final besideASibling = cx.update((_, cx) -> built.group.read(cx).context(cx).isClosable());

        assertFalse(alone);
        assertTrue(besideASibling);
    }

    /**
     * Collapsing takes the displayed panel off screen, and the active-state
     * contract counts that as no panel being displayed.
     */
    function testCollapsingDeactivatesTheDisplayedPanelAndExpandingRestoresIt() {
        final log = new DockLog();
        final built = buildGroup(log, ['a', 'b']);
        final cx = built.cx;
        cx.runUntilParked();
        assertEquals('a true', log.drainActive().join(', '));

        cx.update((window, cx) -> built.group.update(cx, (group, gcx) -> group.setConstraints(TabGroupConstraints.inSplit(false).collapsed(true), window, gcx)));
        cx.runUntilParked();
        assertEquals('a false', log.drainActive().join(', '));

        cx.update((window, cx) -> built.group.update(cx, (group, gcx) -> group.setConstraints(TabGroupConstraints.inSplit(false), window, gcx)));
        cx.runUntilParked();
        assertEquals('a true', log.drainActive().join(', '));
    }

/// The renderer seam

    function buildSkinnedGroup(names:Array<String>):{group:Entity<TabGroup>, calls:Array<String>, cx:VisualTestContext} {
        final calls:Array<String> = [];
        final renderer = new RecordingRenderer(calls);
        final opened = VisualTestContext.addWindowView(app, dispatcher,
            (window, cx:Context<TabGroup>) -> new TabGroup(NodeId.fromU64(1), window, cx).withRenderer(renderer));
        contexts.push(opened.cx);
        final group = opened.view;
        final cx = opened.cx;
        final log = new DockLog();
        cx.update((window, cx) -> {
            final views:Array<PanelView> = [for (name in names) DockTestSupport.view(TestPanel.logging(name, log, cx))];
            group.update(cx, (group, gcx) -> {
                group.setConstraints(TabGroupConstraints.inSplit(false), window, gcx);
                group.syncFromTree(views, 0, window, gcx);
            });
        });
        cx.runUntilParked();
        calls.resize(0);
        return {group: group, calls: calls, cx: cx};
    }

    /**
     * Press on the skin's tab, start the drag, and move into the right-hand
     * third of `skinContent()`.
     */
    static function dragFromTheTabIntoTheContent(cx:VisualTestContext):Void {
        cx.simulateMouseDown(new Point(20, 10), MouseButton.Left);
        cx.simulateMouseMove(new Point(30, 14), MouseButton.Left);
        cx.simulateMouseMove(new Point(450, 200), MouseButton.Left);
    }

    /**
     * The composition contract every later renderer copies: which hooks base
     * calls, and in what order.
     */
    function testTheRendererComposesFrameThenTabBarThenContent() {
        final skinned = buildSkinnedGroup(['a']);

        skinned.cx.update((window, _) -> window.draw());

        assertEquals('frame, tab_bar, content_frame, active_panel', skinned.calls.join(', '),
            'the tab bar is a sibling of the content, not a child of it');
    }

    /**
     * With nothing to display base asks for the empty element instead of the
     * active panel, and never for both.
     */
    function testAnEmptyGroupAsksTheRendererForItsEmptyState() {
        final skinned = buildSkinnedGroup([]);

        skinned.cx.update((window, _) -> window.draw());

        assertEquals('frame, tab_bar, content_frame, empty', skinned.calls.join(', '));
    }

    /**
     * The drop listeners must sit on the content frame, not the outer frame:
     * a drag over the group resolves against the content frame's own bounds,
     * which the skin decides.
     */
    function testTheContentFrameIsWhatADragIsMeasuredAgainst() {
        final skinned = buildSkinnedGroup(['a', 'b']);
        final cx = skinned.cx;
        cx.update((window, _) -> window.draw());

        dragFromTheTabIntoTheContent(cx);

        final indicator:Null<DropIndicator> = cx.update((_, cx) -> skinned.group.read(cx).dropIndicator);
        assertNotNull(indicator, 'the content frame\'s drag-move listener ran');
        assertTrue(indicator.bounds().equals(RecordingRenderer.skinContent()), 'measured against the content frame, not the full-size outer frame');
        assertEquals(Placement.Right, indicator.placement());

        cx.update((window, _) -> window.draw());
        assertTrue(skinned.calls.contains('drop_indicator'), 'a published indicator is handed to the renderer to draw');
    }

    /**
     * A drop landing on the content frame reports a move the container can
     * apply, and clears the hover state behind it.
     */
    function testDroppingOnTheContentFrameReportsTheMove() {
        final skinned = buildSkinnedGroup(['a', 'b']);
        final cx = skinned.cx;
        final events = recordEvents(skinned.group, cx);
        cx.update((window, _) -> window.draw());

        dragFromTheTabIntoTheContent(cx);
        cx.simulateMouseUp(new Point(450, 200), MouseButton.Left);
        cx.runUntilParked();

        assertEquals(1, events.length, 'got ' + events.join(' | '));
        assertTrue(StringTools.endsWith(events[0], 'split 1 Right'), 'got ' + events.join(' | '));
        assertTrue(cx.update((_, cx) -> skinned.group.read(cx).dropIndicator == null));
    }

}

/**
 * A skin that records which hooks base calls, and lays its two frames out at
 * known coordinates so a test can tell them apart by hit geometry.
 */
private class RecordingRenderer extends TabGroupRendererBase {

    final calls:Array<String>;

    public function new(calls:Array<String>) {
        super();
        this.calls = calls;
    }

    /**
     * Where the content frame is. Deliberately not the window's own origin or
     * size, so a listener on the outer frame would report different bounds.
     */
    public static function skinContent():Bounds {
        return new Bounds(new Point(100, 50), new Size(400, 300));
    }

    override public function frame(group:TabGroupContext, window:Window, cx:App):Div {
        calls.push('frame');
        return div().id('skin-frame').relative().sizeFull();
    }

    override public function contentFrame(group:TabGroupContext, window:Window, cx:App):Div {
        calls.push('content_frame');
        final content = skinContent();
        return div()
            .id('skin-content')
            .absolute()
            .left(px(content.origin.x))
            .top(px(content.origin.y))
            .w(px(content.size.width))
            .h(px(content.size.height));
    }

    public function renderTabBar(group:TabGroupContext, window:Window, cx:App):AnyElement {
        calls.push('tab_bar');
        final tab = div().id('skin-tab').absolute().left(px(0)).top(px(0)).w(px(80)).h(px(24));
        final drag = group.dragPanel(0, cx);
        if (drag != null) {
            tab.onDrag(drag, (drag:DragPanel, offset, _, cx) -> {
                drag.setDragOffset(offset);
                return (cx.newEntity((_:Context<gpui.base.dock.DragPanelView>) -> new gpui.base.dock.DragPanelView(drag.clone())) : AnyView);
            });
        }
        return tab.intoAnyElement();
    }

    override public function renderActivePanel(panel:AnyView, group:TabGroupContext, window:Window, cx:App):AnyElement {
        calls.push('active_panel');
        return panel.intoAnyElement();
    }

    override public function renderEmpty(group:TabGroupContext, window:Window, cx:App):Null<AnyElement> {
        calls.push('empty');
        return null;
    }

    override public function renderDropIndicator(indicator:DropIndicator, window:Window, cx:App):Null<AnyElement> {
        calls.push('drop_indicator');
        return null;
    }

}
