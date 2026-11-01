// Ported from gpui-kit 0.8.1: crates/base/src/global_state.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.App;
import gpui.AppContext;
import gpui.Bounds;
import gpui.Point;

/**
 * Holds the deferred interaction context open for as long as it is alive.
 *
 * Handed out by `GlobalState.registerDeferredPopover`. Rust closes the
 * context when the token is dropped; Haxe has no destructors, so call
 * `release()` (the owner of the popup state calls it from its `destroy`).
 */
class DeferredPopover {

    public var alive(default, null):Bool = true;

    @:allow(gpui.base.GlobalState)
    function new() {}

    /**
     * Closes the deferred context held by this token (Rust: dropping it).
     */
    public function release():Void {
        alive = false;
    }

}

/**
 * Application-wide state shared by Base behaviors.
 *
 * Not observable: Base reads it from event handlers, never to render.
 */
class GlobalState {

    var deferredPopovers:Array<DeferredPopover> = [];

    var appMenusValue:Array<gpui.Menu.OwnedMenu> = [];

    var suppressTextSelectionFlag:Bool = false;

    /**
     * The text views being prepainted or painted, innermost last. Kept apart
     * from what views read of this global: pushing and popping as they draw
     * is not a change of it.
     */
    var textViewStateStack:Array<gpui.Entity<gpui.base.text.TextViewState>> = [];

    /** The table cells being prepainted or painted, innermost last. */
    var tableCellStack:Array<Bounds> = [];

    /** When a finger last went down (seconds, `haxe.Timer.stamp()`). */
    var lastTouch:Null<Float> = null;

    function new() {}

    /**
     * Records that a finger went down.
     */
    public static function noteTouch(cx:AppContext):Void {
        init(cx);
        globalMut(cx).lastTouch = haxe.Timer.stamp();
    }

    /**
     * Whether the press being handled came from a finger: a touch went down
     * recently enough that the mouse events of a tap are still arriving.
     */
    public static function isTouchPress(cx:AppContext):Bool {
        final state = (cx:App).tryGlobal(GlobalState);
        return state != null && state.lastTouch != null && haxe.Timer.stamp() - state.lastTouch < 1.0;
    }

    /**
     * Ensures that the Base global exists.
     */
    public static function init(cx:AppContext):Void {
        final app:App = cx;
        if (!app.hasGlobal(GlobalState)) {
            app.setGlobal(new GlobalState(), GlobalState);
        }
    }

    /**
     * Suppresses window-level text selection for the current mouse down.
     */
    public static function suppressTextSelection(cx:AppContext):Void {
        globalMut(cx).suppressTextSelectionFlag = true;
    }

    /**
     * Clears the current mouse-down text-selection suppression.
     */
    public static function resetTextSelectionSuppression(cx:AppContext):Void {
        globalMut(cx).suppressTextSelectionFlag = false;
    }

    /**
     * Returns whether the current mouse down suppresses text selection.
     */
    public static function isTextSelectionSuppressed(cx:AppContext):Bool {
        return global(cx).suppressTextSelectionFlag;
    }

    public static function global(cx:AppContext):GlobalState {
        tracker.Autorun.unobserve();
        final state = (cx:App).global(GlobalState);
        tracker.Autorun.reobserve();
        return state;
    }

    public static function globalMut(cx:AppContext):GlobalState {
        // Not observable state: no invalidation of the global cell.
        return global(cx);
    }

    /**
     * The innermost text view being prepainted or painted, if any.
     */
    public function textViewState():Null<gpui.Entity<gpui.base.text.TextViewState>> {
        return textViewStateStack.length > 0 ? textViewStateStack[textViewStateStack.length - 1] : null;
    }

    public function pushTextViewState(state:gpui.Entity<gpui.base.text.TextViewState>):Void {
        textViewStateStack.push(state);
    }

    public function popTextViewState():Void {
        textViewStateStack.pop();
    }

    /**
     * Enters the table cell being prepainted or painted.
     */
    public function pushTableCell(bounds:Bounds):Void {
        tableCellStack.push(bounds);
    }

    public function popTableCell():Void {
        tableCellStack.pop();
    }

    /**
     * The table cell being prepainted or painted, if any.
     */
    public function tableCell():Null<Bounds> {
        return tableCellStack.length > 0 ? tableCellStack[tableCellStack.length - 1] : null;
    }

    /**
     * Kept for compatibility; automatic order now belongs to the window's selection state.
     */
    public function beginSelectionFrame():Void {}

    /**
     * Returns the application menus.
     */
    public function appMenus():Array<gpui.Menu.OwnedMenu> {
        return appMenusValue;
    }

    /**
     * Replaces the application menus.
     */
    public function setAppMenus(menus:Array<gpui.Menu.OwnedMenu>):Void {
        appMenusValue = menus;
    }

    /**
     * Returns whether any deferred popup currently owns an open interaction context.
     */
    public static function isInDeferredContext(cx:AppContext):Bool {
        for (popover in global(cx).deferredPopovers) {
            if (popover.alive)
                return true;
        }
        return false;
    }

    /**
     * Registers an open deferred popup, which stays registered until the
     * returned token is released.
     */
    public static function registerDeferredPopover(cx:AppContext):DeferredPopover {
        final token = new DeferredPopover();
        final state = globalMut(cx);
        state.deferredPopovers = state.deferredPopovers.filter(popover -> popover.alive);
        state.deferredPopovers.push(token);
        return token;
    }

    /** Number of registrations kept (for tests). */
    @:allow(tests)
    function deferredPopoverCount():Int {
        return deferredPopovers.length;
    }

    /**
     * Confines a selection to its anchor cell and excludes text in other cells.
     * Returns null when nothing is selected, or `[anchor, cursor]`.
     */
    public static function confineToCell(anchorCellAnchor:Null<Point>, anchorCell:Null<Bounds>, painting:Null<Bounds>, anchor:Point, cursor:Point):Null<Array<Point>> {
        if (anchorCellAnchor == null || anchorCell == null || !anchorCellAnchor.equals(anchor)) {
            return [anchor, cursor];
        }
        final cell = anchorCell;
        if (painting == null || !painting.equals(cell)) {
            return null;
        }
        final clamped = new Point(
            Math.min(Math.max(cursor.x, cell.left()), cell.right()),
            Math.min(Math.max(cursor.y, cell.top()), cell.bottom())
        );
        return [anchor, clamped];
    }

}
