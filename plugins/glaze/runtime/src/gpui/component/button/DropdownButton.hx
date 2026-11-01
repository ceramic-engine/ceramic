// Ported from gpui-kit 0.8.1: crates/component/src/button/dropdown_button.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.button;

import gpui.Anchor;
import gpui.App;
import gpui.ElementId;
import gpui.ElementIdArg;
import gpui.IntoElement;
import gpui.RenderOnce;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.base.ComponentTraits.Disableable;
import gpui.base.ComponentTraits.Selectable;
import gpui.component.I18n;
import gpui.component.Sizable;
import gpui.component.Size;
import gpui.component.Size.IntoSize;
import gpui.component.button.Button.ButtonVariant;
import gpui.component.menu.ContextMenu.MenuBuilder;

import gpui.Prelude.*;

using gpui.base.StyledExt;
using gpui.component.menu.DropdownMenu;

/**
 * A split button: an action button with an attached menu trigger.
 *
 * The two halves stay visually joined. A `ghost` split is transparent at
 * rest; hovering either half surfaces the whole control with the hovered half
 * emphasized, and it stays surfaced while the menu is open, so the pair reads
 * as one control rather than two buttons.
 */
class DropdownButton implements RenderOnce implements Styled implements Sizable implements Selectable implements Disableable {

    /** Group name shared by both halves, so hovering one can style the other. */
    static inline final HALVES_GROUP = 'dropdown-button';

    final id:ElementId;

    final dropdownButtonStyle:StyleRefinement = new StyleRefinement();

    @:allow(gpui.component, tests)
    var buttonValue:Null<Button> = null;

    @:allow(gpui.component, tests)
    var menu:Null<MenuBuilder> = null;

    @:allow(gpui.component, tests)
    var selectedValue:Bool = false;

    @:allow(gpui.component, tests)
    var disabledValue:Bool = false;

    var menuAccessibilityLabelValue:Null<String> = null;

    // The button props, applied to both halves. Unset means the inner
    // `Button` keeps whatever it was given.
    @:allow(gpui.component, tests)
    var outlineValue:Bool = false;

    @:allow(gpui.component, tests)
    var variant:Null<ButtonVariant> = null;

    @:allow(gpui.component, tests)
    var size:Null<Size> = null;

    @:allow(gpui.component, tests)
    var anchor:Anchor = TopRight;

    /**
     * Create a new DropdownButton.
     */
    public function new(id:ElementIdArg) {
        this.id = id;
    }

    @:allow(gpui.component, tests)
    function effectiveVariant():ButtonVariant {
        if (variant != null)
            return variant;
        if (buttonValue != null)
            return buttonValue.variant();
        return Default;
    }

    @:allow(gpui.component, tests)
    function effectiveSize():Size {
        if (size != null)
            return size;
        if (buttonValue != null)
            return buttonValue.buttonSize();
        return Medium;
    }

    /**
     * Set the left button of the dropdown button.
     *
     * The button keeps its own label, icon, tooltip and click handler. A
     * variant or size set on the `DropdownButton` applies to both halves and
     * overrides the one set here. When either outer value is unset, this
     * button's value becomes the shared value for both halves.
     */
    public function button(button:Button):DropdownButton {
        buttonValue = button;
        return this;
    }

    /**
     * Set the dropdown menu of the button.
     */
    public function dropdownMenu(menu:MenuBuilder):DropdownButton {
        this.menu = menu;
        return this;
    }

    /**
     * Set the dropdown menu of the button with anchor corner.
     */
    public function dropdownMenuWithAnchor(anchor:Anchor, menu:MenuBuilder):DropdownButton {
        this.menu = menu;
        this.anchor = anchor;
        return this;
    }

    /**
     * Set the name a screen reader announces for the menu trigger. Defaults
     * to the localized "More options".
     *
     * The trigger shows only a caret, so it has no visible label to read.
     * The inner `Button` names the action half.
     */
    public function menuAccessibilityLabel(label:String):DropdownButton {
        menuAccessibilityLabelValue = label;
        return this;
    }

    /**
     * Set the button to outline style.
     */
    public function outline():DropdownButton {
        outlineValue = true;
        return this;
    }

    /// Disableable

    public function disabled(disabled:Bool):DropdownButton {
        disabledValue = disabled;
        return this;
    }

    public function setDisabled(disabled:Bool):Void {
        disabledValue = disabled;
    }

    /// Styled

    public inline function style():StyleRefinement {
        return dropdownButtonStyle;
    }

    /// Sizable

    public function withSize(size:IntoSize):DropdownButton {
        this.size = size;
        return this;
    }

    /// ButtonVariants

    public function withVariant(variant:ButtonVariant):DropdownButton {
        this.variant = variant;
        return this;
    }

    /** With the primary style for the Button. */
    public inline function primary():DropdownButton return withVariant(Primary);

    /** With the secondary style for the Button. */
    public inline function secondary():DropdownButton return withVariant(Secondary);

    /** With the danger style for the Button. */
    public inline function danger():DropdownButton return withVariant(Danger);

    /** With the warning style for the Button. */
    public inline function warning():DropdownButton return withVariant(Warning);

    /** With the success style for the Button. */
    public inline function success():DropdownButton return withVariant(Success);

    /** With the info style for the Button. */
    public inline function info():DropdownButton return withVariant(Info);

    /** With the ghost style for the Button. */
    public inline function ghost():DropdownButton return withVariant(Ghost);

    /** With the link style for the Button. */
    public inline function link():DropdownButton return withVariant(Link);

    /** With the text style for the Button, it will no padding look like a normal text. */
    public inline function text():DropdownButton return withVariant(Text);

    /** With the custom style for the Button. */
    public inline function custom(style:Button.ButtonCustomVariant):DropdownButton return withVariant(Custom(style));

    /// Selectable

    public function selected(selected:Bool):DropdownButton {
        selectedValue = selected;
        return this;
    }

    public function setSelected(selected:Bool):Void {
        selectedValue = selected;
    }

    public function isSelected():Bool {
        return selectedValue;
    }

    public function setOpen(open:Bool):Void {
        setSelected(open);
    }

    public function isOpen():Bool {
        return isSelected();
    }

    public function render(window:Window, cx:App):IntoElement {
        #if debug
        if (buttonValue == null && menu == null) {
            throw 'a DropdownButton needs a `button`, a `dropdownMenu`, or both';
        }
        #end

        final variant = effectiveVariant();
        final size = effectiveSize();
        final selected = selectedValue || (buttonValue != null && buttonValue.isSelected());
        // Only a ghost split has no surface at rest, so only it needs hovering
        // one half to reveal the other, and the action half to stay revealed
        // while the menu holds the trigger pressed.
        final isGhost = variant.isGhost();
        final menuOpen = window.useKeyedState(id, cx, _ -> false);
        final isMenuOpen = menuOpen.read(cx).value;

        final element = div().id(id);
        if (isGhost) element.group(HALVES_GROUP);
        element
            .hFlex()
            .refineStyle(dropdownButtonStyle);
        if (buttonValue != null) {
            final button = buttonValue;
            final disabled = disabledValue || button.isDisabled();
            button
                .withBorderCorners(true, false, false, true)
                .withBorderEdges(true, true, true, true)
                .selected(selected)
                .disabled(disabled);
            if (outlineValue) button.outline();
            button
                .withSize(size)
                .withVariant(variant);
            if (isGhost) {
                button.hoverGroup(HALVES_GROUP)
                    .hoverGroupHeld(isMenuOpen);
            }
            element.child(button);
        }
        if (menu != null) {
            final popup = new Button('popup')
                .dropdownCaret(true)
                .accessibilityLabel(menuAccessibilityLabelValue != null ? menuAccessibilityLabelValue : I18n.t('DropdownButton.more_options'))
                .withBorderCorners(false, true, true, false)
                .withBorderEdges(true, true, true, false)
                .selected(selected)
                .disabled(disabledValue);
            if (outlineValue) popup.outline();
            popup
                .withSize(size)
                .withVariant(variant);
            if (isGhost) popup.hoverGroup(HALVES_GROUP);
            element.child(
                popup
                    .dropdownMenuWithAnchor(anchor, menu)
                    .onOpenChange((open, _, cx) -> {
                        menuOpen.update(cx, (state, _) -> {
                            state.value = open;
                        });
                    })
            );
        }
        return element;
    }

}
