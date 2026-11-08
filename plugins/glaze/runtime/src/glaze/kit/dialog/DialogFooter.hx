// Ported from gpui-kit 0.8.1: crates/component/src/dialog/footer.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.dialog;

import glaze.AnyElement;
import glaze.App;
import glaze.IntoElement;
import glaze.ParentElement;
import glaze.RenderOnce;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.Actions.Confirm;
import glaze.kit.button.Button;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * Footer section of a dialog, typically contains action buttons.
 */
class DialogFooter implements RenderOnce implements Styled implements ParentElement {

    final footerStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    public function new() {}

    public inline function style():StyleRefinement {
        return footerStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):DialogFooter {
        if (child != null) childElements.push(child);
        return this;
    }

    public function render(_:Window, cx:App):IntoElement {
        final element = hFlex()
            .gap2()
            .justifyEnd()
            .lineHeight(glaze.Prelude.relative(1.25))
            .roundedB(Theme.global(cx).radiusLg)
            .refineStyle(footerStyle);
        element.extend(childElements);
        return element;
    }

}

/**
 * Rust trait `DialogFooterButton`, with its default methods.
 */
interface DialogFooterButton {

    function isCancel():Bool;

    function isAction():Bool;

}

/**
 * A close control: Base owns its accessibility and activation.
 */
class DialogClose implements RenderOnce implements ParentElement {

    var base:glaze.kit.base.Dialog.DialogClose = new glaze.kit.base.Dialog.DialogClose();

    public function new() {}

    /**
     * Styles a close button whose accessibility and activation are owned by Base.
     */
    public function trigger(build:(Button) -> IntoElement):DialogClose {
        base = base.trigger(button -> build(Button.component('close').withBase(button)));
        return this;
    }

    public function extend(elements:Array<AnyElement>):Void {
        base.extend(elements);
    }

    public function render(_:Window, _:App):IntoElement {
        return div().sizeFull().child(base);
    }

}

/**
 * A wrapper that dispatches the dialog's `Confirm` action on click.
 */
class DialogAction implements RenderOnce implements ParentElement {

    final childElements:Array<AnyElement> = [];

    public function new() {}

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):DialogAction {
        if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final anchor = new DialogDispatchAnchor('dialog-action-anchor', window, cx);
        final element = div()
            .sizeFull()
            .id('dialog-action')
            .child(anchor.element())
            .onClick((_, window, cx) -> anchor.dispatch(new Confirm(false), window, cx));
        element.extend(childElements);
        return element;
    }

}
