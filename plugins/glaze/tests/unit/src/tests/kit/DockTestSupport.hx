// Ported from gpui-kit 0.8.1: crates/base/src/dock/test_support.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.TestDispatcher;
import gpui.WeakEntity;
import gpui.Window;
import gpui.base.dock.EntityPanelView;
import gpui.base.dock.NodeId;
import gpui.base.dock.PanelBase;
import gpui.base.dock.PanelId;
import gpui.base.dock.PanelView;
import gpui.base.dock.TabGroup;
import gpui.base.dock.TabGroupConstraints;
import testing.VisualTestContext;

/**
 * One thing a panel was told, in delivery order.
 *
 * `setActive` and the membership callbacks share one log because their
 * relative order is itself part of the contract under test: a panel joining a
 * group must see `Added` before it is told it is active. A moved panel must
 * never see `Removed`.
 */
enum PanelSignal {
    Active(active:Bool);
    Zoomed(zoomed:Bool);
    Added;
    Removed;
}

/**
 * Shared, cross-panel ordered log of everything the panels were told.
 */
class DockLog {

    public final entries:Array<{name:String, signal:PanelSignal}> = [];

    public function new() {}

    /**
     * Take everything logged so far, leaving the log empty, as `name signal`
     * strings (`a Active(true)`).
     */
    public function drain():Array<String> {
        final result = [for (entry in entries) entry.name + ' ' + Std.string(entry.signal)];
        entries.resize(0);
        return result;
    }

    /**
     * `drain`, keeping only the `setActive` edges, as `name true|false`.
     */
    public function drainActive():Array<String> {
        final result:Array<String> = [];
        for (entry in entries) {
            switch entry.signal {
                case Active(active): result.push(entry.name + ' ' + active);
                case _:
            }
        }
        entries.resize(0);
        return result;
    }

    /**
     * `drain`, keeping only the zoom signals, as `name true|false`.
     */
    public function drainZoomed():Array<String> {
        final result:Array<String> = [];
        for (entry in entries) {
            switch entry.signal {
                case Zoomed(zoomed): result.push(entry.name + ' ' + zoomed);
                case _:
            }
        }
        entries.resize(0);
        return result;
    }

}

class TestPanel extends PanelBase {

    public final name:String;

    final focus:FocusHandle;

    final log:DockLog;

    @observe public var visibleValue:Bool = true;

    @observe public var zoomableValue:Bool = true;

    public var group:Null<WeakEntity<TabGroup>> = null;

    public function new(name:String, log:DockLog, cx:Context<TestPanel>) {
        super();
        this.name = name;
        this.log = log;
        this.focus = cx.focusHandle();
    }

    /**
     * A panel whose deliveries go nowhere. For tests that only need a panel
     * to exist.
     */
    public static function create(name:String, cx:App):Entity<TestPanel> {
        return logging(name, new DockLog(), cx);
    }

    public static function logging(name:String, log:DockLog, cx:App):Entity<TestPanel> {
        return cx.newEntity((pcx:Context<TestPanel>) -> new TestPanel(name, log, pcx));
    }

    public function setVisible(visible:Bool, cx:Context<TestPanel>):Void {
        visibleValue = visible;
        cx.notify();
    }

    /**
     * A panel that refuses to zoom, which its group must honour.
     */
    public function setZoomable(zoomable:Bool, cx:Context<TestPanel>):Void {
        zoomableValue = zoomable;
        cx.notify();
    }

    function record(signal:PanelSignal):Void {
        log.entries.push({name: name, signal: signal});
    }

    /**
     * The panel's own name, so a dumped layout is legible in assertions.
     */
    public function panelName():String {
        return name;
    }

    override public function visible(cx:App):Bool {
        return visibleValue;
    }

    override public function zoomable(cx:App):Bool {
        return zoomableValue;
    }

    override public function setActive(active:Bool, window:Window, cx:Context<Dynamic>):Void {
        record(Active(active));
    }

    override public function setZoomed(zoomed:Bool, window:Window, cx:Context<Dynamic>):Void {
        record(Zoomed(zoomed));
    }

    override public function onAddedTo(group:WeakEntity<TabGroup>, window:Window, cx:Context<Dynamic>):Void {
        this.group = group;
        record(Added);
    }

    override public function onRemoved(window:Window, cx:Context<Dynamic>):Void {
        this.group = null;
        record(Removed);
    }

    public function focusHandle(cx:App):FocusHandle {
        return focus;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return new gpui.Empty();
    }

}

/**
 * The shared helpers of the dock tests (Rust `test_support.rs`).
 */
class DockTestSupport {

    public static function panelId(panel:Entity<TestPanel>):PanelId {
        return PanelId.fromEntityId(panel.entityId());
    }

    public static function view(panel:Entity<TestPanel>):PanelView {
        return new EntityPanelView(panel);
    }

    /**
     * Open a window holding one tab group over freshly built panels named
     * `names`, with the first tab displayed.
     */
    public static function buildGroup(app:App, dispatcher:TestDispatcher, log:DockLog,
            names:Array<String>):{group:Entity<TabGroup>, panels:Array<Entity<TestPanel>>, cx:VisualTestContext} {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (window, cx:Context<TabGroup>) -> @:privateAccess new TabGroup(NodeId.fromU64(1), window, cx));
        final group = opened.view;
        final cx = opened.cx;
        final panels = cx.update((window, cx) -> {
            final panels = [for (name in names) TestPanel.logging(name, log, cx)];
            final views:Array<PanelView> = [for (panel in panels) view(panel)];
            group.update(cx, (group, gcx) -> {
                // A freshly built group is sealed; place it beside siblings so
                // tests that do not care about constraints get a working group.
                @:privateAccess group.setConstraints(TabGroupConstraints.inSplit(false), window, gcx);
                @:privateAccess group.syncFromTree(views, 0, window, gcx);
            });
            panels;
        });
        return {group: group, panels: panels, cx: cx};
    }

}
