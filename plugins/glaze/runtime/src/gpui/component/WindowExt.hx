// Ported from gpui-kit 0.8.1: crates/component/src/window_ext.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component;

import gpui.App;
import gpui.ElementIdArg;
import gpui.Entity;
import gpui.Window;
import gpui.base.Geometry.Placement;
import gpui.component.dialog.AlertDialog;
import gpui.component.dialog.Dialog;
import gpui.component.notification.Notification;
import gpui.component.sheet.Sheet;

/**
 * Dialog, sheet and notification helpers on `Window`, as a static
 * extension: `using gpui.component.WindowExt;` then
 * `window.openDialog(cx, (dialog, window, cx) -> dialog.title('Title'))`
 * (Rust `WindowExt`).
 *
 * Rust's generic notification ids (`remove_notification::<T>()`) take the
 * marker class here: `window.removeNotification(MyKind, cx)`.
 */
class WindowExt {

    /**
     * Opens a Sheet at right placement.
     *
     * The builder follows the same rendering contract as `openDialog`: it may
     * run again when the sheet layer is rebuilt. Keep it cheap and create
     * persistent entities before opening, not inside the builder.
     */
    public static inline function openSheet(window:Window, cx:App, build:(Sheet, Window, App) -> Sheet):Void {
        openSheetAt(window, Right, cx, build);
    }

    /**
     * Opens a Sheet at the given placement.
     *
     * The builder follows the same rendering contract as `openDialog`.
     */
    public static function openSheetAt(window:Window, placement:Placement, cx:App, build:(Sheet, Window, App) -> Sheet):Void {
        WindowState.update(window, cx, (root, window, cx) -> root.openSheetAt(placement, build, window, cx));
    }

    /**
     * Return true, if there is an active Sheet.
     */
    public static function hasActiveSheet(window:Window, cx:App):Bool {
        return WindowState.read(window).activeSheet != null;
    }

    /**
     * Closes the active Sheet.
     */
    public static function closeSheet(window:Window, cx:App):Void {
        WindowState.update(window, cx, (root, window, cx) -> root.closeSheet(window, cx));
    }

    /**
     * Opens a Dialog.
     *
     * The builder is a render closure, not a one-shot constructor. It may
     * run again when the dialog layer is rebuilt while the dialog is open.
     * Keep it cheap and idempotent: create persistent entities (an input
     * state, a child view) before opening and capture their handles in the
     * builder.
     *
     * `openDialog` initially focuses the dialog shell, replacing any focus
     * set before the call. To choose initial content focus, set it only on
     * the builder's first invocation, with a guard captured separately for
     * each opening.
     */
    public static function openDialog(window:Window, cx:App, build:(Dialog, Window, App) -> Dialog):Void {
        WindowState.update(window, cx, (root, window, cx) -> root.openDialog(build, window, cx));
    }

    /**
     * Opens an AlertDialog.
     *
     * This is a convenience method for opening an alert dialog with
     * opinionated defaults. The builder follows the same rendering contract
     * as `openDialog`.
     */
    public static function openAlertDialog(window:Window, cx:App, build:(AlertDialog, Window, App) -> AlertDialog):Void {
        openDialog(window, cx, (_, window, cx) -> build(new AlertDialog(cx), window, cx).buildSurface(window, cx));
    }

    /**
     * Return true, if there is an active Dialog.
     *
     * A dialog that is playing its exit transition is no longer active: it
     * accepts no input and will unmount when the transition finishes.
     */
    public static function hasActiveDialog(window:Window, cx:App):Bool {
        for (dialog in WindowState.read(window).activeDialogs) {
            if (!dialog.closing) return true;
        }
        return false;
    }

    /**
     * Closes the last active Dialog.
     */
    public static function closeDialog(window:Window, cx:App):Void {
        WindowState.update(window, cx, (root, window, cx) -> root.closeDialog(window, cx));
    }

    /**
     * Closes all active Dialogs.
     */
    public static function closeAllDialogs(window:Window, cx:App):Void {
        WindowState.update(window, cx, (root, window, cx) -> root.closeAllDialogs(window, cx));
    }

    /**
     * Pushes a notification to the notification list.
     */
    public static function pushNotification(window:Window, note:IntoNotification, cx:App):Void {
        final note:Notification = note;
        WindowState.update(window, cx, (root, window, cx) -> root.pushNotification(note, window, cx));
    }

    /**
     * Removes all notifications whose id matches `type`, including ones
     * registered with either `Notification.withId` or `Notification.id1` (any key).
     */
    public static function removeNotification(window:Window, type:Class<Dynamic>, cx:App):Void {
        WindowState.update(window, cx, (root, window, cx) -> root.removeNotification(type, window, cx));
    }

    /**
     * Removes a single notification matching the given `type` and `key`
     * (paired with `Notification.id1`).
     */
    public static function removeNotification1(window:Window, type:Class<Dynamic>, key:ElementIdArg, cx:App):Void {
        WindowState.update(window, cx, (root, window, cx) -> root.removeNotification1(type, key, window, cx));
    }

    /**
     * Clears all notifications.
     */
    public static function clearNotifications(window:Window, cx:App):Void {
        WindowState.update(window, cx, (root, window, cx) -> root.clearNotifications(window, cx));
    }

    /**
     * Returns the notifications.
     */
    public static function notifications(window:Window, cx:App):Array<Entity<Notification>> {
        return WindowState.read(window).notification.read(cx).notifications();
    }

    /**
     * Whether an input of this window holds the focus.
     */
    public static inline function hasFocusedInput(window:Window, cx:App):Bool {
        return focusedInput(window, cx) != null;
    }

    /**
     * The input that holds the focus, if any (`Input`, `Textarea`, `Editor`
     * or `OtpInput` state).
     */
    public static function focusedInput(window:Window, cx:App):Null<gpui.component.input.AnyInputState> {
        final state = WindowState.read(window).focusedInput;
        if (state == null) {
            return null;
        }
        if (state.focusHandle(cx).isFocused(window)) {
            return state;
        }

        // An input removed from the tree while focused never re-renders to
        // unregister itself; drop the stale registration lazily.
        WindowState.tryUpdate(window, cx, (root, _, cx) -> {
            if (state.equals(root.focusedInput)) {
                root.focusedInput = null;
                cx.notify();
            }
            return null;
        });
        return null;
    }

}
