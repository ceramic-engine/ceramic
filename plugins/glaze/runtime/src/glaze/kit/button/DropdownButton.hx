// Ported from gpui-kit 0.8.1: crates/component/src/button/dropdown_button.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.button;

import glaze.Anchor;
import glaze.App;
import glaze.Component;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.ComponentTraits.Disableable;
import glaze.kit.base.ComponentTraits.Selectable;
import glaze.kit.I18n;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.button.Button.ButtonVariant;
import glaze.kit.menu.ContextMenu.MenuBuilder;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;
using glaze.kit.menu.DropdownMenu;

/**
 * A split button: an action button with an attached menu trigger.
 *
 * The two halves stay visually joined. A `ghost` split is transparent at
 * rest; hovering either half surfaces the whole control with the hovered half
 * emphasized, and it stays surfaced while the menu is open, so the pair reads
 * as one control rather than two buttons.
 */
class DropdownButton extends Component implements Styled implements Sizable implements Selectable implements Disableable {

    /** Group name shared by both halves, so hovering one can style the other. */
    static inline final HALVES_GROUP = 'dropdown-button';

    final id:ElementId;

    final dropdownButtonStyle:StyleRefinement = new StyleRefinement();

    /**
     * Set the left button of the dropdown button.
     *
     * The button keeps its own label, icon, tooltip and click handler. A
     * variant or size set on the `DropdownButton` applies to both halves and
     * overrides the one set here. When either outer value is unset, this
     * button's value becomes the shared value for both halves.
     */
    @:allow(glaze.kit, tests)
    @prop var button:Null<Button> = null;

    /**
     * Set the dropdown menu of the button.
     */
    @:allow(glaze.kit, tests)
    @prop var dropdownMenu:Null<MenuBuilder> = null;

    @:allow(glaze.kit, tests)
    @prop var selected:Bool = false;

    @:allow(glaze.kit, tests)
    @prop var disabled:Bool = false;

    /**
     * Set the name a screen reader announces for the menu trigger. Defaults
     * to the localized "More options".
     *
     * The trigger shows only a caret, so it has no visible label to read.
     * The inner `Button` names the action half.
     */
    @prop var menuAccessibilityLabel:Null<String> = null;

    // The button props, applied to both halves. Unset means the inner
    // `Button` keeps whatever it was given.
    @:allow(glaze.kit, tests)
    var outlineValue:Bool = false;

    @:allow(glaze.kit, tests)
    var variant:Null<ButtonVariant> = null;

    @:allow(glaze.kit, tests)
    var size:Null<Size> = null;

    @:allow(glaze.kit, tests)
    var anchor:Anchor = TopRight;

    /**
     * Create a new DropdownButton.
     */
    public function new(id:ElementIdArg) {
        super();
        this.id = id;
    }

    @:allow(glaze.kit, tests)
    function effectiveVariant():ButtonVariant {
        if (variant != null)
            return variant;
        if (button != null)
            return button.variant();
        return Default;
    }

    @:allow(glaze.kit, tests)
    function effectiveSize():Size {
        if (size != null)
            return size;
        if (button != null)
            return button.buttonSize();
        return Medium;
    }

    /**
     * Set the dropdown menu of the button with anchor corner.
     */
    public function dropdownMenuWithAnchor(anchor:Anchor, menu:MenuBuilder):DropdownButton {
        this.dropdownMenu = menu;
        this.anchor = anchor;
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

    public function setDisabled(disabled:Bool):Void {
        this.disabled = disabled;
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

    public function setSelected(selected:Bool):Void {
        this.selected = selected;
    }

    public function isSelected():Bool {
        return selected;
    }

    public function setOpen(open:Bool):Void {
        setSelected(open);
    }

    public function isOpen():Bool {
        return isSelected();
    }

    public function render(window:Window, cx:App):IntoElement {
        #if debug
        if (this.button == null && dropdownMenu == null) {
            throw 'a DropdownButton needs a `button`, a `dropdownMenu`, or both';
        }
        #end

        final variant = effectiveVariant();
        final size = effectiveSize();
        final selected = this.selected || (this.button != null && this.button.isSelected());
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
        if (this.button != null) {
            final button = this.button;
            final disabled = this.disabled || button.isDisabled();
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
        if (dropdownMenu != null) {
            final popup = Button.component('popup')
                .dropdownCaret(true)
                .accessibilityLabel(menuAccessibilityLabel != null ? menuAccessibilityLabel : I18n.t('DropdownButton.more_options'))
                .withBorderCorners(false, true, true, false)
                .withBorderEdges(true, true, true, false)
                .selected(selected)
                .disabled(this.disabled);
            if (outlineValue) popup.outline();
            popup
                .withSize(size)
                .withVariant(variant);
            if (isGhost) popup.hoverGroup(HALVES_GROUP);
            element.child(
                popup
                    .dropdownMenuWithAnchor(anchor, dropdownMenu)
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
