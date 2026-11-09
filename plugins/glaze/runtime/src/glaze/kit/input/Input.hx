// Ported from gpui-kit 0.8.1: crates/component/src/input/input.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.input;

import glaze.AnyElement;
import glaze.App;
import glaze.kit.base.input.InputEvent;
import glaze.kit.KeyedEntity;
import glaze.Model;
import glaze.Context;
import glaze.ClipboardItem;
import glaze.Component;
import glaze.DefiniteLength;
import glaze.Edges;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.TextAlign;
import glaze.TextStyleRefinement;
import glaze.Window;
import glaze.kit.base.A11y;
import glaze.kit.base.ComponentTraits;
import glaze.kit.base.input.InlineTokenClickListener;
import glaze.kit.base.input.InlineTokenContext;
import glaze.kit.base.input.InlineTokenHoverListener;
import glaze.kit.base.input.InlineTokenRenderer;
import glaze.kit.base.input.InputAccessibility;
import glaze.kit.base.input.InputActions;
import glaze.kit.base.input.InputBase;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputEditorStyle;
import glaze.kit.base.input.InputState;
import glaze.kit.base.input.NativeMenu;
import glaze.kit.IconName;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.button.Button.Button;
import glaze.kit.spinner.Spinner;
import glaze.kit.theme.Color;
import glaze.kit.theme.Theme;
import glaze.kit.input.AnyInputState.TextInputState;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.A11y.RoleOverrideTools;
using glaze.kit.base.StyledExt;
using glaze.kit.base.input.InputTokenPresentation;
using glaze.kit.base.input.InputTouch;
using glaze.kit.StyleSized;
using glaze.kit.ThemeStyled;
using glaze.kit.theme.Colorize;

/**
 * A text input element bind to an `InputState`.
 *
 * `Textarea` (and the code editor) render through this element too, with
 * their own state (Rust `Input::from_state`).
 */
class Input extends Component implements Styled implements Sizable implements Selectable implements FocusableExt {

    var tokenRenderer:Null<InlineTokenRenderer> = null;

    /** Open a reference after a completed, unconsumed token click. */
    @:allow(tests)
    @prop var onTokenClick:Null<InlineTokenClickListener> = null;

    /**
     * Report pointer presence over a token so the application can show a
     * tooltip or run custom logic. Hover never selects or edits.
     */
    @:allow(tests)
    @prop var onTokenHover:Null<InlineTokenHoverListener> = null;

    @prop var id:Null<ElementId> = null;

    /**
     * The state rendered; `null` until the first render for an input built
     * by `component()` without a state (see `resolveKeyedState`).
     */
    var textState:Null<TextInputState>;

    /**
     * The position of the `component()` call, the identity of the state
     * it creates when none is given (`null` when the state was given).
     */
    var keyedPos:Null<haxe.PosInfos> = null;

    /** `.at(key)`: the identity of the created state instead of the call position. */
    var keyedId:Null<ElementId> = null;

    var valueToPush:Null<String> = null;

    var hasValueToPush:Bool = false;

    /**
     * Called with the new text on each `InputEvent.Change` of the state
     * created by `component()`. The handler of the latest render is the one
     * called; replacing it invalidates nothing.
     */
    @prop var onChange:Null<(String) -> Void> = null;

    /**
     * The placeholder of the state, pushed when it differs from the state's
     * (`InputState.setPlaceholder`); for an input built by `component()`,
     * or any input whose state the caller does not configure itself.
     */
    @prop var placeholder:Null<String> = null;

    var inputStyle:StyleRefinement = new StyleRefinement();

    var size:Size = Medium;

    var prefixElement:Null<AnyElement> = null;

    var suffixElement:Null<AnyElement> = null;

    var height:Null<DefiniteLength> = null;

    /** Set the appearance of the input field, if false the input field will no border, background. */
    @prop var appearance:Bool = true;

    /** Set whether to show the clear button when the input field is not empty, default is false. */
    @prop var cleanable:Bool = false;

    var maskToggleValue:Bool = false;

    /** Set to disable the input field. */
    @prop var disabled:Bool = false;

    /**
     * Set the input field to read-only, default is `false`.
     *
     * Unlike `disabled`, a read-only input keeps the normal appearance and
     * still can be focused, selected and copied, it only rejects the changes
     * made by the user.
     */
    @prop var readonly:Bool = false;

    /** Set the bordered for the input, default: true */
    @prop var bordered:Bool = true;

    var focusBorderedValue:Bool = true;

    /** Set the tab index for the input, default is 0. */
    @prop var tabIndex:Int = 0;

    @prop var selected:Bool = false;

    /**
     * Set the semantic content type for password managers and autofill.
     *
     * This is a component-level semantic hint. It does not change the text
     * value or masked rendering state.
     */
    @prop var contentType:Null<InputContentType> = null;

    /**
     * Override the accessible role for the input.
     *
     * If unset, the role is inferred from multi-line mode and content type.
     */
    @prop var role:RoleOverride = Implicit;

    /** Set the developer-assigned identifier exposed to accessibility clients. */
    @prop var accessibilityId:Null<String> = null;

    @prop var ariaLabel:Null<String> = null;

    /**
     * Sets a custom context menu builder for the input, shown as a native OS menu.
     *
     * If set, this overrides the built-in right-click context menu. It shows
     * only while the state's context menu is enabled, which is the default.
     */
    @prop var contextMenu:Null<(NativeMenu, Window, App) -> NativeMenu> = null;

    /**
     * Intercept paste payloads (images, files) before the default text insertion.
     *
     * The handler receives the clipboard item and returns whether it took the
     * paste: `true` stops the `input.Paste` action so the input inserts
     * nothing, `false` lets it reach the engine, which inserts
     * `clipboard.text()`.
     */
    @:allow(tests)
    @prop var onPaste:Null<(ClipboardItem, Window, App) -> Bool> = null;

    /** Create a new `Input` element bind to the `InputState`. */
    public function new(state:Entity<InputState>) {
        super();
        final model:Null<InputBaseState> = (state : InputState);
        this.textState = model != null ? new TextInputState(model) : null;
    }

    /**
     * Places an input in a tree. With `state`, it is `Input.component(state)`.
     * Without, the input creates its `InputState` the first time it is
     * rendered and keeps it as long as it is rendered, under the identity
     * of this call (its position in the code, or `.at(key)` in a loop); the
     * state is destroyed when the input leaves the tree. `.value(v)` pushes
     * a value into the state when it differs from the current one,
     * `.onChange(f)` is called with the new text on each change (the latest
     * `f` is kept, without invalidation), and `.state` gives the entity
     * once rendered.
     */
    public static function component(?state:Entity<InputState>, ?pos:haxe.PosInfos):Input {
        if (state != null) return new Input(state);
        final input = new Input(null);
        input.keyedPos = pos;
        return input;
    }

    /**
     * The identity of the state created by `component()` without a state,
     * instead of the position of the call: needed when the call runs more
     * than once per render (a loop).
     */
    public function at(key:ElementIdArg):Input {
        keyedId = key;
        return this;
    }

    /**
     * Pushes `value` into the state when it differs from the state's value
     * (the user's typing is kept otherwise). For an input built by
     * `component()`; an input given its state keeps its value itself.
     */
    public function value(value:String):Input {
        valueToPush = value;
        hasValueToPush = true;
        return this;
    }

    /**
     * The `InputState` rendered by this input: the one given to
     * `component(state)` or `Input.component(state)`, or the one created by
     * `component()` once the input was rendered (`null` before, and for a
     * state of another kind, a textarea's for instance).
     */
    public var state(get, never):Null<Entity<InputState>>;
    function get_state():Null<Entity<InputState>> {
        if (textState == null) return null;
        final model:Model = textState.state.intoAny();
        return Std.isOfType(model, InputState) ? (cast model : InputState) : null;
    }

    /**
     * Creates or finds the state of an input built by `component()` without
     * one, under the identity of the call, applies `.value()` and installs
     * the change handler (`KeyedEntity`).
     */
    function resolveKeyedState(window:Window, cx:App):Void {
        final key:ElementIdArg = keyedId != null ? keyedId : ElementId.CodeLocation(keyedPos.fileName, keyedPos.lineNumber);
        final keyed:KeyedEntity<InputState, (String) -> Void> = window.useKeyedState(key, cx, w -> new KeyedEntity(cx.newEntity((c:Context<InputState>) -> new InputState(w, c)))).read(cx).value;
        final entity = keyed.entity;
        final base:Entity<InputBaseState> = (entity : InputState);
        textState = new TextInputState(base);
        keyed.handler = onChange;
        if (onChange != null) {
            keyed.subscribe(cx, InputEvent, (entity, event, cx) -> {
                if (event.match(Change) && keyed.handler != null) {
                    keyed.handler(entity.read(cx).value());
                }
            });
        }
        // Not tracked by the view being rendered (see `Select.resolveKeyedState`)
        tracker.Autorun.unobserve();
        if (hasValueToPush && entity.read(cx).value() != valueToPush) {
            final value = valueToPush;
            base.update(cx, (s, c) -> s.setValue(value, window, c));
        }
        tracker.Autorun.reobserve();
    }

    /**
     * Pushes `.placeholder(text)` into the state when it differs from the
     * state's placeholder.
     */
    function applyPlaceholder(window:Window, cx:App):Void {
        final base = textState.state;
        final text = placeholder;
        tracker.Autorun.unobserve();
        final differs = base.read(cx).placeholder != text;
        tracker.Autorun.reobserve();
        if (differs) {
            base.update(cx, (s, c) -> s.setPlaceholder(text, window, c));
        }
    }

    /**
     * Builds an input renderer around a state of any kind.
     *
     * `Textarea` and `Editor` render through this. Application code uses
     * `new Input`, `Textarea`, or `Editor`.
     */
    @:allow(glaze.kit)
    static function fromState(state:Entity<InputBaseState>):Input {
        // Not `Input.component(cast state)`: a textarea state is not an
        // `InputState`, and hxcpp checks class casts (it would give null).
        final input = new Input(null);
        input.textState = new TextInputState(state);
        return input;
    }

    public inline function style():StyleRefinement {
        return inputStyle;
    }

    /** Rust `std::mem::take(input.style())`: the style, replaced by an empty one. */
    @:allow(glaze.kit)
    function takeStyle():StyleRefinement {
        final style = inputStyle;
        inputStyle = new StyleRefinement();
        return style;
    }

    public function withSize(size:IntoSize):Input {
        this.size = size;
        return this;
    }

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

    public function focusRing(enabled:Bool):Input {
        focusBorderedValue = enabled;
        return this;
    }

    public function setFocusRing(enabled:Bool):Void {
        focusBorderedValue = enabled;
    }

    public function isFocusRingEnabled():Bool {
        return focusBorderedValue;
    }

    /**
     * The element each atomic inline token renders as, in place of the default
     * `InputToken`; editing and history stay with the input.
     */
    public function token(render:(InlineTokenContext, Window, App) -> IntoElement):Input {
        tokenRenderer = (token, window, cx) -> (render(token, window, cx) : AnyElement);
        return this;
    }

    /** Sets the GPUI identity of the input frame. By default it uses the state entity ID. */
    public function id(id:ElementIdArg):Input {
        this.id = id;
        return this;
    }

    /**
     * The state this input renders; a compound control reads focus and
     * presentation from it.
     */
    @:allow(glaze.kit)
    inline function getState():TextInputState {
        return textState;
    }

    @:allow(glaze.kit)
    inline function isDisabled():Bool {
        return disabled;
    }

    public function prefix(prefix:IntoElement):Input {
        prefixElement = prefix;
        return this;
    }

    public function suffix(suffix:IntoElement):Input {
        suffixElement = suffix;
        return this;
    }

    /** Set full height of the input (Multi-line only). */
    public function hFull():Input {
        height = glaze.Prelude.relative(1.);
        return this;
    }

    /** Set height of the input (Multi-line only). */
    public function h(height:glaze.IntoDefiniteLength):Input {
        this.height = height;
        return this;
    }

    /** Set focus border for the input, default is true. */
    public function focusBordered(bordered:Bool):Input {
        focusBorderedValue = bordered;
        return this;
    }

    /** Set to enable toggle button for password mask state. */
    public function maskToggle():Input {
        maskToggleValue = true;
        return this;
    }

    @:allow(tests)
    static function accessibilityRole(isMultiLine:Bool, contentType:Null<InputContentType>, role:RoleOverride):Null<Role> {
        return role.resolve(() -> {
            if (isMultiLine) {
                return Role.MultilineTextInput;
            }
            if (contentType == null) {
                return Role.TextInput;
            }
            return switch (contentType : InputContentType) {
                case TelephoneNumber: Role.PhoneNumberInput;
                case EmailAddress: Role.EmailInput;
                case Url: Role.UrlInput;
                case Password | NewPassword: Role.PasswordInput;
                case DateTime: Role.DateTimeInput;
                case Birthdate: Role.DateInput;
                case _: Role.TextInput;
            }
        });
    }

    @:allow(tests)
    static function exposesAccessibilityValue(contentType:Null<InputContentType>):Bool {
        return !(contentType == Password || contentType == NewPassword);
    }

    /** Returns `(background, foreground)` colors for input-like components (Rust `input_style`). */
    @:allow(glaze.kit)
    static function inputStyleColors(disabled:Bool, cx:App):InputStyleColors {
        final theme = Theme.global(cx);
        if (disabled) {
            return new InputStyleColors(theme.input.mixOklab(theme.transparent, 0.8), theme.mutedForeground);
        }
        return new InputStyleColors(theme.inputBackground(), theme.foreground);
    }

    /**
     * A color of the highlight theme's editor style (Rust
     * `cx.theme().highlight_theme.style.<key>`). The highlight theme comes
     * with the highlighter (wave 11); until then its colors are read from
     * the `highlight` section of the theme config.
     */
    /** Rust `Theme::editor_background`: the editor background, or the input background. */
    static function editorBackground(theme:Theme):Hsla {
        final color = theme.highlightTheme.style.editorBackground;
        return color != null ? color : theme.inputBackground();
    }

    static function renderToggleMaskButton(state:TextInputState, cx:App):Button {
        final masked = state.presentation(cx).isMasked();
        return glaze.kit.button.Button.component("toggle-mask")
            .icon(masked ? IconName.Eye : IconName.EyeOff)
            .accessibilityLabel(masked ? I18n.t("Input.Show Password") : I18n.t("Input.Hide Password"))
            .xsmall()
            .text()
            .tabStop(false)
            .onClick((_, window, cx) -> state.toggleMasked(window, cx));
    }

    /** This method must after the refineStyle. */
    static function renderEditor(inputState:TextInputState, searchPanel:Null<AnyElement>, window:Window):IntoElement {
        final element = vFlex().sizeFull();
        if (searchPanel != null) element.child(searchPanel);
        return element.child(div().relative().flex1().child(inputState.state));
    }

    /**
     * The handles and the edit menu of the selection a long press made.
     *
     * The menu offers what the native context menu would: Cut, Copy, Paste
     * and Select All, leaving out what cannot apply right now rather than
     * disabling it. Cut, Copy and Paste go through the input's actions, so a
     * custom key binding or an open completion menu sees them the same way.
     */
    static function renderTouchSelection(state:TextInputState, window:Window, cx:App):Array<AnyElement> {
        final engine = state.state;
        if (glaze.kit.base.input.InputTouch.touchSelection(engine.read(cx)) == null) {
            return [];
        }
        final capabilities = engine.read(cx).contextMenuCapabilities();
        final editable = capabilities.isEditable();
        final copyable = capabilities.isCopyable();
        // Offered whenever the text can change, without peeking at the
        // clipboard: on iOS every read of it shows the system's paste banner,
        // and an empty clipboard pastes nothing.
        final pasteable = editable;
        final selectable = state.text(cx).len() > 0 && !state.isAllSelected(cx);
        final focusHandle = state.presentation(cx).focusHandle();

        final dispatch = (action:glaze.Action, window:Window, cx:App) -> focusHandle.dispatchAction(action, window, cx);
        final items:Array<glaze.kit.touchselection.EditMenu.EditMenuItem> = [];
        if (editable && copyable) {
            items.push(new glaze.kit.touchselection.EditMenu.EditMenuItem(I18n.t("Input.Cut"), (window, cx) -> dispatch(new Cut(), window, cx)));
        }
        if (copyable) {
            items.push(new glaze.kit.touchselection.EditMenu.EditMenuItem(I18n.t("Input.Copy"), (window, cx) -> {
                dispatch(new Copy(), window, cx);
                engine.update(cx, (state, cx) -> state.closeEditMenu(cx));
            }));
        }
        if (pasteable) {
            items.push(new glaze.kit.touchselection.EditMenu.EditMenuItem(I18n.t("Input.Paste"), (window, cx) -> dispatch(new Paste(), window, cx)));
        }
        if (selectable) {
            items.push(new glaze.kit.touchselection.EditMenu.EditMenuItem(I18n.t("Input.Select All"), (window, cx) -> {
                engine.update(cx, (state, cx) -> state.selectAllFromEditMenu(window, cx));
            }));
        }

        return new glaze.kit.touchselection.TouchSelectionOverlay(NamedInteger('input-touch-selection', state.entityId()), (_, cx) -> glaze.kit.base.input.InputTouch.touchSelection(engine.read(cx)))
            .handles((edge, phase, position, _, cx) -> {
                engine.update(cx, (state, cx) -> switch phase {
                    case Started: state.beginEdgeDrag(edge, position, cx);
                    case Moved: state.updateEdgeDrag(position, cx);
                    case Ended | Cancelled: state.endEdgeDrag(cx);
                });
            })
            .items(items)
            .intoElements(window, cx);
    }

    public function render(window:Window, cx:App):IntoElement {
        if (textState == null) resolveKeyedState(window, cx);
        if (this.placeholder != null) applyPlaceholder(window, cx);
        final LINE_HEIGHT = rems(1.25);
        final textAlign:TextAlign = inputStyle.text != null && inputStyle.text.has(TextStyleRefinement.TEXT_ALIGN) ? inputStyle.text.textAlign : Left;
        final state = this.textState;
        final theme = Theme.global(cx);
        final secret = this.contentType == Password || this.contentType == NewPassword;
        final renderer:InlineTokenRenderer = tokenRenderer != null ? tokenRenderer : (token, _, _) -> (InputToken.component(token) : IntoElement);
        final clickListener = onTokenClick;
        final hoverListener = onTokenHover;
        state.state.update(cx, (s, _) -> s.installTokenPresentation(renderer, clickListener, secret));
        state.state.update(cx, (s, _) -> s.installTokenHoverPresentation(hoverListener));
        // Which kind of input this registers as follows from the state itself.
        @:privateAccess AnyInputState.syncFocusedInputRegistry(state.toAny(), window, cx);

        final editorStyle = new InputEditorStyle(
            theme.foreground,
            theme.mutedForeground,
            editorBackground(theme),
            theme.border,
            theme.selection,
            theme.caret,
            theme.highlightTheme.style.editorInvisible
        );
        state.state.update(cx, (s, _) -> s.setEditorStyle(editorStyle));
        final presentation0 = state.presentation(cx);
        final paddings = if (presentation0.isMultiLine()) {
            new Edges(size.inputPy(), size.inputPx(), size.inputPy(), size.inputPx());
        } else {
            new Edges();
        }
        state.state.update(cx, (s, _) -> s.setEditorPaddings(paddings));
        state.setDisabled(this.disabled, cx);
        state.setReadonly(readonly, cx);
        state.setTextAlign(textAlign, cx);
        final custom = contextMenu;
        state.state.update(cx, (s, _) -> s.onContextMenu((_, capabilities, position, window, cx) -> {
            final menu = if (custom != null) {
                custom(new NativeMenu(), window, cx);
            } else {
                final enabled = !capabilities.isDisabled();
                // A read-only input can still navigate the code, it only
                // rejects the items that would change the text.
                final editable = enabled && !capabilities.isReadonly();
                final menu = new NativeMenu();
                menu.menuWithDisabled(I18n.t("Input.Cut"), !(editable && capabilities.isCopyable()), new Cut())
                    .menuWithDisabled(I18n.t("Input.Copy"), !capabilities.isCopyable(), new Copy())
                    // Offered whenever the text can change, without peeking
                    // at the clipboard: the synchronous read is always empty
                    // on the web, and an empty clipboard pastes nothing.
                    .menuWithDisabled(I18n.t("Input.Paste"), !editable, new Paste())
                    .separator()
                    .menu(I18n.t("Input.Select All"), new SelectAll());
            }
            // Rust `menu.show(position, window, cx)`: the native menu of the
            // component layer (an OS popup on macOS and Windows, a drawn
            // PopupMenu elsewhere) is not ported yet, the menu is not shown.
        }));
        // The engine ignores `Paste` on a read-only or disabled input; the hook
        // must not see a paste the input itself would refuse.
        final pasteHandler = this.onPaste != null && state.presentation(cx).isEditable() ? this.onPaste : null;
        final overlays = InputOverlays.renderOverlays(state.state, window, cx);
        for (element in renderTouchSelection(state, window, cx)) overlays.floating.push(element);

        final presentation = state.presentation(cx);
        final contentType = this.contentType;
        final disabled = this.disabled;
        final isMultiLine = presentation.isMultiLine();
        // Without a content type, a masked input is a password field to screen
        // readers, so they announce it as one.
        final accessibilityRole = Input.accessibilityRole(isMultiLine, contentType != null ? contentType : (presentation.isMasked() ? Password : null), role);
        final inputFocused = presentation.focusHandle().isFocused(window) && !presentation.isDisabled();
        if (inputFocused) {
            InputContentType.syncNativeContentType(window, contentType, presentation.isEditable());
        }
        final frameFocusHandle:FocusHandle = window.useKeyedState(ElementId.NamedInteger("input-frame-focus", state.entityId()), cx, _ -> cx.focusHandle()).read(cx).value;
        final focused = !presentation.isDisabled() && (state.hasSelectionFocus(window, cx) || frameFocusHandle.containsFocused(window, cx));

        final gapX:Float = switch size {
            case Small: 4.;
            case Large: 8.;
            case _: 6.;
        }

        var bg = inputStyleColors(presentation.isDisabled(), cx).background;
        if (presentation.isDisabled()) bg = bg.opacity(0.5);
        final prefix = prefixElement;
        final suffix = suffixElement;
        final showClearButton = cleanable && presentation.isEditable() && !presentation.isLoading() && state.text(cx).len() > 0
            && !presentation.isMultiLine();
        final hasSuffix = suffix != null || presentation.isLoading() || maskToggleValue || showClearButton;

        final placeholder:Null<String> = presentation.placeholder() != "" ? presentation.placeholder() : null;

        // Don't use a mask-derived placeholder ("(___)___-___") as an aria_label fallback.
        final placeholderIsMask = presentation.maskPlaceholder() == placeholder;

        final ariaLabel = this.ariaLabel != null ? this.ariaLabel : (placeholderIsMask ? null : placeholder);
        final accessibility = new InputAccessibility(accessibilityRole)
            .withLabel(ariaLabel)
            .withPlaceholder(placeholder)
            .withAccessibilityId(accessibilityId)
            .withValueExposed(exposesAccessibilityValue(contentType));
        state.state.update(cx, (s, _) -> s.setAccessibility(accessibility));
        final id:ElementId = this.id != null ? this.id : ElementId.NamedInteger("input", state.entityId());
        final appearance = this.appearance;
        final bordered = this.bordered;
        final focusBordered = focusBorderedValue;
        final frame = InputBase.component(id)
            .semanticOwner(state.entityId())
            .focused(focused)
            .disabled(disabled)
            .trackFocus(frameFocusHandle);
        frame.base.onMouseDown(Right, (_, window, cx) -> {
            // The text element has already taken focus. Publish its state
            // before an outer ContextMenu resolves the selection owner;
            // render-time registration still names the previous input.
            @:privateAccess AnyInputState.syncFocusedInputRegistry(state.toAny(), window, cx);
        });
        if (disabled) {
            frame.base.captureAnyMouseDown((_, _, cx) -> cx.stopPropagation());
        }
        frame.styles(styles -> styles.focused(style -> {
            if (appearance && bordered && focusBordered) style.border1().borderColor(theme.ring);
            return style;
        }))
            // The editor owns text semantics. The frame still scopes addon
            // controls, custom IDs and focus styling without registering the
            // editor's FocusHandle a second time.
            .role(Presentational);
        frame.flex().sizeFull().lineHeight(LINE_HEIGHT);
        if (!isMultiLine) frame.inputPx(size).inputPy(size);
        frame.inputH(size).inputTextSize(size).itemsCenter();
        if (presentation.isMultiLine()) {
            frame.hAuto();
            if (height != null) frame.h(height);
        }
        if (appearance) {
            frame.bg(bg).rounded(theme.radius);
            if (bordered) frame.border1().borderColor(theme.input);
        }
        frame.itemsCenter().gap(glaze.Prelude.px(gapX)).refineStyle(inputStyle);
        if (focused && appearance && bordered && focusBordered) frame.focusRingStyle(window, cx);
        if (prefix != null) {
            final wrapper = div();
            if (presentation.isDisabled()) wrapper.opacity(0.5);
            frame.child(wrapper.child(prefix));
        }
        if (presentation.isMultiLine()) {
            frame.child(renderEditor(state, overlays.search, window));
        }
        if (!presentation.isMultiLine()) {
            frame.child(state.state);
        }
        if (hasSuffix) {
            frame.pr(size.inputPx());
            final suffixRow = hFlex().id("suffix").gap(glaze.Prelude.px(gapX)).itemsCenter().cursorDefault();
            if (presentation.isDisabled()) suffixRow.opacity(0.5);
            if (presentation.isLoading()) suffixRow.child(Spinner.component().color(theme.mutedForeground));
            if (maskToggleValue) suffixRow.child(renderToggleMaskButton(state, cx));
            if (showClearButton) {
                suffixRow.child(ClearButton.clearButton(cx).onClick((_, window, cx) -> {
                    state.clean(window, cx);
                    state.focus(window, cx);
                }));
            }
            if (suffix != null) suffixRow.child(suffix);
            frame.child(suffixRow);
        }
        frame.relative();
        for (element in overlays.floating) frame.child(element);
        if (pasteHandler != null) {
            frame.base.captureAction(Paste, (_, window, cx) -> {
                final clipboard = cx.readFromClipboard();
                if (clipboard != null) {
                    if (pasteHandler(clipboard, window, cx)) {
                        cx.stopPropagation();
                    }
                }
            });
        }
        return frame.render(window, cx);
    }

}

/**
 * The colors of `Input.inputStyleColors` (a class: the fields of an
 * anonymous structure are read by name on hxcpp). Internal.
 */
@:noCompletion
class InputStyleColors {

    public final background:Hsla;

    public final foreground:Hsla;

    public inline function new(background:Hsla, foreground:Hsla) {
        this.background = background;
        this.foreground = foreground;
    }

}
