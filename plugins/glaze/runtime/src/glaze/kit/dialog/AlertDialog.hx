// Ported from gpui-kit 0.8.1: crates/component/src/dialog/alert_dialog.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.dialog;

import glaze.AnyElement;
import glaze.App;
import glaze.ClickEvent;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.Pixels;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.button.Button.ButtonVariant;
import glaze.kit.dialog.Dialog.DialogButtonProps;

import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;
using glaze.kit.WindowExt;

/**
 * AlertDialog is a modal dialog that interrupts the user with important content
 * and expects a response.
 *
 * It is built on top of the Dialog component with opinionated defaults:
 * - Footer buttons are center-aligned (vs right-aligned in Dialog)
 * - Icon is optional (disabled by default)
 * - Simplified API for common alert scenarios
 * - Uses declarative DialogHeader, DialogTitle, DialogDescription, and DialogFooter components
 * - Supports both imperative (`window.openAlertDialog`) and declarative
 *   (`trigger` and `content`) API styles
 */
@:allow(glaze.kit, tests)
class AlertDialog implements RenderOnce implements Styled implements ParentElement {

    var base:Dialog;

    var triggerElement:Null<AnyElement> = null;

    var iconElement:Null<AnyElement> = null;

    var titleElement:Null<AnyElement> = null;

    var descriptionElement:Null<AnyElement> = null;

    final childElements:Array<AnyElement> = [];

    /**
     * Create a new AlertDialog.
     *
     * By default, the dialog is not overlay closable with a OK button.
     */
    public function new(cx:App) {
        base = new Dialog(cx)
            .withBaseAlertDialog(new glaze.kit.base.AlertDialog(cx))
            .closeButton(false);
    }

    public inline function style():StyleRefinement {
        return base.dialogStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):AlertDialog {
        if (child != null) childElements.push(child);
        return this;
    }

    /**
     * Set to use confirm dialog, with OK and Cancel buttons.
     *
     * The default of `AlertDialog` has OK button.
     */
    public function confirm():AlertDialog {
        base.buttonPropsValue.showCancelValue = true;
        return this;
    }

    /**
     * Sets the trigger element for the alert dialog.
     *
     * When a trigger is set, the dialog will render as a trigger element that
     * opens the dialog when clicked. Use `content()` with it: `title`,
     * `description`, `icon` and `buttonProps` are ignored with a trigger.
     */
    public function trigger(trigger:IntoElement):AlertDialog {
        triggerElement = trigger;
        return this;
    }

    /**
     * Sets the content builder for declarative API (`DialogHeader`,
     * `DialogTitle`, `DialogDescription`, `DialogFooter`), typically used
     * together with `trigger()`.
     */
    public function content(builder:(DialogContent, Window, App) -> DialogContent):AlertDialog {
        base = base.content(builder);
        return this;
    }

    /**
     * Sets the footer for declarative API.
     *
     * If not set, a default footer with OK and optional Cancel button will be used.
     */
    public function footer(footer:IntoElement):AlertDialog {
        base = base.footer(footer);
        return this;
    }

    function debugAssertNoTrigger():Void {
        #if debug
        if (!(triggerElement == null && base.contentBuilder == null)) {
            throw 'Cannot set this property when trigger is used. Use content() to define dialog content instead.';
        }
        #end
    }

    /** Sets the icon of the alert dialog, default is null. */
    public function icon(icon:IntoElement):AlertDialog {
        debugAssertNoTrigger();
        iconElement = icon;
        return this;
    }

    /** Sets the title of the alert dialog. */
    public function title(title:IntoElement):AlertDialog {
        debugAssertNoTrigger();
        titleElement = title;
        return this;
    }

    /** Sets the description of the alert dialog. */
    public function description(description:IntoElement):AlertDialog {
        debugAssertNoTrigger();
        descriptionElement = description;
        return this;
    }

    /**
     * Set the button props of the alert dialog.
     *
     * It overrides only the fields `buttonProps` sets, so the Cancel button
     * `confirm` asked for and callbacks set earlier survive, whatever the call
     * order.
     */
    public function buttonProps(buttonProps:DialogButtonProps):AlertDialog {
        debugAssertNoTrigger();
        base = base.buttonProps(buttonProps);
        return this;
    }

    /** Sets the text of the OK button. Default is `OK`. */
    public function okText(okText:String):AlertDialog {
        base.buttonPropsValue.okTextValue = okText;
        return this;
    }

    /** Sets the variant of the OK button. Default is `ButtonVariant.Primary`. */
    public function okVariant(okVariant:ButtonVariant):AlertDialog {
        base.buttonPropsValue.okVariantValue = okVariant;
        return this;
    }

    /** Sets the text of the Cancel button. Default is `Cancel`. */
    public function cancelText(cancelText:String):AlertDialog {
        base.buttonPropsValue.cancelTextValue = cancelText;
        return this;
    }

    /** Sets the variant of the Cancel button. Default is `ButtonVariant.Default`. */
    public function cancelVariant(cancelVariant:ButtonVariant):AlertDialog {
        base.buttonPropsValue.cancelVariantValue = cancelVariant;
        return this;
    }

    /** Sets the width of the alert dialog. */
    public function width(width:Pixels):AlertDialog {
        base = base.width(width);
        return this;
    }

    /** Show cancel button. Default is false. */
    public function showCancel(showCancel:Bool):AlertDialog {
        base.buttonPropsValue.showCancelValue = showCancel;
        return this;
    }

    /** Alert dialogs never close from a backdrop press (deprecated in Rust). */
    @:deprecated('AlertDialog backdrop dismissal is disabled by design')
    public function overlayClosable(_:Bool):AlertDialog {
        return this;
    }

    /** Set the close button of the alert dialog, defaults to `false`. */
    public function closeButton(closeButton:Bool):AlertDialog {
        base = base.closeButton(closeButton);
        return this;
    }

    /** Set whether to support keyboard esc to close the dialog, defaults to `true`. */
    public function keyboard(keyboard:Bool):AlertDialog {
        base = base.keyboard(keyboard);
        return this;
    }

    /**
     * Sets the top offset of the alert dialog.
     *
     * Without this, the surface keeps the `Dialog` default: a tenth of the
     * viewport height below the top edge.
     */
    public function marginTop(marginTop:Pixels):AlertDialog {
        base = base.marginTop(marginTop);
        return this;
    }

    /**
     * Centers the alert dialog vertically in the window, whatever its
     * height, in place of the `marginTop` offset.
     */
    public function centered():AlertDialog {
        base = base.centered();
        return this;
    }

    /**
     * Sets how the alert dialog enters, defaulting to `DialogEntrance.SlideDown`.
     */
    public function entrance(entrance:DialogEntrance):AlertDialog {
        base = base.entrance(entrance);
        return this;
    }

    /**
     * Sets the callback for when the alert dialog is closed.
     *
     * Called after `onOk` or `onCancel` callback.
     */
    public function onClose(onClose:(ClickEvent, Window, App) -> Void):AlertDialog {
        base = base.onClose(onClose);
        return this;
    }

    /**
     * Sets the callback for when the OK/action button is clicked.
     *
     * The callback should return `true` to close the dialog, if return `false` the dialog will not be closed.
     */
    public function onOk(onOk:(ClickEvent, Window, App) -> Bool):AlertDialog {
        base = base.onOk(onOk);
        return this;
    }

    /**
     * Sets the callback for when the alert dialog has been canceled.
     *
     * The callback should return `true` to close the dialog, if return `false` the dialog will not be closed.
     */
    public function onCancel(onCancel:(ClickEvent, Window, App) -> Bool):AlertDialog {
        base = base.onCancel(onCancel);
        return this;
    }

    /**
     * Build the styled dialog surface around the Base alert-dialog host.
     */
    function buildSurface(window:Window, cx:App):Dialog {
        final buttonProps = base.buttonPropsValue.clone();
        final hasTitle = iconElement != null || titleElement != null;
        final hasHeader = hasTitle || descriptionElement != null;
        final hasFooter = base.footerElement != null;

        if (hasHeader) {
            final row = hFlex()
                .gap2()
                .itemsStart();
            if (iconElement != null) row.child(iconElement);
            final column = vFlex()
                .flex1()
                .minW0()
                .gap1();
            if (titleElement != null) column.child(new DialogTitle().child(titleElement));
            if (descriptionElement != null) column.child(new DialogDescription().child(descriptionElement));
            base.header(new DialogHeader().child(row.child(column)));
        }
        base.extend(childElements);
        if (!hasFooter) {
            // Default footer for AlertDialog if user doesn't provide one, with OK and optional Cancel button
            final footer = new DialogFooter();
            if (buttonProps.isCancelShown()) {
                footer.child(buttonProps.renderCancel(window, cx));
            }
            base.footer(footer.child(buttonProps.renderOk(window, cx)));
        }
        return base;
    }

    function renderTrigger(trigger:AnyElement, _:Window, _:App):IntoElement {
        final contentBuilder = base.contentBuilder;
        final style = base.dialogStyle.clone();
        final props = base.props.clone();
        final buttonProps = base.buttonPropsValue.clone();

        return new glaze.kit.base.AlertDialog.AlertDialogTrigger(trigger)
            .onOpen((window, cx) -> {
                window.openDialog(cx, (dialog, _, cx) -> {
                    final dialog = dialog
                        .withBaseAlertDialog(new glaze.kit.base.AlertDialog(cx))
                        .refineStyle(style)
                        .buttonProps(buttonProps.clone())
                        .withProps(props.clone());
                    return contentBuilder != null
                        ? dialog.content((content, window, cx) -> contentBuilder(content, window, cx))
                        : dialog;
                });
            });
    }

    public function render(window:Window, cx:App):IntoElement {
        if (triggerElement != null) {
            // If a trigger is provided, render the trigger element that opens the dialog
            final trigger = triggerElement;
            triggerElement = null;
            return renderTrigger(trigger, window, cx);
        }
        else {
            // Otherwise, render the dialog content directly
            return buildSurface(window, cx);
        }
    }

}
