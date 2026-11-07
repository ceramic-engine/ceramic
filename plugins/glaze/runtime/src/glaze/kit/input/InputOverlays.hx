// Ported from gpui-kit 0.8.1: crates/component/src/input/overlay.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.input;

import glaze.AnyElement;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Range;
import glaze.WeakEntity;
import glaze.Window;
import glaze.kit.base.input.CompletionHighlighter;
import glaze.kit.base.input.DiagnosticEntry;
import glaze.kit.base.input.EditorState;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputOverlayKind;
import ropey.Rope;

using glaze.kit.base.input.InputLspExt;
using glaze.kit.base.input.InputSearchExt;

/**
 * The overlays an input renders around its text: the search panel (placed
 * above a multi-line editor) and the floating popovers.
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
        OverlayMode.installActionHandler(state, cx);
        final hasOverlay = {
            final s = state.read(cx);
            final snapshot = OverlayMode.lspSnapshot(s, cx);
            s.searchSession.open || (snapshot != null && snapshot.hasOverlay());
        };
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

/**
 * Identifies one version of an overlay's content.
 *
 * Sync runs on every frame, so the check for "did this change" must not touch
 * the content itself: the completion list can hold hundreds of items, each
 * with its own documentation. The engine bumps a revision when it swaps the
 * content, and the popovers are keyed by cheap identity instead: a revision,
 * a reference, or a range.
 */
@:allow(glaze.kit.input, tests)
class OverlaySignature {

    final open:Bool;

    final revision:Int;

    public function new(open:Bool = false, revision:Int = 0) {
        this.open = open;
        this.revision = revision;
    }

    public function equals(other:OverlaySignature):Bool {
        return open == other.open && revision == other.revision;
    }

}

/**
 * The popovers driven by language features: completion, code actions, hover
 * and diagnostics. They belong to a code editor, so they are built and synced
 * by `OverlayMode`, where the state's kind is concrete.
 */
@:allow(glaze.kit.input, tests)
class LspOverlays {

    final completion:Entity<CompletionMenu>;

    final codeActions:Entity<CodeActionMenu>;

    var hover:Null<Entity<HoverPopover>> = null;

    var diagnostic:Null<Entity<DiagnosticPopover>> = null;

    var completionSignature:OverlaySignature = new OverlaySignature();

    var codeActionSignature:OverlaySignature = new OverlaySignature();

    var hoverSignature:Null<Range> = null;

    var diagnosticSignature:Null<DiagnosticEntry> = null;

    /**
     * Highlighter last copied onto the completion menu.
     *
     * Compared by identity, so swapping the host's closure repaints an open
     * menu without rebuilding its items.
     */
    var completionHighlight:Null<CompletionHighlighter> = null;

    public function new(completion:Entity<CompletionMenu>, codeActions:Entity<CodeActionMenu>) {
        this.completion = completion;
        this.codeActions = codeActions;
    }

}

/**
 * What the state read out of the engine for one sync pass.
 *
 * Deliberately free of content: only what is needed to decide whether a
 * popover is shown and whether it changed. The content is read from the state
 * again, on the frames where it actually did.
 */
@:allow(glaze.kit.input, tests)
class LspSnapshot {

    final completion:OverlaySignature;

    final completionStart:Null<Int>;

    final codeAction:OverlaySignature;

    final hover:Null<Range>;

    final diagnostic:Null<DiagnosticEntry>;

    final cursor:Int;

    public function new(completion:OverlaySignature, completionStart:Null<Int>, codeAction:OverlaySignature, hover:Null<Range>, diagnostic:Null<DiagnosticEntry>, cursor:Int) {
        this.completion = completion;
        this.completionStart = completionStart;
        this.codeAction = codeAction;
        this.hover = hover;
        this.diagnostic = diagnostic;
        this.cursor = cursor;
    }

    function hasOverlay():Bool {
        return completion.open || codeAction.open || hover != null || diagnostic != null;
    }

}

/**
 * What the UI layer needs from each kind of input (Rust trait `OverlayMode`,
 * implemented by `InputMode` and `TextareaMode` with its defaults and by
 * `EditorMode`). The code-editor implementation is the only one that builds
 * language-feature popovers; the port picks it from the state's class.
 */
@:allow(glaze.kit.input, tests)
class OverlayMode {

    static inline function isEditor(state:InputBaseState):Bool {
        return Std.isOfType(state, EditorState);
    }

    /** Installs the routing that lets an open menu consume actions first. */
    static function installActionHandler(state:Entity<InputBaseState>, cx:App):Void {
        if (!isEditor(state.read(cx)))
            return;
        final id = state.entityId();
        state.update(cx, (state, _) -> {
            state.setOverlayActionHandler((kind, action, window, cx) -> {
                final registry = InputOverlayRegistry.get(cx.app);
                final entry = registry != null ? registry.hosts.get(id) : null;
                final lsp = entry != null ? entry.host.lsp : null;
                if (lsp == null)
                    return false;
                final completion = lsp.completion;
                final codeActions = lsp.codeActions;
                return switch kind {
                    case Completion:
                        completion.update(cx, (menu, cx) -> menu.handleAction(action, window, cx));
                    case CodeAction:
                        codeActions.update(cx, (menu, cx) -> menu.handleAction(action, window, cx));
                }
            });
        });
    }

    /** Reads the language-feature state this mode shows, if any. */
    static function lspSnapshot(state:InputBaseState, _:App):Null<LspSnapshot> {
        if (!isEditor(state))
            return null;
        final completion = state.completionMenuState();
        final codeActions = state.codeActionMenuState();
        final hoverPopover = state.hoverPopover();
        return new LspSnapshot(
            new OverlaySignature(completion.open, completion.revision()),
            completion.triggerStartOffset,
            new OverlaySignature(codeActions.open, codeActions.revision()),
            hoverPopover != null ? hoverPopover.symbolRange : null,
            state.diagnosticPopover,
            state.cursor()
        );
    }

    static function buildLsp(state:Entity<InputBaseState>, window:Window, cx:App):Null<LspOverlays> {
        if (!isEditor(state.read(cx)))
            return null;
        final editor:Entity<EditorState> = cast state;
        return new LspOverlays(CompletionMenu.create(editor, window, cx), CodeActionMenu.create(editor, window, cx));
    }

    static function syncLsp(lsp:LspOverlays, state:Entity<InputBaseState>, snapshot:LspSnapshot, window:Window, cx:App):Void {
        final editor:Entity<EditorState> = cast state;
        final cursor = snapshot.cursor;

        final highlight = (cast state.read(cx) : EditorState).lsp().completionHighlighter();
        if (lsp.completionHighlight == null || !Reflect.compareMethods(lsp.completionHighlight, highlight)) {
            lsp.completionHighlight = highlight;
            lsp.completion.update(cx, (menu, cx) -> menu.setHighlight(highlight, cx));
        }

        if (!snapshot.completion.equals(lsp.completionSignature)) {
            lsp.completionSignature = new OverlaySignature(snapshot.completion.open, snapshot.completion.revision);
            final open = snapshot.completion.open;
            final start = snapshot.completionStart;
            // Read the items only now, on a frame where they changed.
            final menuState = state.read(cx).completionMenuState();
            final query = menuState.query;
            final items = menuState.items.copy();
            lsp.completion.update(cx, (menu, cx) -> {
                if (open) {
                    menu.updateQuery(start != null ? start : cursor, query);
                    menu.show(cursor, items, window, cx);
                }
                else {
                    menu.hide(cx);
                }
            });
        }

        if (!snapshot.codeAction.equals(lsp.codeActionSignature)) {
            lsp.codeActionSignature = new OverlaySignature(snapshot.codeAction.open, snapshot.codeAction.revision);
            final open = snapshot.codeAction.open;
            final items = state.read(cx).codeActionMenuState().items.copy();
            lsp.codeActions.update(cx, (menu, cx) -> {
                if (open) {
                    menu.show(cursor, items, window, cx);
                }
                else {
                    menu.hide(cx);
                }
            });
        }

        // A hover popover is anchored to one symbol, so a new range means new
        // content and the same range means the same content.
        if (!sameRange(snapshot.hover, lsp.hoverSignature)) {
            lsp.hoverSignature = snapshot.hover;
            final popover = state.read(cx).hoverPopover();
            lsp.hover = popover != null ? HoverPopover.create(editor, popover.symbolRange, popover.hover, cx) : null;
        }

        // The engine hands out the diagnostic by reference, so identity
        // already answers "is this the same entry".
        final diagnosticChanged = snapshot.diagnostic != lsp.diagnosticSignature;
        if (diagnosticChanged) {
            lsp.diagnosticSignature = snapshot.diagnostic;
            lsp.diagnostic = snapshot.diagnostic != null ? DiagnosticPopover.create(snapshot.diagnostic, editor, cx) : null;
        }
    }

    static function sameRange(a:Null<Range>, b:Null<Range>):Bool {
        if (a == null || b == null)
            return a == null && b == null;
        return a.equals(b);
    }

}

@:allow(glaze.kit.input, tests)
class InputOverlayHost {

    final search:Entity<SearchPanel>;

    var searchSignature:SearchSignature = new SearchSignature();

    /** The language-feature popovers. Only a code editor has them. */
    final lsp:Null<LspOverlays>;

    public function new(state:Entity<InputBaseState>, window:Window, cx:App) {
        search = SearchPanel.create(state, window, cx);
        lsp = OverlayMode.buildLsp(state, window, cx);
    }

    function sync(state:Entity<InputBaseState>, window:Window, cx:App):InputOverlays {
        final snapshot = OverlayMode.lspSnapshot(state.read(cx), cx);
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

        if (lsp != null && snapshot != null) {
            OverlayMode.syncLsp(lsp, state, snapshot, window, cx);
        }

        final overlays = new InputOverlays();
        if (searchOpen) overlays.search = (this.search : IntoElement).intoAnyElement();
        if (lsp != null && snapshot != null) {
            if (snapshot.completion.open) {
                overlays.floating.push((lsp.completion : IntoElement).intoAnyElement());
            }
            if (snapshot.codeAction.open) {
                overlays.floating.push((lsp.codeActions : IntoElement).intoAnyElement());
            }
            if (lsp.hover != null) {
                overlays.floating.push((lsp.hover : IntoElement).intoAnyElement());
            }
            if (lsp.diagnostic != null) {
                overlays.floating.push((lsp.diagnostic : IntoElement).intoAnyElement());
            }
        }
        return overlays;
    }

}
