// Ported from gpui-kit 0.8.1: crates/component/src/root.rs (WindowState, the component layer's root plugin)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component;

import gpui.AnyElement;
import gpui.App;
import gpui.Bounds;
import gpui.AppContext;
import gpui.Context;
import gpui.DefiniteLength;
import gpui.DispatchPhase;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.GlobalElementId;
import gpui.MouseMoveEvent;
import gpui.Div;
import gpui.IntoElement;
import gpui.RenderOnce;
import gpui.StyleBuilder;
import gpui.Window;
import gpui.base.Geometry.Placement;
import gpui.base.Root;
import gpui.base.TextSelection;
import gpui.base.TextSelectionScopeId;
import gpui.base.Tooltip.TooltipOverlay;
import gpui.base.motion.Presence;
import gpui.base.motion.TransitionId;
import gpui.component.dialog.Dialog;
import gpui.component.notification.Notification;
import gpui.component.sheet.Sheet;
import gpui.component.tooltip.Tooltip.TooltipLifetime;
import gpui.component.theme.Theme;

import gpui.Prelude.*;

using gpui.base.ElementExt;

/**
 * Component-owned window state and presentation; Base owns the actual root.
 *
 * Registered by `Component.init` as a `Root` plugin: before each root
 * render it sets the window's rem size to the theme's font size, it gives the
 * root surface the theme's font family, background and text color, and it
 * mounts the window-level layers above the application content.
 *
 * Ported so far: the surface defaults, the sheet, dialog and notification
 * layers (`WindowStateLayers`) and the tooltip layer. The touch selection and
 * fallback menu layers come with their components. `decorate` wraps the surface in
 * `WindowBorder.windowBorder()`, which only draws client side decorations
 * (Linux): with the server decorations of the port's windows it renders the
 * surface unchanged.
 *
 * The dialog and sheet state is not observable: like Rust, every change to it
 * notifies the window state.
 */
@:allow(gpui.component, tests)
class WindowState extends RootPlugin {

    var activeSheet:Null<ActiveSheet> = null;

    var activeDialogs:Array<ActiveDialog> = [];

    /** The input that holds the focus, as registered by the inputs while they render. */
    @:allow(gpui.component)
    var focusedInput:Null<gpui.component.input.AnyInputState> = null;

    public final notification:Entity<NotificationList>;


    /** Rust field `tooltip_overlay`: the per-window tooltip provider (Base `TooltipOverlay`, rendered with `Tooltip.renderTooltip`). */
    @:allow(gpui.component)
    @:allow(tests)
    final tooltipOverlayEntity:Entity<TooltipOverlay>;

    final touchSelectionOverlay:Entity<gpui.component.touchselection.WindowTouchSelectionOverlay>;

    var tooltipHoveredTrigger:Null<GlobalElementId> = null;

    var tooltipTriggerLifetime:Null<TooltipLifetime> = null;

    /**
     * Bounds of the tooltip trigger last pressed, whose tooltip stays
     * dismissed until the pointer moves outside them.
     */
    @observe var tooltipPressedTrigger:Null<Bounds> = null;

    var sheetSize:Null<DefiniteLength> = null;

    /**
     * The focus to restore after a deferred close (Rust keeps a weak handle;
     * the port's focus handles are never released).
     */
    var pendingFocusRestore:Null<FocusHandle> = null;

    /** Source of stable dialog identities, including their rendered subtrees. */
    var nextDialogId:Int = 0;

    public function new(window:Window, cx:Context<WindowState>) {
        super();
        notification = cx.newEntity((notificationCx:Context<NotificationList>) -> new NotificationList(window, notificationCx));
        tooltipOverlayEntity = cx.newEntity((_:Context<TooltipOverlay>) -> new TooltipOverlay().renderWith(gpui.component.tooltip.Tooltip.renderTooltip));
        touchSelectionOverlay = cx.newEntity((cx:Context<gpui.component.touchselection.WindowTouchSelectionOverlay>) -> new gpui.component.touchselection.WindowTouchSelectionOverlay(window, cx));
    }

    static inline final ROOT_MISSING = 'component window state is missing; call gpui.component.Component.init before opening the window';

    /**
     * The component state of `window`, or null when its root has none.
     */
    public static function tryRead(window:Window):Null<WindowState> {
        final root = Root.tryRead(window);
        return root != null ? root.plugin(WindowState) : null;
    }

    public static function read(window:Window):WindowState {
        final state = tryRead(window);
        if (state == null)
            throw ROOT_MISSING;
        return state;
    }

    public static function update<R>(window:Window, cx:AppContext, f:(WindowState, Window, Context<WindowState>) -> R):R {
        final state:Entity<WindowState> = read(window);
        return state.update(cx, (state, cx) -> f(state, window, cx));
    }

    public static function tryUpdate<R>(window:Window, cx:AppContext, f:(WindowState, Window, Context<WindowState>) -> R):Null<R> {
        final state:Null<Entity<WindowState>> = tryRead(window);
        if (state == null)
            return null;
        return state.update(cx, (state, cx) -> f(state, window, cx));
    }

    function allocateTextSelectionScope():TextSelectionScopeId {
        return TextSelectionScopeId.allocate();
    }

    /**
     * The scope of the topmost open dialog, else of the sheet, else the
     * default scope.
     */
    @:allow(gpui.component)
    function activeTextSelectionScope():TextSelectionScopeId {
        var ix = activeDialogs.length - 1;
        while (ix >= 0) {
            if (!activeDialogs[ix].closing) return activeDialogs[ix].selectionScope;
            ix--;
        }
        if (activeSheet != null) return activeSheet.selectionScope;
        return TextSelectionScopeId.DEFAULT;
    }

    static function notificationLayer(root:WindowState, window:Window, cx:App):Null<IntoElement> {
        final activeSheetPlacement:Null<Placement> = root.activeSheet != null ? root.activeSheet.placement : null;

        final sheetSize = root.sheetSize;
        var mt:Null<DefiniteLength> = null;
        var mr:Null<DefiniteLength> = null;
        var mb:Null<DefiniteLength> = null;
        var ml:Null<DefiniteLength> = null;
        if (activeSheetPlacement != null) {
            switch activeSheetPlacement {
                case Top: mt = sheetSize;
                case Right: mr = sheetSize;
                case Bottom: mb = sheetSize;
                case Left: ml = sheetSize;
            }
        }

        // Keep toasts out from under the system bars and the on-screen keyboard.
        final safeInsets = WindowBorder.windowSafeInsets(window);

        final inner = div()
            .absolute()
            .inset0();
        if (mt != null) inner.mt(mt);
        if (mr != null) inner.mr(mr);
        if (mb != null) inner.mb(mb);
        if (ml != null) inner.ml(ml);
        return div()
            .absolute()
            .top(px(safeInsets.top))
            .right(px(safeInsets.right))
            .bottom(px(safeInsets.bottom))
            .left(px(safeInsets.left))
            .child(inner.child(root.notification));
    }

    static function sheetLayer(root:WindowState, window:Window, cx:App):Null<IntoElement> {
        final activeSheet = root.activeSheet;
        if (activeSheet != null) {
            var sheet = new Sheet(window, cx);
            sheet = activeSheet.builder(sheet, window, cx);
            sheet.focusHandle = activeSheet.focusHandle;
            sheet.selectionScope = activeSheet.selectionScope;
            sheet.placement = activeSheet.placement;

            final size = sheet.sizeValue;

            // Rust updates the window state entity in prepaint; the size is
            // not observable, so the port writes it directly.
            return div()
                .relative()
                .child(sheet)
                .onPrepaint((_, _, _) -> root.sheetSize = size);
        }

        return null;
    }

    /** Keys one dialog's shared entrance and exit transition. */
    static inline function dialogPresenceId(id:Int):TransitionId {
        return ElementId.NamedInteger('dialog-presence', id);
    }

    static function dialogLayer(root:WindowState, window:Window, cx:App):Null<IntoElement> {
        final activeDialogs = root.activeDialogs.copy();

        if (activeDialogs.length == 0) {
            return null;
        }

        final rendered:Array<{index:Int, dialog:Dialog}> = [];

        for (index in 0...activeDialogs.length) {
            final activeDialog = activeDialogs[index];
            var dialog = new Dialog(cx);

            dialog = activeDialog.builder(dialog, window, cx);

            // Give the dialog the focus handle: the dialog is a temporary
            // value, so the focus handle is kept in the `ActiveDialog`, owned
            // by the `WindowState`.
            dialog.focusHandle = activeDialog.focusHandle;
            dialog.selectionScope = activeDialog.selectionScope;

            dialog.layerIx = index;
            dialog.id = activeDialog.id;

            // Refreshed every frame so closing decides in one step whether an
            // exit transition has to play at all.
            final exitDuration = dialog.exitDuration(cx);
            activeDialog.exitEnabled = exitDuration != 0;

            final sample = new Presence(dialogPresenceId(activeDialog.id), !activeDialog.closing)
                .transition(dialog.motionTransition(cx))
                .sample(window, cx);
            if (activeDialog.closing && !sample.shouldRender()) {
                scheduleDialogRemoval(root, activeDialog.id, window, cx);
                continue;
            }
            dialog.motion = new DialogMotion(sample.progress, activeDialog.closing);

            rendered.push({index: index, dialog: dialog});
        }

        if (rendered.length == 0) {
            return null;
        }

        // The overlay belongs to the newest dialog still open. With none left,
        // the newest closing dialog keeps the dim through its exit so the
        // backdrop fades with the surface instead of switching off at once.
        // A closing dialog below an open overlay never paints its own backdrop:
        // the constant dim beneath it hands over without a flash.
        var overlaySlot:Null<Int> = null;
        for (slot in 0...rendered.length) {
            if (!activeDialogs[rendered[slot].index].closing && rendered[slot].dialog.hasOverlay()) {
                overlaySlot = slot;
            }
        }
        if (overlaySlot == null) {
            for (slot in 0...rendered.length) {
                if (rendered[slot].dialog.hasOverlay()) {
                    overlaySlot = slot;
                }
            }
        }
        if (overlaySlot != null) {
            rendered[overlaySlot].dialog.props.overlayVisible = true;
        }

        final closingScopes = [for (dialog in activeDialogs) if (dialog.closing) dialog.focusHandle];

        // Named so a test can assert the layer actually reached the screen. A
        // dialog that opens into a root which never renders this layer looks
        // exactly like one that does not open.
        final layer = div()
            .debugSelector(() -> 'dialog-layer')
            .children([for (entry in rendered) div().id(ElementId.NamedInteger('dialog-instance', entry.dialog.id)).child(entry.dialog)]);
        if (closingScopes.length > 0) {
            layer.onPrepaint((_, window, cx) -> {
                // Skip every exiting scope, including when close-all
                // leaves several old tab groups mounted at once.
                final visited:Array<Null<FocusHandle>> = [];
                while (Lambda.exists(closingScopes, scope -> scope.containsFocused(window, cx))) {
                    final current = window.focused(cx);
                    if (visited.indexOf(current) != -1) {
                        window.blur(cx);
                        break;
                    }
                    visited.push(current);
                    if (window.modifiers().shift) {
                        window.focusPrev(cx);
                    }
                    else {
                        window.focusNext(cx);
                    }
                }
            });
        }
        return layer;
    }

    /**
     * Unmounts a dialog once its exit transition has finished.
     *
     * The removal is deferred because the layer runs while the window state
     * that owns the dialog is rendering, and removing it mid-render would
     * update an entity that is still on the stack.
     */
    static function scheduleDialogRemoval(root:WindowState, dialogId:Int, window:Window, cx:App):Void {
        final root:Entity<WindowState> = root;
        window.defer(cx, (_, cx) -> {
            root.update(cx, (state, cx) -> {
                final before = state.activeDialogs.length;
                final kept = [];
                for (dialog in state.activeDialogs) {
                    if (dialog.closing && dialog.id == dialogId) releaseFocusHandle(dialog.focusHandle, window, cx.app);
                    else kept.push(dialog);
                }
                state.activeDialogs = kept;
                if (state.activeDialogs.length != before) {
                    cx.notify();
                }
            });
        });
    }

    public function openDialog(build:(Dialog, Window, App) -> Dialog, window:Window, cx:Context<WindowState>):Void {
        var previousFocusedHandle = window.focused(cx.app);

        // Use pending focus restore if available to maintain correct focus chain
        // when a new dialog is opened immediately after closing another dialog.
        if (pendingFocusRestore != null) {
            previousFocusedHandle = pendingFocusRestore;
            pendingFocusRestore = null;
        }

        final focusHandle = cx.focusHandle();
        focusHandle.focus(window, cx.app);

        final id = nextDialogId;
        nextDialogId++;
        final selectionScope = allocateTextSelectionScope();
        activeDialogs.push(new ActiveDialog(id, focusHandle, previousFocusedHandle, selectionScope, build));
        // Opening a modal confines selection to it; drop any background
        // selection so it cannot linger (or be copied) under the modal.
        TextSelection.clear(window, cx.app);
        cx.notify();
    }

    /**
     * Closes the newest dialog that is not already closing.
     *
     * A dialog with an exit transition stays in `activeDialogs`, marked
     * `closing`, until `dialogLayer` unmounts it once the transition ends.
     * Without one, it is removed as before.
     */
    function closeDialogInternal(window:Window, cx:App):Null<FocusHandle> {
        focusedInput = null;

        var ix = activeDialogs.length - 1;
        while (ix >= 0 && activeDialogs[ix].closing) {
            ix--;
        }
        if (ix < 0) {
            return null;
        }
        final previousFocusedHandle = activeDialogs[ix].previousFocusedHandle;

        if (activeDialogs[ix].exitEnabled) {
            beginDialogExit(activeDialogs[ix], window, cx);
        }
        else {
            releaseFocusHandle(activeDialogs.splice(ix, 1)[0].focusHandle, window, cx);
        }

        return previousFocusedHandle;
    }

    /**
     * Stands for dropping a dialog's or a sheet's focus handle with its
     * `ActiveDialog` / `ActiveSheet`. GPUI releases a dropped handle, so a
     * window still focused on it reports no focus (`Window::focused` is
     * `None`); the port never releases focus handles, so it forgets the focus
     * instead (the keyed handles of the content, such as the close button's,
     * are forgotten when their state is dropped, see `StateModel.destroy`).
     */
    static function releaseFocusHandle(handle:FocusHandle, window:Window, cx:App):Void {
        if (handle.isFocused(window)) {
            @:privateAccess window._focus = null;
        }
    }

    static function beginDialogExit(dialog:ActiveDialog, window:Window, cx:App):Void {
        if (dialog.closing) {
            return;
        }
        dialog.closing = true;
        // Do not leave the input handler active during deferred focus restoration.
        if (dialog.focusHandle.containsFocused(window, cx)) {
            window.blur(cx);
        }
    }

    public function closeDialog(window:Window, cx:Context<WindowState>):Void {
        final handle = closeDialogInternal(window, cx.app);
        if (handle != null) {
            window.focus(handle, cx.app);
        }
        TextSelection.clear(window, cx.app);
        cx.notify();
    }

    function deferCloseDialog(window:Window, cx:Context<WindowState>):Void {
        final handle = closeDialogInternal(window, cx.app);
        if (handle != null) {
            // The dialog left behind for its exit transition must not look
            // like a newly opened dialog later, so compare what stays open.
            final openDialogs = countOpenDialogs();

            // Save for new dialogs opened during animation to maintain focus chain
            pendingFocusRestore = handle;

            final state = cx.weakEntity();
            final app = cx.app;
            app.backgroundExecutor().timer(Dialog.ANIMATION_DURATION).then(_ -> {
                if (window.isDestroyed() || !state.isUpgradable()) {
                    return;
                }
                state.update(app, (state, cx) -> {
                    final currentOpenDialogs = state.countOpenDialogs();
                    // Only restore focus if no new dialogs were opened during animation
                    if (currentOpenDialogs == openDialogs) {
                        window.focus(handle, cx.app);
                    }
                    state.pendingFocusRestore = null;
                });
            });
        }
        TextSelection.clear(window, cx.app);
        cx.notify();
    }

    function countOpenDialogs():Int {
        var count = 0;
        for (dialog in activeDialogs) {
            if (!dialog.closing) count++;
        }
        return count;
    }

    public function closeAllDialogs(window:Window, cx:Context<WindowState>):Void {
        focusedInput = null;
        final previousFocusedHandle = activeDialogs.length > 0 ? activeDialogs[0].previousFocusedHandle : null;

        // Dialogs with an exit transition leave by animating; the rest go now.
        final kept = [];
        for (dialog in activeDialogs) {
            if (dialog.closing || dialog.exitEnabled) kept.push(dialog);
            else releaseFocusHandle(dialog.focusHandle, window, cx.app);
        }
        activeDialogs = kept;
        for (dialog in activeDialogs) {
            beginDialogExit(dialog, window, cx.app);
        }

        if (previousFocusedHandle != null) {
            window.focus(previousFocusedHandle, cx.app);
        }
        TextSelection.clear(window, cx.app);
        cx.notify();
    }

    public function openSheetAt(placement:Placement, build:(Sheet, Window, App) -> Sheet, window:Window, cx:Context<WindowState>):Void {
        final taken = activeSheet;
        activeSheet = null;
        if (taken != null) releaseFocusHandle(taken.focusHandle, window, cx.app);
        final previousFocusedHandle = taken != null && taken.previousFocusedHandle != null
            ? taken.previousFocusedHandle
            : window.focused(cx.app);

        final focusHandle = cx.focusHandle();
        focusHandle.focus(window, cx.app);
        final selectionScope = allocateTextSelectionScope();
        activeSheet = new ActiveSheet(focusHandle, previousFocusedHandle, placement, selectionScope, build);
        // Opening a modal confines selection to it; drop any background
        // selection so it cannot linger (or be copied) under the modal.
        TextSelection.clear(window, cx.app);
        cx.notify();
    }

    public function closeSheet(window:Window, cx:Context<WindowState>):Void {
        focusedInput = null;
        if (activeSheet != null && activeSheet.previousFocusedHandle != null) {
            window.focus(activeSheet.previousFocusedHandle, cx.app);
        }
        if (activeSheet != null) releaseFocusHandle(activeSheet.focusHandle, window, cx.app);
        activeSheet = null;
        TextSelection.clear(window, cx.app);
        cx.notify();
    }

    public function pushNotification(note:IntoNotification, window:Window, cx:Context<WindowState>):Void {
        notification.update(cx, (view, cx) -> view.push(note, window, cx));
        cx.notify();
    }

    /**
     * Removes all notifications whose id matches `type`, including ones
     * registered with either `Notification.withId` or `Notification.id1` (any key).
     */
    public function removeNotification(type:Class<Dynamic>, window:Window, cx:Context<WindowState>):Void {
        notification.update(cx, (view, cx) -> view.closeByType(NotificationIdTools.typeIdOf(type), window, cx));
        cx.notify();
    }

    /**
     * Removes the notification matching the given type and element id (paired with `Notification.id1`).
     */
    public function removeNotification1(type:Class<Dynamic>, key:ElementIdArg, window:Window, cx:Context<WindowState>):Void {
        final key:ElementId = key;
        notification.update(cx, (view, cx) -> view.close(IdAndElementId(NotificationIdTools.typeIdOf(type), key), window, cx));
        cx.notify();
    }

    public function clearNotifications(window:Window, cx:Context<WindowState>):Void {
        notification.update(cx, (view, cx) -> view.clear(window, cx));
        cx.notify();
    }

    /**
     * Get the tooltip overlay entity for this window.
     */
    @:allow(gpui.component)
    @:allow(tests)
    static function tooltipOverlay(window:Window, cx:App):Null<Entity<TooltipOverlay>> {
        final state = tryRead(window);
        return state != null ? state.tooltipOverlayEntity : null;
    }

    /**
     * Only the current trigger may request a hide. Hover listeners run in
     * reverse paint order, so a new trigger can enter before the old one leaves.
     */
    @:allow(gpui.component)
    static function tooltipOverlayForTrigger(trigger:GlobalElementId, lifetime:Null<TooltipLifetime>, hovered:Bool, window:Window, cx:App):Null<Entity<TooltipOverlay>> {
        final state = tryRead(window);
        if (state == null) {
            return null;
        }
        if (hovered) {
            state.tooltipHoveredTrigger = trigger;
            state.tooltipTriggerLifetime = lifetime;
        }
        else if (trigger.equals(state.tooltipHoveredTrigger)) {
            state.tooltipHoveredTrigger = null;
            state.tooltipTriggerLifetime = null;
        }
        else {
            return null;
        }
        return state.tooltipOverlayEntity;
    }

    function dismissRemovedTooltip(window:Window, cx:App):Void {
        final trigger = tooltipHoveredTrigger;
        if (trigger == null) {
            return;
        }
        final state:Entity<WindowState> = this;
        final weak = state.downgrade();
        // Defer until GPUI has retained this frame's element states and dropped
        // absent ones. A reused cached subtree keeps its trigger alive.
        window.defer(cx, (_, cx) -> {
            weak.tryUpdate(cx, (state, cx) -> {
                if (!trigger.equals(state.tooltipHoveredTrigger) || TooltipLifetime.isAlive(state.tooltipTriggerLifetime)) {
                    return;
                }
                state.tooltipHoveredTrigger = null;
                state.tooltipTriggerLifetime = null;
                state.tooltipOverlayEntity.update(cx, (overlay, cx) -> overlay.hide(cx));
            });
        });
    }

    /**
     * Keeps the tooltip of the trigger at `bounds` dismissed until the
     * pointer moves outside them.
     */
    @:allow(gpui.component)
    static function pressTooltipTrigger(bounds:Bounds, window:Window, cx:App):Void {
        final state = tryRead(window);
        if (state != null) {
            // Rust `cx.notify()`: the field is observable.
            state.tooltipPressedTrigger = bounds;
        }
    }

    @:allow(gpui.component)
    static function isTooltipTriggerPressed(bounds:Bounds, window:Window, cx:App):Bool {
        final state = tryRead(window);
        if (state == null) {
            return false;
        }
        tracker.Autorun.unobserve();
        final pressed = state.tooltipPressedTrigger;
        tracker.Autorun.reobserve();
        return pressed != null && pressed.equals(bounds);
    }

    /**
     * Ends the press on the first pointer move outside the trigger. It is
     * window-level because a removed or moved trigger never reports a
     * hover-leave.
     */
    function tooltipPressListener():Null<IntoElement> {
        final bounds = tooltipPressedTrigger;
        if (bounds == null) {
            return null;
        }
        final state:Entity<WindowState> = this;
        final weak = state.downgrade();
        return canvas((_, _, _) -> null, (_, _, window, _) -> {
            window.onMouseEvent(MouseMove, (event, phase, _, cx) -> {
                final event:MouseMoveEvent = cast event;
                if (phase != DispatchPhase.Capture || bounds.contains(event.position)) {
                    return;
                }
                weak.tryUpdate(cx, (state, _) -> {
                    if (state.tooltipPressedTrigger != null && state.tooltipPressedTrigger.equals(bounds)) {
                        state.tooltipPressedTrigger = null;
                    }
                });
            });
        });
    }

    override public function prepare(window:Window, cx:Context<Dynamic>):Void {
        dismissRemovedTooltip(window, cx.app);
        window.setRemSize(Theme.global(cx.app).fontSize);
        TextSelection.activateScope(activeTextSelectionScope(), window, cx.app);
    }

    override public function styleSurface(surface:Div, window:Window, cx:App):Void {
        final theme = Theme.global(cx);
        final style = new StyleBuilder()
            .fontFamily(theme.fontFamily)
            .bg(theme.tokens.background.background)
            .textColor(theme.foreground)
            .style();
        surface.style().refine(style);
    }

    override public function decorate(surface:AnyElement, root:Root, window:Window, cx:App):IntoElement {
        return WindowBorder.windowBorder().child(surface);
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final layers = div()
            .absolute()
            .inset0()
            .child(new WindowStateLayers(this));
        layers.child(touchSelectionOverlay);
        layers.child(tooltipOverlayEntity);
        final pressListener = tooltipPressListener();
        if (pressListener != null) layers.child(pressListener);
        // The fallback native-menu overlay (Rust `native_menu_overlay`) comes with the menus.
        return layers;
    }

}

@:allow(gpui.component, tests)
class ActiveSheet {

    final focusHandle:FocusHandle;

    /** The previous focused handle before opening the Sheet. */
    final previousFocusedHandle:Null<FocusHandle>;

    final placement:Placement;

    final selectionScope:TextSelectionScopeId;

    final builder:(Sheet, Window, App) -> Sheet;

    function new(focusHandle:FocusHandle, previousFocusedHandle:Null<FocusHandle>, placement:Placement, selectionScope:TextSelectionScopeId, builder:(Sheet, Window, App) -> Sheet) {
        this.focusHandle = focusHandle;
        this.previousFocusedHandle = previousFocusedHandle;
        this.placement = placement;
        this.selectionScope = selectionScope;
        this.builder = builder;
    }

}

@:allow(gpui.component, tests)
class ActiveDialog {

    /** Stable for the dialog's lifetime, independently of its stack position. */
    final id:Int;

    final focusHandle:FocusHandle;

    /** The previous focused handle before opening the Dialog. */
    final previousFocusedHandle:Null<FocusHandle>;

    final selectionScope:TextSelectionScopeId;

    final builder:(Dialog, Window, App) -> Dialog;

    /**
     * Whether closing plays an exit transition, refreshed on every render.
     *
     * `DialogEntrance.None`, reduced motion, and a zero theme duration all
     * close in a single frame.
     */
    var exitEnabled:Bool = false;

    /** Retained after closing until its exit transition finishes. */
    var closing:Bool = false;

    function new(id:Int, focusHandle:FocusHandle, previousFocusedHandle:Null<FocusHandle>, selectionScope:TextSelectionScopeId, builder:(Dialog, Window, App) -> Dialog) {
        this.id = id;
        this.focusHandle = focusHandle;
        this.previousFocusedHandle = previousFocusedHandle;
        this.selectionScope = selectionScope;
        this.builder = builder;
    }

}

/**
 * Window-level layers, always mounted once after the application content.
 * Child view caching does not affect their ownership or rendering.
 */
private class WindowStateLayers implements RenderOnce {

    final root:WindowState;

    public function new(root:WindowState) {
        this.root = root;
    }

    public function render(window:Window, cx:App):IntoElement {
        final root = this.root;
        final layers:Array<IntoElement> = [];
        final sheet = WindowState.sheetLayer(root, window, cx);
        if (sheet != null) layers.push(sheet);
        final dialog = WindowState.dialogLayer(root, window, cx);
        if (dialog != null) layers.push(dialog);
        final notification = WindowState.notificationLayer(root, window, cx);
        if (notification != null) layers.push(notification);
        return div()
            .absolute()
            .inset0()
            .debugSelector(() -> 'root-layers')
            .children(layers);
    }

}
