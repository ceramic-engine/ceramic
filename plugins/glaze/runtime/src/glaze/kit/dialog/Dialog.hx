// Ported from gpui-kit 0.8.1: crates/component/src/dialog/dialog.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.dialog;

import glaze.Action;
import glaze.Anchor;
import glaze.AnyElement;
import glaze.App;
import glaze.BoxShadow;
import glaze.ClickEvent;
import glaze.DefiniteLengthTools;
import glaze.FocusHandle;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.Pixels;
import glaze.Point;
import glaze.RenderOnce;
import glaze.SpringMath.f32;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.Actions.Cancel;
import glaze.kit.base.Actions.Confirm;
import glaze.kit.base.Positioner;
import glaze.kit.base.animation.Easings;
import glaze.kit.base.motion.Transition;
import glaze.kit.IconName;
import glaze.kit.TitleBar;
import glaze.kit.WindowBorder;
import glaze.kit.WindowState;
import glaze.kit.button.Button;
import glaze.kit.button.Button.ButtonVariant;
import glaze.kit.dialog.DialogEntrance.EntranceSurface;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.ElementExt;
using glaze.kit.base.Observe;
using glaze.kit.base.StyledExt;
using glaze.kit.WindowExt;
using glaze.kit.scroll.Scrollable;

private typedef OkHandler = (ClickEvent, Window, App) -> Bool;
private typedef CancelHandler = (ClickEvent, Window, App) -> Bool;
private typedef CloseHandler = (ClickEvent, Window, App) -> Void;
private typedef ContentBuilderFn = (DialogContent, Window, App) -> DialogContent;

/**
 * Dialog button props.
 *
 * Every field is unset until a builder sets it, and an unset field falls back
 * to its documented default when the dialog renders. Handing a value to
 * `Dialog.buttonProps` or `AlertDialog.buttonProps` therefore overrides only
 * the fields that value sets: whatever the dialog already carries survives.
 *
 * Rust builders take the value and return it: here they set the field and
 * return the same object, so share a props value only through `clone()`.
 */
@:allow(glaze.kit, tests)
class DialogButtonProps {

    var okTextValue:Null<String> = null;
    var okVariantValue:Null<ButtonVariant> = null;
    var cancelTextValue:Null<String> = null;
    var cancelVariantValue:Null<ButtonVariant> = null;
    var showCancelValue:Null<Bool> = null;
    var onOkValue:Null<OkHandler> = null;
    var onCancelValue:Null<CancelHandler> = null;
    var onCloseValue:Null<CloseHandler> = null;

    public function new() {}

    public function clone():DialogButtonProps {
        final props = new DialogButtonProps();
        props.merge(this);
        return props;
    }

    /** Sets the text of the OK button. Default is `OK`. */
    public function okText(okText:String):DialogButtonProps {
        this.okTextValue = okText;
        return this;
    }

    /** Sets the variant of the OK button. Default is `ButtonVariant.Primary`. */
    public function okVariant(okVariant:ButtonVariant):DialogButtonProps {
        this.okVariantValue = okVariant;
        return this;
    }

    /** Sets the text of the Cancel button. Default is `Cancel`. */
    public function cancelText(cancelText:String):DialogButtonProps {
        this.cancelTextValue = cancelText;
        return this;
    }

    /** Sets the variant of the Cancel button. Default is `ButtonVariant.Default`. */
    public function cancelVariant(cancelVariant:ButtonVariant):DialogButtonProps {
        this.cancelVariantValue = cancelVariant;
        return this;
    }

    /** Sets whether to show the Cancel button. Default is `false`. */
    public function showCancel(showCancel:Bool):DialogButtonProps {
        this.showCancelValue = showCancel;
        return this;
    }

    /**
     * Sets the callback for when the dialog is has been confirmed.
     *
     * The callback should return `true` to close the dialog, if return `false` the dialog will not be closed.
     */
    public function onOk(onOk:(ClickEvent, Window, App) -> Bool):DialogButtonProps {
        this.onOkValue = onOk;
        return this;
    }

    /**
     * Sets the callback for when the dialog is has been canceled.
     *
     * The callback should return `true` to close the dialog, if return `false` the dialog will not be closed.
     */
    public function onCancel(onCancel:(ClickEvent, Window, App) -> Bool):DialogButtonProps {
        this.onCancelValue = onCancel;
        return this;
    }

    /** Takes over every field `other` sets and keeps the rest. */
    function merge(other:DialogButtonProps):Void {
        if (other.okTextValue != null) okTextValue = other.okTextValue;
        if (other.okVariantValue != null) okVariantValue = other.okVariantValue;
        if (other.cancelTextValue != null) cancelTextValue = other.cancelTextValue;
        if (other.cancelVariantValue != null) cancelVariantValue = other.cancelVariantValue;
        if (other.showCancelValue != null) showCancelValue = other.showCancelValue;
        if (other.onOkValue != null) onOkValue = other.onOkValue;
        if (other.onCancelValue != null) onCancelValue = other.onCancelValue;
        if (other.onCloseValue != null) onCloseValue = other.onCloseValue;
    }

    /** Whether the default footer renders a Cancel button. Default is `false`. */
    function isCancelShown():Bool {
        return showCancelValue != null ? showCancelValue : false;
    }

    /** The confirm callback, defaulting to one that closes the dialog. */
    function okHandler():OkHandler {
        return onOkValue != null ? onOkValue : (_, _, _) -> true;
    }

    /** The cancel callback, defaulting to one that closes the dialog. */
    function cancelHandler():CancelHandler {
        return onCancelValue != null ? onCancelValue : (_, _, _) -> true;
    }

    /** The close callback, defaulting to one that does nothing. */
    function closeHandler():CloseHandler {
        return onCloseValue != null ? onCloseValue : (_, _, _) -> {};
    }

    function renderOk(_:Window, _:App):IntoElement {
        final okText = this.okTextValue != null ? this.okTextValue : I18n.t('Dialog.ok');
        return new DialogButton('dialog-ok-anchor', new Button('ok')
            .label(okText)
            .withVariant(okVariantValue != null ? okVariantValue : Primary), new Confirm(false));
    }

    function renderCancel(_:Window, _:App):IntoElement {
        final cancelText = this.cancelTextValue != null ? this.cancelTextValue : I18n.t('Dialog.cancel');
        return new DialogButton('dialog-cancel-anchor', new Button('cancel')
            .label(cancelText)
            .withVariant(cancelVariantValue != null ? cancelVariantValue : Default), new Cancel());
    }

}

/**
 * A default dialog button: activating it dispatches `action` on the dialog
 * it sits in, whatever holds focus at that moment.
 */
private class DialogButton implements RenderOnce {

    /** Distinct per button: OK and Cancel render as siblings in one scope. */
    final anchorKey:String;

    final button:Button;

    final action:Action;

    public function new(anchorKey:String, button:Button, action:Action) {
        this.anchorKey = anchorKey;
        this.button = button;
        this.action = action;
    }

    public function render(window:Window, cx:App):IntoElement {
        final anchor = new DialogDispatchAnchor(anchorKey, window, cx);
        final action = this.action;
        return button
            .child(anchor.element())
            .onClick((_, window, cx) -> anchor.dispatch(action, window, cx));
    }

}

@:allow(glaze.kit, tests)
class DialogProps {

    var width:Pixels = 448.;
    var maxWidth:Null<Pixels> = null;
    var marginTop:Null<Pixels> = null;
    var centered:Bool = false;
    var closeButton:Bool = true;

    var overlay:Bool = true;
    var overlayClosable:Bool = true;
    var overlayVisible:Bool = false;
    var keyboard:Bool = true;
    var entrance:DialogEntrance = SlideDown;

    public function new() {}

    public function clone():DialogProps {
        final props = new DialogProps();
        props.width = width;
        props.maxWidth = maxWidth;
        props.marginTop = marginTop;
        props.centered = centered;
        props.closeButton = closeButton;
        props.overlay = overlay;
        props.overlayClosable = overlayClosable;
        props.overlayVisible = overlayVisible;
        props.keyboard = keyboard;
        props.entrance = entrance;
        return props;
    }

}

/**
 * The Base host of a dialog: a plain `Dialog`, or an `AlertDialog` (whose
 * backdrop never closes it). Rust's enum maps every builder over both
 * variants; the alert dialog delegates them to the `Dialog` it wraps.
 */
private class BaseDialogRoot {

    final dialog:Null<glaze.kit.base.Dialog>;

    final alert:Null<glaze.kit.base.AlertDialog>;

    public function new(?dialog:glaze.kit.base.Dialog, ?alert:glaze.kit.base.AlertDialog) {
        this.dialog = dialog;
        this.alert = alert;
    }

    inline function host():glaze.kit.base.Dialog {
        return dialog != null ? dialog : @:privateAccess alert.inner;
    }

    public function layer(index:Int, topmost:Bool):BaseDialogRoot {
        host().layer(index, topmost);
        return this;
    }

    public function focusHandle(focus:FocusHandle):BaseDialogRoot {
        host().focusHandle(focus);
        return this;
    }

    public function closeOnEscape(value:Bool):BaseDialogRoot {
        host().closeOnEscape(value);
        return this;
    }

    public function closeOnBackdropPress(value:Bool):BaseDialogRoot {
        if (dialog != null) dialog.closeOnBackdropPress(value);
        return this;
    }

    public function dismissBelowY(value:Pixels):BaseDialogRoot {
        host().dismissBelowY(value);
        return this;
    }

    public function backdrop(element:IntoElement):BaseDialogRoot {
        host().backdrop(element);
        return this;
    }

    public function popup(element:IntoElement):BaseDialogRoot {
        host().popup(element);
        return this;
    }

    public function onOk(handler:(ClickEvent, Window, App) -> Bool):BaseDialogRoot {
        host().onOk(handler);
        return this;
    }

    public function onCancel(handler:(ClickEvent, Window, App) -> Bool):BaseDialogRoot {
        host().onCancel(handler);
        return this;
    }

    public function onClose(handler:(ClickEvent, Window, App) -> Void):BaseDialogRoot {
        host().onClose(handler);
        return this;
    }

    public function requestClose(handler:(Bool, Window, App) -> Void):BaseDialogRoot {
        host().requestClose(handler);
        return this;
    }

    public function intoElement():IntoElement {
        return dialog != null ? (dialog : IntoElement) : (alert : IntoElement);
    }

}

/**
 * The shared entrance and exit sample for a mounted dialog.
 *
 * Built by the window dialog layer with stable per-dialog identity.
 */
@:allow(glaze.kit, tests)
class DialogMotion {

    final visibility:Float;

    final closing:Bool;

    function new(visibility:Float, closing:Bool) {
        this.visibility = visibility;
        this.closing = closing;
    }

}

/**
 * A modal to display content in a dialog box.
 */
@:allow(glaze.kit, tests)
class Dialog implements RenderOnce implements Styled implements ParentElement {

    /** The legacy entrance and exit duration, in seconds. */
    public static final ANIMATION_DURATION:Float = 0.25;

    var base:Null<BaseDialogRoot>;

    var dialogStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    var triggerElement:Null<AnyElement> = null;

    var titleElement:Null<AnyElement> = null;

    var headerElement:Null<AnyElement> = null;

    var footerElement:Null<AnyElement> = null;

    var contentBuilder:Null<ContentBuilderFn> = null;

    var props:DialogProps = new DialogProps();

    var buttonPropsValue:DialogButtonProps = new DialogButtonProps();

    /** This will be change when open the dialog, the focus handle is create when open the dialog. */
    var focusHandle:FocusHandle;

    var layerIx:Int = 0;

    var selectionScope:glaze.kit.base.TextSelectionScopeId = glaze.kit.base.TextSelectionScopeId.DEFAULT;

    var motion:Null<DialogMotion> = null;

    var id:Int = 0;

    /**
     * Create a new dialog.
     */
    public function new(cx:App) {
        base = new BaseDialogRoot(new glaze.kit.base.Dialog(cx));
        focusHandle = cx.focusHandle();
    }

    public inline function style():StyleRefinement {
        return dialogStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):Dialog {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):Dialog {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    /**
     * Sets the trigger element for the dialog.
     *
     * When a trigger is set, the dialog will render as a trigger button that opens the dialog when clicked.
     */
    public function trigger(trigger:IntoElement):Dialog {
        triggerElement = trigger;
        return this;
    }

    /**
     * Sets the content of the dialog.
     */
    public function content(builder:(DialogContent, Window, App) -> DialogContent):Dialog {
        contentBuilder = builder;
        return this;
    }

    /**
     * Sets the title of the dialog.
     */
    public function title(title:IntoElement):Dialog {
        titleElement = title;
        return this;
    }

    /**
     * Sets the header of the dialog, rendered above the title and content.
     */
    function header(header:IntoElement):Dialog {
        headerElement = header;
        return this;
    }

    /**
     * Sets the footer of the dialog, the footer will render at the bottom of
     * the dialog, usually for action buttons.
     *
     * A plain `Dialog` never renders buttons from `buttonProps`: the props
     * only install the callbacks behind the `Confirm` and `Cancel` actions.
     * Compose the action buttons yourself (typically with a `DialogFooter`)
     * or use an `AlertDialog`, which builds a default footer from
     * `buttonProps` when no footer is set.
     */
    public function footer(footer:IntoElement):Dialog {
        footerElement = footer;
        return this;
    }

    /**
     * Set the button props of the dialog.
     *
     * This overrides only the fields `buttonProps` sets; the rest of the
     * dialog's button configuration is kept, so the call order does not
     * matter.
     */
    public function buttonProps(buttonProps:DialogButtonProps):Dialog {
        buttonPropsValue.merge(buttonProps);
        return this;
    }

    function withBaseAlertDialog(base:glaze.kit.base.AlertDialog):Dialog {
        this.base = new BaseDialogRoot(null, base);
        props.overlayClosable = false;
        return this;
    }

    /**
     * Sets the callback for when the dialog is closed.
     *
     * Called after `onOk` or `onCancel` callback.
     */
    public function onClose(onClose:(ClickEvent, Window, App) -> Void):Dialog {
        buttonPropsValue.onCloseValue = onClose;
        return this;
    }

    /**
     * Sets the callback for when the dialog is has been confirmed.
     *
     * The callback should return `true` to close the dialog, if return `false` the dialog will not be closed.
     */
    public function onOk(onOk:(ClickEvent, Window, App) -> Bool):Dialog {
        buttonPropsValue = buttonPropsValue.onOk(onOk);
        return this;
    }

    /**
     * Sets the callback for when the dialog is has been canceled.
     *
     * The callback should return `true` to close the dialog, if return `false` the dialog will not be closed.
     */
    public function onCancel(onCancel:(ClickEvent, Window, App) -> Bool):Dialog {
        buttonPropsValue = buttonPropsValue.onCancel(onCancel);
        return this;
    }

    /** Sets the false to hide close icon, default: true */
    public function closeButton(closeButton:Bool):Dialog {
        props.closeButton = closeButton;
        return this;
    }

    /** Set the top offset of the dialog, defaults to null, will use the 1/10 of the viewport height. */
    public function marginTop(marginTop:Pixels):Dialog {
        props.marginTop = marginTop;
        return this;
    }

    /**
     * Centers the dialog vertically in the window, whatever its height, in
     * place of the `marginTop` offset.
     */
    public function centered():Dialog {
        props.centered = true;
        return this;
    }

    /**
     * Sets the width of the dialog, defaults to 448px.
     *
     * The dialog is never wider than the viewport minus a margin on each side.
     * Like Rust, this shadows `Styled.w`.
     */
    public function w(width:Pixels):Dialog {
        props.width = width;
        return this;
    }

    /**
     * Sets the width of the dialog, defaults to 448px.
     *
     * The dialog is never wider than the viewport minus a margin on each side.
     */
    public function width(width:Pixels):Dialog {
        props.width = width;
        return this;
    }

    /** Set the maximum width of the dialog, defaults to null (shadows `Styled.maxW`). */
    public function maxW(maxWidth:Pixels):Dialog {
        props.maxWidth = maxWidth;
        return this;
    }

    /** Set the overlay of the dialog, defaults to `true`. */
    public function overlay(overlay:Bool):Dialog {
        props.overlay = overlay;
        return this;
    }

    /**
     * Set the overlay closable of the dialog, defaults to `true`.
     *
     * When the overlay is clicked, the dialog will be closed.
     */
    public function overlayClosable(overlayClosable:Bool):Dialog {
        props.overlayClosable = overlayClosable;
        return this;
    }

    /** Set whether to support keyboard esc to close the dialog, defaults to `true`. */
    public function keyboard(keyboard:Bool):Dialog {
        props.keyboard = keyboard;
        return this;
    }

    /**
     * Sets how the dialog enters, defaulting to `DialogEntrance.SlideDown`.
     *
     * This controls the surface and backdrop together, and closing animates
     * both back out. Reduced motion skips both and shows the final state
     * immediately, as does `DialogEntrance.None`.
     */
    public function entrance(entrance:DialogEntrance):Dialog {
        props.entrance = entrance;
        return this;
    }

    /**
     * How long the exit transition runs, in seconds; zero closes in one frame.
     *
     * Mirrors the entrance: `DialogEntrance.None`, reduced motion, and a
     * zero theme duration leave nothing to animate out.
     */
    function exitDuration(cx:App):Float {
        if (cx.reduceMotion()) {
            return 0.;
        }
        return switch props.entrance {
            case None: 0.;
            case SlideDown: ANIMATION_DURATION;
            case _: Theme.global(cx).motionTokens().durationNormal;
        }
    }

    function motionTransition(cx:App):Transition {
        final transition = new Transition(exitDuration(cx));
        // Use the same curve in both directions: changing the curve at the
        // reversal would resample the entrance at a different position.
        if (props.entrance == SlideDown) {
            return transition.ease(Easings.cubicBezier(1. / 3., 0.72, 2. / 3., 1.));
        }
        else {
            final easing = Theme.global(cx).motionTokens().easingEnter;
            return transition.ease(delta -> {
                final value = easing.sample(delta);
                return value < 0. ? 0. : value > 1. ? 1. : value;
            });
        }
    }

    function hasOverlay():Bool {
        return props.overlay;
    }

    function withProps(props:DialogProps):Dialog {
        this.props = props;
        return this;
    }

    static function deferCloseDialog(window:Window, cx:App):Void {
        WindowState.update(window, cx, (root, window, cx) -> root.deferCloseDialog(window, cx));
    }

    static function overlayColor(overlay:Bool, cx:App):Hsla {
        if (!overlay) {
            return hsla(0., 0., 0., 0.);
        }
        return Theme.global(cx).overlay;
    }

    static function dialogShadow(delta:Float):Array<BoxShadow> {
        final first = new BoxShadow(glaze.Prelude.px(0.), glaze.Prelude.px(20.), hsla(0., 0., 0., f32(0.1 * delta)));
        first.blurRadius = glaze.Prelude.px(25.);
        first.spreadRadius = glaze.Prelude.px(-5.);
        final second = new BoxShadow(glaze.Prelude.px(0.), glaze.Prelude.px(8.), hsla(0., 0., 0., f32(0.1 * delta)));
        second.blurRadius = glaze.Prelude.px(10.);
        second.spreadRadius = glaze.Prelude.px(-6.);
        return [first, second];
    }

    function renderTrigger(trigger:AnyElement, _:Window, _:App):IntoElement {
        final contentBuilder = this.contentBuilder;
        final style = dialogStyle.clone();
        final props = this.props.clone();
        final buttonProps = buttonPropsValue.clone();

        return new glaze.kit.base.Dialog.DialogTrigger(trigger)
            .onOpen((window, cx) -> {
                window.openDialog(cx, (dialog, _, _) -> dialog
                    .refineStyle(style)
                    .buttonProps(buttonProps.clone())
                    .withProps(props.clone())
                    .content((content, window, cx) -> contentBuilder != null ? contentBuilder(content, window, cx) : content));
            });
    }

    public function render(window:Window, cx:App):IntoElement {
        if (triggerElement != null) {
            final trigger = triggerElement;
            triggerElement = null;
            return renderTrigger(trigger, window, cx);
        }

        final layerIx = this.layerIx;
        final onClose = buttonPropsValue.closeHandler();
        final onOk = buttonPropsValue.okHandler();
        final onCancel = buttonPropsValue.cancelHandler();
        final theme = Theme.global(cx);

        final windowPaddings = WindowBorder.windowPaddings(window);
        final viewport = window.viewportSize();
        final viewWidth:Float = viewport.width - (windowPaddings.left + windowPaddings.right);
        final viewHeight:Float = viewport.height - (windowPaddings.top + windowPaddings.bottom);
        // The dialog keeps this much of the viewport clear around its edges,
        // so a small window shrinks the surface instead of letting it run off
        // the window. A dialog that fits keeps `marginTop` (a tenth of the
        // viewport by default); an overflowing one is snapped up to this edge
        // margin so that the preferred offset does not waste usable height.
        final margin:Float = theme.spacingTokens().lg;
        final layerOffset:Float = f32(layerIx * 16.);
        var anchor:Anchor;
        var y:Float;
        if (props.centered) {
            anchor = LeftCenter;
            y = f32(viewHeight / 2.);
        }
        else {
            anchor = TopLeft;
            y = props.marginTop != null ? props.marginTop : f32(viewHeight / 10.);
        }
        y = f32(y + layerOffset);
        final entrance = props.entrance;
        final motionTokens = theme.motionTokens();
        final closing = motion != null && motion.closing;
        final visibility:Float = motion != null ? (motion.visibility < 0. ? 0. : motion.visibility > 1. ? 1. : motion.visibility) : 1.0;
        final fadeOverlay = closing && props.overlayVisible;
        final travel:Float = motionTokens.distanceShort.toPixels(window.remSize());
        final width:Float = Math.min(props.width, Math.max(f32(viewWidth - f32(margin * 2.)), 0.));
        final x:Float = f32(f32(viewWidth - width) / 2.);
        final maxHeight:Float = Math.max(f32(f32(viewHeight - f32(margin * 2.)) - layerOffset), 0.);

        final baseSize = window.textStyle().fontSize;
        final remSize = window.remSize();

        var paddingTop:Float = 16.;
        var paddingRight:Float = 16.;
        var paddingBottom:Float = 16.;
        var paddingLeft:Float = 16.;
        if (dialogStyle.paddingLeft != null) {
            paddingLeft = DefiniteLengthTools.toPixels(dialogStyle.paddingLeft, baseSize, remSize);
        }
        if (dialogStyle.paddingRight != null) {
            paddingRight = DefiniteLengthTools.toPixels(dialogStyle.paddingRight, baseSize, remSize);
        }
        if (dialogStyle.paddingTop != null) {
            paddingTop = DefiniteLengthTools.toPixels(dialogStyle.paddingTop, baseSize, remSize);
        }
        if (dialogStyle.paddingBottom != null) {
            paddingBottom = DefiniteLengthTools.toPixels(dialogStyle.paddingBottom, baseSize, remSize);
        }

        // The newest dialog still open owns Escape, the backdrop, and the
        // focus trap; a closing dialog keeps its layer only to finish leaving.
        final activeDialogs = WindowState.read(window).activeDialogs;
        var topmost:Null<Int> = null;
        var index = activeDialogs.length - 1;
        while (index >= 0) {
            if (!activeDialogs[index].closing) {
                topmost = index;
                break;
            }
            index--;
        }
        final isTopmost = !closing && topmost == layerIx;

        final surface = vFlex()
            .id('surface')
            .testSupport()
            .debugSelector(() -> 'dialog-$layerIx')
            .bg(theme.tokens.background.background)
            .border1()
            .borderColor(theme.border)
            .rounded(theme.radiusLg)
            .minH24()
            .pt(glaze.Prelude.px(paddingTop))
            .pb(glaze.Prelude.px(paddingBottom))
            .gap(glaze.Prelude.px(Math.max(paddingTop, 8.)))
            .refineStyle(dialogStyle)
            .px0()
            .occlude()
            .w(glaze.Prelude.px(width))
            .whenSome(props.maxWidth, (surface, w) -> surface.maxW(w))
            .maxH(glaze.Prelude.px(maxHeight));

        final body = vFlex()
            .flex1()
            .overflowHidden()
            .gapY2();
        if (headerElement != null) {
            body.child(div()
                .pl(glaze.Prelude.px(paddingLeft))
                .pr(glaze.Prelude.px(paddingRight))
                .child(headerElement));
        }
        if (titleElement != null) {
            body.child(new DialogTitle()
                .pl(glaze.Prelude.px(paddingLeft))
                .pr(glaze.Prelude.px(paddingRight))
                .child(titleElement));
        }
        if (contentBuilder != null) {
            body.child(contentBuilder(new DialogContent()
                .gap(glaze.Prelude.px(paddingBottom))
                .pl(glaze.Prelude.px(paddingLeft))
                .pr(glaze.Prelude.px(paddingRight)), window, cx));
        }
        if (childElements.length > 0) {
            // Body
            final scroller = vFlex()
                .sizeFull()
                .overflowYScrollbar()
                .pl(glaze.Prelude.px(paddingLeft))
                .pr(glaze.Prelude.px(paddingRight));
            scroller.extend(childElements);
            body.child(div().flex1().overflowHidden().child(scroller));
        }
        surface.child(body);
        if (footerElement != null) {
            surface.child(div()
                .pl(glaze.Prelude.px(paddingLeft))
                .pr(glaze.Prelude.px(paddingRight))
                .child(footerElement));
        }
        if (props.closeButton) {
            final top = Math.max(paddingTop - 10., 8.);
            final right = Math.max(paddingRight - 10., 8.);
            surface.child(new glaze.kit.base.Dialog.DialogClose()
                .absolute()
                .top(glaze.Prelude.px(top))
                .right(glaze.Prelude.px(right))
                .trigger(button -> new Button('close')
                    .withBase(button)
                    .small()
                    .ghost()
                    .icon(IconName.Close)));
        }
        if (closing) {
            // The shield is painted after the content, so
            // descendant hitboxes cannot receive input.
            surface
                .captureAnyMouseDown((_, _, cx) -> cx.stopPropagation())
                .captureAnyMouseUp((_, _, cx) -> cx.stopPropagation())
                .captureKeyDown((_, window, cx) -> {
                    window.preventDefault();
                    cx.stopPropagation();
                })
                .captureKeyUp((_, _, cx) -> cx.stopPropagation())
                .child(div()
                    .absolute()
                    .inset0()
                    .occlude()
                    .onAnyMouseDown((_, _, cx) -> cx.stopPropagation())
                    .onScroll((_, _, cx) -> cx.stopPropagation()));
        }
        // Base paints its popup in a deferred pass; the
        // surface must apply opacity itself.
        surface
            .opacity(visibility)
            .shadow(dialogShadow(visibility));
        final scopedSurface = glaze.kit.base.TextSelection.textSelectionScope(selectionScope, surface);
        var surfaceElement:AnyElement;
        if (entrance == FadeSlide) {
            final entranceSurface = new EntranceSurface(scopedSurface.intoAnyElement(), travel, windowPaddings.top + margin);
            entranceSurface.progress = visibility;
            surfaceElement = entranceSurface.intoAnyElement();
        }
        else {
            surfaceElement = scopedSurface.intoAnyElement();
        }

        final positioner = Positioner.corner(anchor, new Point(windowPaddings.left + x, windowPaddings.top + y))
            .margin(margin)
            .child(surfaceElement);
        if (entrance == SlideDown) {
            positioner.position(new Point(windowPaddings.left + x, f32(windowPaddings.top + f32(y * visibility))));
        }

        final props = this.props;
        final host = base;
        base = null;
        if (host == null) {
            throw 'Dialog base host is always present';
        }
        host
            .layer(id, isTopmost)
            .focusHandle(focusHandle)
            .closeOnEscape(props.keyboard && !closing)
            .closeOnBackdropPress(props.overlayClosable && !closing)
            .dismissBelowY(TitleBar.TITLE_BAR_HEIGHT);
        if (props.overlay && !closing) {
            final backdrop = div()
                .absolute()
                .sizeFull();
            // Rust `.window_control_area(WindowControlArea::Drag)`: window
            // control areas only matter for client side decorations, which the
            // port does not draw.
            if (props.overlayVisible) {
                backdrop.bg(overlayColor(true, cx));
            }
            host.backdrop(backdrop);
        }
        host
            .onOk((event, window, cx) -> !closing && onOk(event, window, cx))
            .onCancel((event, window, cx) -> !closing && onCancel(event, window, cx))
            .onClose((event, window, cx) -> onClose(event, window, cx))
            .requestClose((deferred, window, cx) -> {
                // A dialog already leaving must not close
                // whatever sits below it.
                if (closing) {
                    return;
                }
                if (deferred) {
                    deferCloseDialog(window, cx);
                }
                else {
                    window.closeDialog(cx);
                }
            })
            .popup(positioner);

        final dialog = div()
            .id('dialog')
            .testSupport();
        // A closing dialog is leaving: it must not swallow input
        // aimed at what is already usable again beneath it.
        if (!closing) dialog.occlude();
        dialog
            .w(glaze.Prelude.px(viewWidth))
            .h(glaze.Prelude.px(viewHeight));
        if (fadeOverlay) {
            dialog.child(div().absolute().inset0().bg(overlayColor(true, cx)));
        }
        dialog
            .child(host.intoElement())
            .opacity(visibility);

        return anchored()
            .position(new Point(windowPaddings.left, windowPaddings.top))
            .snapToWindow()
            .child(dialog);
    }

}
