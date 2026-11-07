// Ported from gpui-kit 0.8.1: crates/base/src/alert_dialog.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.AnyElement;
import gpui.App;
import gpui.ClickEvent;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.ParentElement;
import gpui.Pixels;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.A11y;
import gpui.base.Actions.Cancel;
import gpui.base.Actions.Confirm;
import gpui.base.Dialog;

import gpui.Prelude.*;

using gpui.base.StyledExt;

/**
 * The unstyled alert dialog parts (Rust `alert_part!`).
 */
@:allow(gpui.base)
abstract class AlertDialogPart implements RenderOnce implements Styled implements ParentElement {

    final partStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    final partId:String;

    final occlude:Bool;

    function new(partId:String, occlude:Bool) {
        this.partId = partId;
        this.occlude = occlude;
    }

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function render(_:Window, _:App):IntoElement {
        final element = div().id(partId);
        // Presses on the popup stay off the backdrop behind it.
        if (occlude) element.occlude();
        element.extend(childElements);
        return element.refineStyle(partStyle);
    }

}

class AlertDialogBackdrop extends AlertDialogPart {

    public function new() {
        super('alert-dialog-backdrop', false);
    }

}

class AlertDialogPopup extends AlertDialogPart {

    public function new() {
        super('alert-dialog-popup', true);
    }

}

class AlertDialogTitle extends AlertDialogPart {

    public function new() {
        super('alert-dialog-title', false);
    }

}

class AlertDialogDescription extends AlertDialogPart {

    public function new() {
        super('alert-dialog-description', false);
    }

}

class AlertDialogTrigger implements RenderOnce {

    final trigger:AnyElement;

    var openRequest:(Window, App) -> Void = (_, _) -> {};

    var handleValue:Null<DialogHandle> = null;

    public function new(trigger:IntoElement) {
        this.trigger = trigger;
    }

    public function onOpen(open:(Window, App) -> Void):AlertDialogTrigger {
        openRequest = open;
        return this;
    }

    public function handle(handle:DialogHandle):AlertDialogTrigger {
        handleValue = handle;
        return this;
    }

    public function render(_:Window, _:App):IntoElement {
        final handle = handleValue;
        final open = openRequest;
        return div()
            .onMouseDown(Left, (_, window, cx) -> {
                if (handle != null) {
                    handle.setOpen(true, TriggerPress, window, cx);
                }
                open(window, cx);
                cx.stopPropagation();
            })
            .child(trigger);
    }

}

/**
 * The parts that dispatch `Cancel` on click (Rust `alert_close_part!`).
 */
@:allow(gpui.base)
abstract class AlertDialogClosePart implements RenderOnce implements Styled implements ParentElement {

    final partStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    final partId:String;

    function new(partId:String) {
        this.partId = partId;
    }

    public inline function style():StyleRefinement {
        return partStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function render(_:Window, _:App):IntoElement {
        final element = div()
            .id(partId)
            .onClick((_, window, cx) -> window.dispatchAction(new Cancel(), cx));
        element.extend(childElements);
        return element.refineStyle(partStyle);
    }

}

class AlertDialogClose extends AlertDialogClosePart {

    public function new() {
        super('alert-dialog-close');
    }

}

class AlertDialogCancel extends AlertDialogClosePart {

    public function new() {
        super('alert-dialog-cancel');
    }

}

/**
 * Wrapper that dispatches the alert dialog's confirm action.
 */
class AlertDialogAction implements RenderOnce implements Styled implements ParentElement {

    final actionStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return actionStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function render(_:Window, _:App):IntoElement {
        final element = div()
            .id('alert-dialog-action')
            .onClick((_, window, cx) -> window.dispatchAction(new Confirm(false), cx));
        element.extend(childElements);
        return element.refineStyle(actionStyle);
    }

}

/**
 * Alert-dialog specialization of the Base modal host.
 */
class AlertDialog implements RenderOnce implements Styled implements ParentElement {

    /** The wrapped host (Rust `AlertDialog(Dialog)`). */
    @:allow(gpui.base, gpui.component)
    var inner:Dialog;

    public function new(cx:App) {
        inner = new Dialog(cx)
            .role(Role.AlertDialog)
            .closeOnBackdropPress(false);
    }

    public inline function style():StyleRefinement {
        return inner.style();
    }

    public function extend(elements:Array<AnyElement>):Void {
        inner.extend(elements);
    }

    public function open(open:Bool):AlertDialog {
        inner = inner.open(open);
        return this;
    }

    public function handle(handle:DialogHandle):AlertDialog {
        inner = inner.handle(handle);
        return this;
    }

    public function onOpenChange(handler:(Bool, DialogChangeReason, Window, App) -> Void):AlertDialog {
        inner = inner.onOpenChange(handler);
        return this;
    }

    public function backdrop(element:IntoElement):AlertDialog {
        inner = inner.backdrop(element);
        return this;
    }

    public function popup(element:IntoElement):AlertDialog {
        inner = inner.popup(element);
        return this;
    }

    public function closeOnEscape(value:Bool):AlertDialog {
        inner = inner.closeOnEscape(value);
        return this;
    }

    public function dismissBelowY(value:Pixels):AlertDialog {
        inner = inner.dismissBelowY(value);
        return this;
    }

    public function onOk(handler:(ClickEvent, Window, App) -> Bool):AlertDialog {
        inner = inner.onOk(handler);
        return this;
    }

    public function onCancel(handler:(ClickEvent, Window, App) -> Bool):AlertDialog {
        inner = inner.onCancel(handler);
        return this;
    }

    public function onClose(handler:(ClickEvent, Window, App) -> Void):AlertDialog {
        inner = inner.onClose(handler);
        return this;
    }

    /** Hidden in the Rust docs. */
    public function layer(index:Int, topmost:Bool):AlertDialog {
        inner = inner.layer(index, topmost);
        return this;
    }

    /** Hidden in the Rust docs. */
    public function focusHandle(value:FocusHandle):AlertDialog {
        inner = inner.focusHandle(value);
        return this;
    }

    /** Hidden in the Rust docs. */
    public function requestClose(handler:(Bool, Window, App) -> Void):AlertDialog {
        inner = inner.requestClose(handler);
        return this;
    }

    /** The accessibility properties the host exports. */
    public inline function a11y():A11y {
        return inner.a11y;
    }

    /** Rust `IntoElement` returns the host's element. */
    public function render(window:Window, cx:App):IntoElement {
        return inner.render(window, cx);
    }

}
