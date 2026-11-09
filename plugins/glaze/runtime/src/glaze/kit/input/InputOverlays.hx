// Ported from gpui-kit 0.8.1: crates/component/src/input/overlay.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.input;

import glaze.AnyElement;
import glaze.App;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Range;
import glaze.WeakEntity;
import glaze.Window;
import glaze.kit.base.input.InputBaseState;
import ropey.Rope;

using glaze.kit.base.input.InputSearchExt;

/**
 * The overlays an input renders around its text: the search panel (placed
 * above a multi-line input) and the floating ones (the touch selection).
 * gpui-kit's code editor popovers (completion, code actions, hover,
 * diagnostics) are not part of Glaze: its code editor is Cityscape.
 */
class InputOverlays {

    public var search:Null<AnyElement> = null;

    public final floating:Array<AnyElement> = [];

    public function new() {}

    @:allow(tests)
    function len():Int {
        return (search != null ? 1 : 0) + floating.length;
    }

    @:allow(tests)
    function isEmpty():Bool {
        return search == null && floating.length == 0;
    }

    /**
     * Rust `!cfg!(test)`: the search panel moves the focus when the host shows
     * or hides it, except in gpui-kit's own unit tests of this module.
     */
    @:allow(glaze.kit.input, tests)
    static var focusOnSync:Bool = true;

    /**
     * Builds and syncs the overlays of `state` (Rust `render_overlays`).
     */
    @:allow(glaze.kit.input, tests)
    static function renderOverlays(state:Entity<InputBaseState>, window:Window, cx:App):InputOverlays {
        final hasOverlay = state.read(cx).searchSession.open;
        if (!hasOverlay) {
            final registry = InputOverlayRegistry.get(cx);
            if (registry != null) {
                registry.hosts.remove(state.entityId());
                registry.retainLiving();
            }
            return new InputOverlays();
        }

        final registry = InputOverlayRegistry.getOrCreate(cx);

        final id = state.entityId();
        final entry = registry.hosts.get(id);
        registry.hosts.remove(id);
        final host = entry != null ? entry.host : new InputOverlayHost(state, window, cx);
        final overlays = host.sync(state, window, cx);
        registry.hosts.set(id, new RegistryEntry(state.downgrade(), host));
        return overlays;
    }

}

/**
 * Rust `InputOverlayRegistry<M>`: the overlay hosts of the inputs that have
 * an overlay, by entity id. The port keeps one registry for every kind of
 * input (each state has its own entity id).
 */
@:allow(glaze.kit.input, tests)
class InputOverlayRegistry {

    final hosts:Map<Int, RegistryEntry> = new Map();

    public function new() {}

    /**
     * The registry of the app, if any. Read untracked: it is bookkeeping of
     * the inputs that render, not something a render depends on (in GPUI a
     * render never subscribes to a global it reads). Reading it tracked in
     * render, then mutating it, would invalidate every rendering input and
     * re-render them forever.
     */
    static function get(cx:App):Null<InputOverlayRegistry> {
        tracker.Autorun.unobserve();
        final registry = cx.tryGlobal(InputOverlayRegistry);
        tracker.Autorun.reobserve();
        return registry;
    }

    /** `get`, creating the registry on first use (Rust `set_global`). */
    static function getOrCreate(cx:App):InputOverlayRegistry {
        var registry = get(cx);
        if (registry == null) {
            registry = new InputOverlayRegistry();
            tracker.Autorun.unobserve();
            cx.setGlobal(registry, InputOverlayRegistry);
            tracker.Autorun.reobserve();
        }
        return registry;
    }

    /** Rust `retain(|_, (owner, _)| owner.upgrade().is_some())`. */
    function retainLiving():Void {
        final dead:Array<Int> = [];
        for (id => entry in hosts) {
            if (entry.owner.upgrade() == null)
                dead.push(id);
        }
        for (id in dead)
            hosts.remove(id);
    }

    /** Rust `hosts.contains_key` (tests). */
    function containsKey(id:Int):Bool {
        return hosts.exists(id);
    }

}

@:allow(glaze.kit.input, tests)
private class RegistryEntry {

    final owner:WeakEntity<InputBaseState>;

    final host:InputOverlayHost;

    public function new(owner:WeakEntity<InputBaseState>, host:InputOverlayHost) {
        this.owner = owner;
        this.host = host;
    }

}

/**
 * Identifies one version of the search session, as the search panel shows it.
 *
 * Everything the panel renders from is here, so an unchanged frame compares
 * equal and rebuilds nothing. `activationRevision` is what separates "the
 * session is open" from "the user just asked for search again": re-invoking an
 * open session leaves every other field alone, and without the revision the
 * second request would compare equal and be dropped.
 */
@:allow(glaze.kit.input, tests)
class SearchSignature {

    final open:Bool;

    final replaceMode:Bool;

    final query:String;

    final anchorOffset:Null<Int>;

    final activationRevision:Int;

    public function new(open:Bool = false, replaceMode:Bool = false, query:String = '', ?anchorOffset:Int, activationRevision:Int = 0) {
        this.open = open;
        this.replaceMode = replaceMode;
        this.query = query;
        this.anchorOffset = anchorOffset;
        this.activationRevision = activationRevision;
    }

    public function equals(other:SearchSignature):Bool {
        return open == other.open
            && replaceMode == other.replaceMode
            && query == other.query
            && anchorOffset == other.anchorOffset
            && activationRevision == other.activationRevision;
    }

}

@:allow(glaze.kit.input, tests)
class InputOverlayHost {

    final search:Entity<SearchPanel>;

    var searchSignature:SearchSignature = new SearchSignature();

    public function new(state:Entity<InputBaseState>, window:Window, cx:App) {
        search = SearchPanel.create(state, window, cx);
    }

    function sync(state:Entity<InputBaseState>, window:Window, cx:App):InputOverlays {
        final s = state.read(cx);
        final search = s.searchSession;
        final searchOpen = search.open;
        final replaceMode = search.replaceMode;
        final activationRevision = s.searchActivationRevision;
        final searchSession = search.clone();

        final panelReplaceMode = this.search.read(cx).replaceMode();
        this.search.update(cx, (panel, _) -> panel.syncSession(searchSession));

        final searchSignature = new SearchSignature(searchOpen, replaceMode, searchSession.query, searchSession.anchorOffset, activationRevision);
        if (!searchSignature.equals(this.searchSignature)) {
            // The panel writes query and replacement-mode changes back into the
            // session. Re-showing it for that echo would select the query or steal
            // focus from replacement, so preserve changes the panel already holds.
            // External mode changes still move focus out of a hidden replace field.
            final was = this.searchSignature;
            final queryEcho = searchOpen
                && was.open
                && (was.replaceMode == searchSignature.replaceMode || panelReplaceMode == searchSignature.replaceMode)
                && was.anchorOffset == searchSignature.anchorOffset
                && was.activationRevision == searchSignature.activationRevision
                && this.search.read(cx).query(cx) == searchSession.query;
            this.searchSignature = searchSignature;
            if (!queryEcho) {
                final focus = InputOverlays.focusOnSync;
                this.search.update(cx, (panel, cx) -> {
                    if (searchOpen) {
                        final selected = Rope.fromStr(searchSession.query);
                        final visible = searchSession.anchorOffset != null ? new Range(searchSession.anchorOffset, searchSession.anchorOffset) : null;
                        panel.showWithFocus(selected, replaceMode, visible, focus, window, cx);
                    }
                    else {
                        panel.hideWithFocus(focus, window, cx);
                    }
                });
            }
        }

        final overlays = new InputOverlays();
        if (searchOpen) overlays.search = (this.search : IntoElement).intoAnyElement();
        return overlays;
    }

}
