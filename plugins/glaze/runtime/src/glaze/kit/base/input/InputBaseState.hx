// Ported from gpui-kit 0.8.1: crates/base/src/input/base/state.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
// Also modified during the initial port: deviation DEV-009 (no Change event when the value did not change). See docs/DEVIATIONS.md.
// Also modified during the initial port: deviation DEV-015 (typing over a selection undoes in one step). See docs/DEVIATIONS.md.
// Also modified during the initial port: deviation DEV-017 (the software keyboard suited to a number field). See docs/DEVIATIONS.md.
package glaze.kit.base.input;

import glaze.Action;
import glaze.App;
import glaze.Bounds;
import glaze.ClickEvent;
import glaze.ClipboardItem;
import glaze.Context;
import glaze.Div;
import glaze.Edges;
import glaze.Entity;
import glaze.EntityInputHandler;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.MouseButton;
import glaze.MouseDownEvent;
import glaze.MouseMoveEvent;
import glaze.MouseUpEvent;
import glaze.Pixels;
import glaze.Point;
import glaze.Range;
import glaze.Render;
import glaze.ScrollDelta;
import glaze.ScrollEvent;
import glaze.ScrollHandle;
import glaze.Size;
import glaze.Subscription;
import glaze.TextAlign;
import glaze.TextInputConfiguration;
import glaze.TouchPhase;
import glaze.UTF16Selection;
import glaze.Window;
import glaze.kit.base.Actions.SelectDown;
import glaze.kit.base.Actions.SelectLeft;
import glaze.kit.base.Actions.SelectRight;
import glaze.kit.base.Actions.SelectUp;
import glaze.kit.base.AutoScroll;
import glaze.kit.base.GlobalState;
import glaze.kit.base.NumberStep;
import glaze.kit.base.Overscroll;
import glaze.kit.base.ScrollBounce;
import glaze.kit.base.input.InputActions;
import glaze.kit.base.theme.Theme as BaseTheme;
import glaze.util.Ref;
import glaze.util.Utf8;
import ropey.Rope;
import ropey.RopeSlice;
import unicode_segmentation.UnicodeSegmentation;

import glaze.Prelude.*;

using glaze.kit.base.input.InputMovement;
using glaze.kit.base.input.InputSearchExt;
using glaze.kit.base.input.InputIndentExt;
using glaze.kit.base.input.InputTokens;
using glaze.kit.base.input.InputTokenPresentation;
using glaze.kit.base.input.InputTouch;
using glaze.kit.base.input.InputWordSelection;
using glaze.kit.base.input.MaskPattern.MaskPatternTools;
using glaze.kit.base.input.RopeExt;

/** The result of `lineAndPositionForOffset` (Rust `(usize, usize, Option<Point<Pixels>>)`). */
typedef LinePosition = {final line:Int; final localRow:Int; final position:Null<Point>;};

/** The result of `resolveMousePosition` (Rust `(usize, bool, usize)`). */
typedef MousePosition = {final offset:Int; final lineEndAffinity:Bool; final columnsPastLineEnd:Int;};

/** The result of `indexForMousePosition` (Rust `(usize, bool)`). */
typedef MouseIndex = {final offset:Int; final lineEndAffinity:Bool;};

/** The result of `cursorLayout` (Rust `(Bounds<Pixels>, Pixels)`). */
typedef CursorLayoutResult = {final bounds:Bounds; final lineHeight:Pixels;};

/** A pressed token (Rust `(usize, u64, Point<Pixels>)`). */
typedef PressedToken = {final start:Int; final revision:Int; final position:Point;};

/** A right click waiting for its mouse up (Rust `(Point<Pixels>, usize)`). */
typedef PendingContextMenu = {final position:Point; final offset:Int;};

/** One edit of a batch (Rust `(Range<usize>, String)`): `InputIndentExt.RangeEdit`. */
typedef TextEdit = glaze.kit.base.input.InputIndentExt.RangeEdit;

/** The handler of the right-click menu (Rust `Rc<dyn Fn(NativeMenu, InputContextMenuCapabilities, Point<Pixels>, &mut Window, &mut App)>`). */
typedef ContextMenuHandler = (NativeMenu, InputContextMenuCapabilities, Point, Window, App) -> Void;

/** The handler routing the actions of an overlay (Rust `overlay_action_handler`). */
typedef OverlayActionHandler = (InputOverlayKind, Action, Window, Context<InputBaseState>) -> Bool;

/**
 * Rust `impl Into<MaskPattern>`: a `MaskPattern`, or a pattern string
 * (`MaskPatternTools.create`).
 */
abstract IntoMaskPattern(MaskPattern) from MaskPattern to MaskPattern {

    @:from static inline function fromString(pattern:String):IntoMaskPattern {
        return MaskPatternTools.create(pattern);
    }

}

/**
 * A mouse position resolved for a columnar (block) selection.
 *
 * A position past the end of a short row has no glyph to land on, so `offset` clips to
 * that row's end and `columnsPastLineEnd` keeps what the clip dropped. Together they
 * say which column the pointer really reached, which is what a block spanning rows of
 * different lengths has to be measured in.
 */
class ColumnarPoint {

    public final offset:Int;

    public final columnsPastLineEnd:Int;

    public inline function new(offset:Int, columnsPastLineEnd:Int) {
        this.offset = offset;
        this.columnsPastLineEnd = columnsPastLineEnd;
    }

    public function equals(other:Null<ColumnarPoint>):Bool {
        return other != null && other.offset == offset && other.columnsPastLineEnd == columnsPastLineEnd;
    }

}

/**
 * The document and selections a paste was asked to replace, taken when the
 * `Paste` action ran so a clipboard read that resolves later can tell
 * whether it still applies. See `InputBaseState.pasteTarget`.
 */
private class PasteTarget {

    public final documentRevision:Int;

    public final selections:Array<CursorSelection>;

    public function new(documentRevision:Int, selections:Array<CursorSelection>) {
        this.documentRevision = documentRevision;
        this.selections = selections;
    }

    public function equals(other:PasteTarget):Bool {
        if (other.documentRevision != documentRevision || other.selections.length != selections.length)
            return false;
        for (i in 0...selections.length) {
            if (!selections[i].equals(other.selections[i]))
                return false;
        }
        return true;
    }

}

/**
 * The shared text-editing engine behind `InputState`, `TextareaState` and
 * `EditorState`.
 *
 * Rust makes it generic over a mode marker (`InputBaseState<M>`) that only
 * decides which methods exist. The port keeps one non-generic class holding
 * its `modeKind` (`InputMode.instance`, `TextareaMode.instance` or
 * `EditorMode.instance`): `M::f(self)` becomes `modeKind.f(this)`, and the
 * `impl InputBaseState<InputMode>` / `<TextareaMode>` / `<EditorMode>`
 * blocks are the subclasses `InputState`, `TextareaState` and `EditorState`.
 * The methods of `impl<M: MultiLineMode>` live here, guarded by the mode
 * where they would not exist in Rust (see `TextareaState` for the public
 * builders).
 *
 * The `impl InputBaseState` blocks written in other Rust files are static
 * extensions: `InputMovement`, `InputWordSelection`, `InputTouch`,
 * `InputTokens`, `InputTokenPresentation`, `InputSearchExt`,
 * `InputIndentExt`, `InputLspExt` and `InputDecorationsExt`.
 *
 * Names: the builders whose name is a field get a `with` prefix
 * (`withPlaceholder`, `withMasked`...), the getters that only return a field
 * (`text()`, `displayMap()`, `inputBounds()`, `diagnosticPopover()`,
 * `prepaintCaretGeometry()`) are the fields themselves. The `Paste` action
 * handler is `pasteAction` (`paste` is the `EntityInputHandler` method).
 */
@:access(glaze.kit.base.input.LayoutMode)
class InputBaseState extends Model implements Render implements EntityInputHandler {

    /** The listeners of `render()`, made on the first render */
    var renderListeners:Null<InputRenderListeners> = null;

    public static inline final EDITOR_ELEMENT_ID = "input-state";

    /** The key context of the inputs (Rust `CONTEXT`). */
    public static inline final CONTEXT = InputActions.CONTEXT;

    /** What decides the kind of this input (Rust's mode marker `M`). */
    public final modeKind:InputModeKind;

    /** State only this mode needs. See `InputModeKind.newExtras`. */
    public var extras:InputExtras;

    public var focusHandle:FocusHandle;

    var selectionFocus:Null<FocusHandle> = null;

    public var mode:LayoutMode;

    public var text:Rope;

    public var displayMap:DisplayMap;

    public var undoManager:UndoManager;

    public var inlineTokens:Null<InlineTokenStore> = null;

    public var pendingToken:Null<InlineToken> = null;

    public var replayingHistory:Bool = false;

    public var validatedTokenEdit:Bool = false;

    public var documentRevision:Int = 0;

    public var tokenPresentation:InlineTokenPresentation;

    public var tokenLayoutCache:Null<glaze.kit.base.input.InlineTokenPresentation.TokenLayoutCache> = null;

    /**
     * Real per-frame bounds of the placed token elements, keyed by token
     * start offset; used for hover payloads and stale-hover reconciliation.
     */
    public var tokenBounds:Map<Int, Bounds> = new Map();

    /**
     * The currently hovered token: its entered span, last measured bounds,
     * and UTF-16 range as of entry. Retained so hover exit can still be
     * delivered when the token is removed, replaced, scrolled out, or
     * disabled.
     */
    public var hoveredToken:Null<HoverSnapshot> = null;

    public var pendingTokenHoverExits:Array<HoverSnapshot> = [];

    /**
     * The start offset of a pressed token, with the document revision and
     * pointer position at the press.
     */
    public var pressedToken:Null<PressedToken> = null;

    public var searchSession:SearchSession;

    /** Advances every time search is explicitly invoked. */
    public var searchActivationRevision:Int = 0;

    public var searchable:Bool = false;

    public var replaceable:Bool = true;

    public var softWrap:Bool = true;

    public var wrappingIndent:WrappingIndent = WrappingIndent.defaultValue();

    public var scrollBeyondLastLine:Null<Int> = null;

    public var cursorSurroundingLines:Null<Int> = null;

    public var blinkCursor:Entity<BlinkCursor>;

    @observe public var loading:Bool = false;

    /**
     * The cursors and selections.
     *
     * Always contains at least one selection where index 0 is the active cursor.
     */
    public var selections:Selections;

    /** Range for save the selected word, use to keep word range when drag move. */
    public var selectedWordRange:Null<CursorSelection> = null;

    /** The marked range is the temporary insert text on IME typing. */
    public var imeMarkedRange:Null<CursorSelection> = null;

    public var lastLayout:Null<LastLayout> = null;

    /**
     * Fresh caret geometry stashed during prepaint for caret-anchored popups.
     *
     * Popups are positioned in their deferred prepaint, which runs after the
     * input's prepaint but before its paint, so they read this instead of
     * the previous frame's `lastLayout`.
     */
    public var prepaintCaretGeometry:Null<PrepaintCaretGeometry> = null;

    public var lastCursor:Null<Int> = null;

    /** The input container bounds. */
    public var inputBounds:Bounds;

    /** The text bounds. */
    public var lastBounds:Null<Bounds> = null;

    /**
     * The fully visible part of the window this input last asked its scroll
     * containers to reveal it in, while focused. `null` while unfocused.
     */
    public var revealedViewport:Null<Bounds> = null;

    public var lastSelectedRange:Null<CursorSelection> = null;

    public var selecting:Bool = false;

    /** Anchor point of an in-progress columnar (block) selection. */
    public var columnSelectStart:Null<ColumnarPoint> = null;

    /** The selection a long press made, with its handles and edit menu. */
    public var touchSelection:TouchSelection;

    public var disabled:Bool = false;

    public var readonly:Bool = false;

    @observe public var textAlign:TextAlign = TextAlign.Left;

    @observe public var masked:Bool = false;

    public var cleanOnEscape:Bool = false;

    public var submitOnEnter:Bool = false;

    /** Overrides for `textInputConfiguration`. */
    public var inputAction:Null<TextInputAction> = null;

    public var autocorrect:Null<Bool> = null;

    public var autocapitalize:Null<Autocapitalize> = null;

    public var showWhitespaces:Bool = false;

    /** This flag tells the renderer to prefer the end of the current visual line. */
    public var cursorLineEndAffinity:Bool = false;

    public var pattern:Null<EReg> = null;

    public var validate:Null<(String, App) -> Bool> = null;

    /** The step strategy for `NumberInput` to increment/decrement. */
    public var numberStep:Null<NumberStep> = Fixed(1.);

    /** The minimum value for `NumberInput`. */
    public var numberMin:Null<Float> = null;

    /** The maximum value for `NumberInput`. */
    public var numberMax:Null<Float> = null;

    public var scrollHandle:ScrollHandle;

    /** Whether the text stretches past its ends, see `withScrollBounce`. */
    public var scrollBounce:Bool;

    /** The text's stretch past an end, while it lasts. */
    public var overscroll:Overscroll;

    /** The deferred scroll offset to apply on next layout. */
    public var deferredScrollOffset:Null<Point> = null;

    /** The size of the scrollable content. */
    public var scrollSize:Size;

    /** The editor scrollbar's snapshot of the last prepaint. */
    public var editorScrollbarSnapshot:Null<EditorScrollbarSnapshot> = null;

    /** The widest measured unwrapped line width and what it was measured for. */
    public var longestLineWidth:Null<glaze.kit.base.input.LongestLineKey.LongestLineWidth> = null;

    public var editorPaddings:Edges;

    /**
     * The style this state paints with: what was projected onto it, with
     * every colour left unset resolved from the palette that is current. It
     * is rebuilt at the top of every render, which is what keeps it current
     * when the palette changes after the state was built.
     */
    public var editorStyle:InputEditorStyle;

    /**
     * What a consumer projected, kept verbatim so that resolution never
     * consumes its own output.
     */
    var projectedEditorStyle:InputEditorStyle;

    var accessibility:Null<InputAccessibility> = null;

    /** What paints in place of Base's editor scrollbar, when a consumer supplies its own. */
    public var scrollbarRenderer:Null<glaze.kit.base.input.EditorScrollbarContext.EditorScrollbarRenderer> = null;

    /** The mask pattern for formatting the input text. */
    public var maskPattern:MaskPattern = MaskPattern.None;

    /**
     * Whether the `maskPattern` was explicitly set, to let `NumberInput` only
     * apply its default mask when the user has not made an explicit choice.
     */
    public var maskPatternSet:Bool = false;

    @observe public var placeholder:String = "";

    /** Diagnostic currently requested by pointer hover; applications render it. */
    public var diagnosticPopover:Null<DiagnosticEntry> = null;

    var contextMenuHandler:Null<ContextMenuHandler> = null;

    var pendingContextMenu:Null<PendingContextMenu> = null;

    /** Whether the context menu that shows on right-click is enabled. */
    public var enableContextMenu:Bool = true;

    /** A flag to indicate if we are currently inserting a completion item. */
    public var completionInserting:Bool = false;

    public var overlayActionHandler:Null<OverlayActionHandler> = null;

    /**
     * A flag to indicate if we have a pending update to the text.
     *
     * If true, will call some update (for example LSP, Syntax Highlight) before render.
     */
    public var _pendingUpdate:Bool = false;

    /** A flag to indicate if we should ignore the next completion event. */
    public var silentReplaceText:Bool = false;

    /** A flag to indicate if we should emit InputEvents. */
    public var emitEvents:Bool = true;

    var _subscriptions:Array<Subscription>;

    public var autoScroll:AutoScroll;

    /**
     * Build the engine in the given mode (Rust `new_in_mode`). Each mode's
     * own constructor (`InputState`, `TextareaState`, `EditorState`) sets
     * its layout on top of this.
     */
    public function new(modeKind:InputModeKind, window:Window, cx:Context<Dynamic>) {
        super();
        final cx:Context<InputBaseState> = cast cx;
        this.modeKind = modeKind;

        final focusHandle = cx.focusHandle().tabStop(true);
        final blinkCursor = cx.newEntity(cx -> new BlinkCursor(cx));
        final undoManager = new UndoManager();

        _subscriptions = [
            // Key bindings can consume events before on_key_down. Observe input
            // before action dispatch so every keystroke resets the blink delay.
            @:privateAccess cx.ownSubscription(cx.app.interceptKeystrokes((_, window, cx) -> {
                if (focusHandle.isFocused(window)) {
                    if (!(blinkCursor : BlinkCursor).destroyed) {
                        blinkCursor.update(cx, (cursor, cx) -> cursor.pause(cx));
                    }
                }
            })),
            // Observe the blink cursor to repaint the view when it changes.
            cx.observe(blinkCursor, (_, _, cx) -> cx.notify()),
            // Blink the cursor when the window is active, pause when it's not.
            cx.observeWindowActivation(window, (input, window, cx) -> {
                if (window.isWindowActive()) {
                    final focusHandle = input.focusHandle;
                    if (focusHandle.isFocused(window)) {
                        input.blinkCursor.update(cx, (blinkCursor, cx) -> {
                            blinkCursor.start(cx);
                        });
                    }
                }
            }),
            cx.onFocus(focusHandle, window, (input, window, cx) -> input.onFocus(window, cx)),
            cx.onBlur(focusHandle, window, (input, window, cx) -> input.onBlur(window, cx)),
        ];

        final textStyle = window.textStyle();

        this.extras = modeKind.newExtras();
        this.focusHandle = focusHandle;
        this.text = Rope.fromStr("");
        this.displayMap = new DisplayMap(textStyle.font(), window.remSize(), null);
        this.searchSession = new SearchSession();
        this.blinkCursor = blinkCursor;
        this.undoManager = undoManager;
        this.tokenPresentation = new InlineTokenPresentation();
        this.selections = Selections.defaultValue();
        this.inputBounds = new Bounds(new Point(0, 0), new Size(0, 0));
        this.touchSelection = new TouchSelection();
        this.mode = LayoutMode.defaultValue();
        this.scrollHandle = new ScrollHandle();
        this.scrollBounce = ScrollBounce.enabledByDefault();
        this.overscroll = new Overscroll();
        this.scrollSize = new Size(0, 0);
        this.editorPaddings = new Edges();
        this.editorStyle = InputEditorStyle.defaultValue();
        this.projectedEditorStyle = InputEditorStyle.defaultValue();
        this.autoScroll = new AutoScroll();
    }

    inline function typedCx(cx:Context<Dynamic>):Context<InputBaseState> {
        return cast cx;
    }

    /** The cursor bounds and line height of the last layout. */
    public function cursorLayout():Null<CursorLayoutResult> {
        final layout = lastLayout;
        if (layout == null || layout.cursorBounds == null)
            return null;
        return {bounds: layout.cursorBounds, lineHeight: layout.lineHeight};
    }

    /** Rust `text_bounds()`: the text bounds of the last layout. */
    public inline function textBounds():Null<Bounds> {
        return lastBounds;
    }

    /**
     * Wrap the text for `font`, `fontSize` and `width` before the first
     * layout, so that `DisplayMap.wrapRowCount` is known on the first frame.
     *
     * Call it after setting the value and the wrapping indent. `width` is the
     * width of the input's text area. Once the input has been laid out this
     * does nothing, and layout keeps the wrap up to date.
     */
    public function prewrap(font:glaze.Font, fontSize:Pixels, width:Pixels, cx:Context<InputBaseState>):Void {
        if (lastLayout != null) {
            return;
        }
        final wrapWidth = Math.max(width - TextElement.RIGHT_MARGIN, 1.);
        displayMap.setFont(font, fontSize, cx.app);
        displayMap.setTabSize(mode.tabSize().tabSize, cx.app);
        displayMap.onLayoutChanged(softWrap ? wrapWidth : null, cx.app);
        displayMap.setWrappingIndent(wrappingIndent, cx.app);
        displayMap.ensureTextPrepared(text, cx.app);
    }

    public function presentation():InputPresentation {
        return new InputPresentation(focusHandle, disabled, readonly, loading, masked, isMultiLine(), isCodeEditor(), textAlign, placeholder,
            maskPattern.placeholder());
    }

    /**
     * Whether this input paints scrollbars.
     *
     * Only a multi-line input can scroll: a single-line input keeps its
     * caret in view by moving its own offset.
     */
    public inline function showsScrollbar():Bool {
        return isMultiLine();
    }

    /** Whether this input spans more than one line (answered by the mode). */
    public inline function isMultiLine():Bool {
        return modeKind.multiLine();
    }

    /** Whether this input is a single-line text field. */
    public inline function isSingleLine():Bool {
        return !modeKind.multiLine();
    }

    /** Whether this input is a source-code editor. */
    public inline function isCodeEditor():Bool {
        return modeKind.codeEditor();
    }

    /**
     * Whether the user is allowed to copy the selection out.
     *
     * A masked input keeps its value out of the clipboard.
     */
    public function isCopyable():Bool {
        for (sel in selections.iter()) {
            if (!sel.isEmpty())
                return !masked;
        }
        return false;
    }

    public function contextMenuCapabilities():InputContextMenuCapabilities {
        final support = extras.contextMenuCapabilities();
        return new InputContextMenuCapabilities()
            .disabled(disabled)
            .readonly(readonly)
            .codeEditor(isCodeEditor())
            .selection(!activeSelection().isEmpty())
            .masked(masked)
            .goToDefinition(support.goToDefinition)
            .codeActions(support.codeActions);
    }

    public function setTextAlign(textAlign:TextAlign, cx:Context<InputBaseState>):Void {
        if (!isSingleLine() || this.textAlign == textAlign) {
            return;
        }

        this.textAlign = textAlign;
        cx.notify();
    }

    /** Flip the password mask. */
    public function toggleMasked(window:Window, cx:Context<InputBaseState>):Void {
        masked = !masked;
        cx.notify();
    }

    public function onContextMenu(handler:ContextMenuHandler):Void {
        contextMenuHandler = handler;
    }

    /**
     * Keeps the selection highlighted while this popup or one of its children has focus.
     *
     * This does not transfer keyboard focus or keep the caret visible. Pass
     * `null` to clear it.
     */
    public function setSelectionFocus(focus:Null<FocusHandle>, cx:Context<InputBaseState>):Void {
        selectionFocus = focus != null ? focus.downgrade() : null;
        cx.notify();
    }

    /** Whether the input or its associated selection popup has focus. */
    public function hasSelectionFocus(window:Window, cx:App):Bool {
        if (focusHandle.isFocused(window))
            return true;
        final focus = selectionFocus;
        return focus != null && (focus.isFocused(window) || focus.containsFocused(window, cx));
    }

    /**
     * Sets whether the context menu that shows on right-click is enabled.
     *
     * The context menu is enabled by default.
     */
    public function contextMenu(enable:Bool):InputBaseState {
        enableContextMenu = enable;
        return this;
    }

    public function setContextMenuEnabled(enabled:Bool):Void {
        enableContextMenu = enabled;
    }

    /** Set whether search UI allows replacement, default is true. */
    public function withReplaceable(allow:Bool):InputBaseState {
        replaceable = allow;
        return this;
    }

    /** Set placeholder. */
    public function withPlaceholder(placeholder:String):InputBaseState {
        this.placeholder = placeholder;
        return this;
    }

    /** Set highlighter language for the code editor mode. */
    public function setHighlighter(newLanguage:String, cx:Context<InputBaseState>):Void {
        if (mode.kind == CodeEditor) {
            mode.language.setName(newLanguage);
            mode._highlighter.value = null;
        }
        refresh(cx);
    }

    function resetHighlighter(cx:Context<InputBaseState>):Void {
        if (mode.kind == CodeEditor) {
            mode._highlighter.value = null;
        }
        cx.notify();
    }

    /** Install the parser/highlighter adapter used by code-editor mode. */
    public function setHighlighterFactory(factory:InputHighlighterFactory, cx:Context<InputBaseState>):Void {
        mode.setHighlighterFactory(factory);
        _pendingUpdate = true;
        tokenLayoutCache = null;
        cx.notify();
    }

    /** Install a default adapter without replacing an application-provided one. */
    public function ensureHighlighterFactory(factory:InputHighlighterFactory):Void {
        mode.ensureHighlighterFactory(factory);
    }

    public function setEditorStyle(style:InputEditorStyle):Void {
        editorStyle = style.clone();
        projectedEditorStyle = style;
    }

    /** Project semantics onto the editor, never onto a second focus owner. */
    public function setAccessibility(accessibility:InputAccessibility):Void {
        this.accessibility = accessibility;
    }

    function handleAccessibilityFocus(window:Window, cx:Context<InputBaseState>):Void {
        if (!disabled) {
            focus(window, cx);
        }
    }

    /**
     * Rust takes `Option<&accesskit::ActionData>` and only acts on
     * `ActionData::Value`: the port takes that value, or null.
     */
    function handleAccessibilitySetValue(value:Null<String>, window:Window, cx:Context<InputBaseState>):Void {
        if (value == null) {
            return;
        }
        // The action may have been queued before editability changed.
        if (isEditable()) {
            replaceAll(value, window, cx);
        }
    }

    /** Set presentation padding for multi-line text and its scrollbar layout. */
    public function setEditorPaddings(paddings:Edges):Void {
        editorPaddings = paddings;
    }

    /**
     * Supply the element painted in place of the editor's scrollbar, or
     * `null` to keep Base's. Like `setEditorStyle`, this does not notify, so
     * it can be called while rendering.
     */
    public function setScrollbarRenderer(renderer:Null<glaze.kit.base.input.EditorScrollbarContext.EditorScrollbarRenderer>):Void {
        scrollbarRenderer = renderer;
    }

    public function applyHighlighterFoldCandidates(candidates:Array<FoldRange>, cx:Context<InputBaseState>):Void {
        if (mode.isFolding()) {
            displayMap.setFoldCandidates(candidates);
        }
        cx.notify();
    }

    public inline function diagnostics():Null<DiagnosticSet> {
        return mode.diagnostics();
    }

    public inline function diagnosticsMut():Null<DiagnosticSet> {
        return mode.diagnosticsMut();
    }

    /** Set placeholder. */
    public function setPlaceholder(placeholder:String, window:Window, cx:Context<InputBaseState>):Void {
        this.placeholder = placeholder;
        cx.notify();
    }

    /**
     * Find which line and sub-line the given offset belongs to, along with
     * the position within that sub-line.
     */
    public function lineAndPositionForOffset(offset:Int):LinePosition {
        final lastLayout = this.lastLayout;
        if (lastLayout == null) {
            return {line: 0, localRow: 0, position: null};
        }
        final lineHeight = lastLayout.lineHeight;

        var yOffset:Float = lastLayout.visibleTop;
        for (vi in 0...lastLayout.lines.length) {
            final line = lastLayout.lines[vi];
            final prevLinesOffset = lastLayout.visibleLineByteOffsets[vi];
            final localOffset = saturatingSub(offset, prevLinesOffset);
            final pos = line.positionForIndex(localOffset, lastLayout, false);
            if (pos != null) {
                final subLineIndex = Std.int((pos.y : Float) / (lineHeight : Float));
                final adjustedPos = new Point(pos.x + lastLayout.lineNumberWidth, pos.y + yOffset);
                return {line: vi, localRow: subLineIndex, position: adjustedPos};
            }

            yOffset += line.size(lineHeight).height;
        }
        return {line: 0, localRow: 0, position: null};
    }

    /**
     * Set the value of the input field: plain text, or `InputContent` to
     * restore text together with its inline tokens. Editing history is
     * cleared and no `InputEvent.Change` is emitted.
     *
     * For single-line inputs the caret is placed at the end of the text while
     * the view is scrolled back to the start. Multi-line inputs reset the
     * selection to `0..0`.
     */
    public function setValue(value:glaze.kit.base.input.InputContent.IntoInputContent, window:Window, cx:Context<InputBaseState>):Void {
        final content:InputContent = value;
        inlineTokens = null;
        undoManager.setIgnoring(true);
        emitEvents = false;
        replaceText(content.text(), window, cx);
        this.installTokens(content);
        undoManager.setIgnoring(false);
        emitEvents = true;

        resetSelection();
        resetLspState();
        resetScrollToStart();

        undoManager.clear();
        cx.notify();
    }

    /**
     * Replace the entire text content while preserving undo history.
     *
     * The selection is placed at the end of the new text for single-line
     * inputs, or cleared (0..0) for multi-line inputs.
     */
    public function replaceAll(text:String, window:Window, cx:Context<InputBaseState>):Void {
        replaceText(text, window, cx);
        resetSelection();
        resetLspState();
        resetScrollToStart();

        cx.notify();
    }

    /**
     * Perform `f` with the user-facing edit restrictions lifted.
     *
     * The `disabled` and `readonly` modes only reject the changes made by the
     * user, the programmatic APIs must always be able to update the text.
     */
    public function withEditsAllowed(f:(InputBaseState) -> Void):Void {
        final wasDisabled = disabled;
        final wasReadonly = readonly;
        disabled = false;
        readonly = false;
        f(this);
        disabled = wasDisabled;
        readonly = wasReadonly;
    }

    /**
     * Insert text at the current cursor position.
     *
     * And the cursor will be moved to the end of inserted text.
     */
    public function insert(text:String, window:Window, cx:Context<InputBaseState>):Void {
        withEditsAllowed(this_ -> {
            this_.undoManager.setPendingIntent(EditIntent.Atomic);
            final rangeUtf16 = this_.rangeToUtf16(new Range(this_.cursor(), this_.cursor()));
            this_.replaceTextInRangeSilent(rangeUtf16, text, window, cx);
            final end = this_.activeSelection().end;
            this_.setCursorTo(end);
        });
    }

    /**
     * Replace text at the current cursor position.
     *
     * And the cursor will be moved to the end of replaced text.
     */
    public function replace(text:String, window:Window, cx:Context<InputBaseState>):Void {
        withEditsAllowed(this_ -> {
            this_.undoManager.setPendingIntent(EditIntent.Atomic);
            this_.replaceTextInRangeSilent(null, text, window, cx);
            final end = this_.activeSelection().end;
            this_.setCursorTo(end);
        });
    }

    function replaceText(text:String, window:Window, cx:Context<InputBaseState>):Void {
        withEditsAllowed(this_ -> {
            this_.undoManager.setPendingIntent(EditIntent.Atomic);
            final range = new Range(0, this_.text.lenUtf16());
            this_.replaceTextInRangeSilent(range, text, window, cx);
            this_.resetHighlighter(cx);
        });
    }

    function resetSelection():Void {
        selections.removeAllButActive();

        // For single-line inputs the caret is placed at the end of the text
        // (matching HTML `<input>`); multi-line inputs reset the selection to
        // `0..0`.
        if (isSingleLine()) {
            final end = text.len();
            setCursorTo(end);
        }
        else {
            activeSelectionMut().clear();
        }
    }

    function resetLspState():Void {
        if (isCodeEditor()) {
            _pendingUpdate = true;
            modeKind.resetLanguageFeatures(this);
        }
    }

    function resetScrollToStart():Void {
        // Move scroll to the start. For single-line the caret is at the end, so
        // override the cursor-follow scroll for the next painted frame to keep
        // the start visible; the deferred offset is consumed during that paint.
        scrollHandle.setOffset(new Point(0, 0));
        if (isSingleLine()) {
            deferredScrollOffset = new Point(0, 0);
        }
    }

    /** Set with disabled mode. See also: `setDisabled`. */
    public function withDisabled(disabled:Bool):InputBaseState {
        this.disabled = disabled;
        return this;
    }

    public function setDisabled(disabled:Bool, cx:Context<InputBaseState>):Void {
        if (this.disabled == disabled) {
            return;
        }

        this.disabled = disabled;
        if (disabled) {
            modeKind.hideContextMenu(this, cx);
            modeKind.clearInlineCompletion(this, cx);
        }
        cx.notify();
    }

    /**
     * Set with read-only mode.
     *
     * Unlike `disabled`, a read-only input keeps the normal appearance,
     * focus, cursor, selection and copy behavior, it only rejects any change
     * of the text made by the user.
     */
    public function withReadonly(readonly:Bool):InputBaseState {
        this.readonly = readonly;
        return this;
    }

    public function setReadonly(readonly:Bool, cx:Context<InputBaseState>):Void {
        if (this.readonly == readonly) {
            return;
        }

        this.readonly = readonly;
        if (readonly) {
            modeKind.hideContextMenu(this, cx);
            modeKind.clearInlineCompletion(this, cx);
            searchSession.replaceMode = false;
        }
        cx.notify();
    }

    /**
     * Returns true if the user is allowed to change the text.
     *
     * This is false when the input is `disabled` or `readonly`, the
     * programmatic APIs (e.g.: `setValue`, `insert`) are not limited by this.
     */
    public inline function isEditable():Bool {
        return !disabled && !readonly;
    }

    /** Set true to clear the input by pressing Escape key. */
    public function withCleanOnEscape():InputBaseState {
        cleanOnEscape = true;
        return this;
    }

    public function setCleanOnEscape(clean:Bool):Void {
        cleanOnEscape = clean;
    }

    /**
     * Set true to treat `Enter` as a submit action in multi-line mode,
     * while `Shift+Enter` inserts a newline.
     */
    public function withSubmitOnEnter(submit:Bool):InputBaseState {
        submitOnEnter = submit;
        return this;
    }

    public function setSubmitOnEnter(submit:Bool, cx:Context<InputBaseState>):Void {
        submitOnEnter = submit;
        cx.notify();
    }

    /**
     * Set the action a software keyboard shows on its enter key, like Search
     * or Send. Pressing it still emits `InputEvent.PressEnter`.
     */
    public function withInputAction(action:TextInputAction):InputBaseState {
        inputAction = action;
        return this;
    }

    /**
     * Set whether the platform may autocorrect the text and offer word
     * suggestions. Default is `false`.
     */
    public function withAutocorrect(autocorrect:Bool):InputBaseState {
        this.autocorrect = autocorrect;
        return this;
    }

    /** Set how a software keyboard capitalizes the text. Default is `None`. */
    public function withAutocapitalize(autocapitalize:Autocapitalize):InputBaseState {
        this.autocapitalize = autocapitalize;
        return this;
    }

    /**
     * The text assistance a platform IME (a software keyboard) should give
     * this input. Also the `EntityInputHandler` method (Rust has both, the
     * inherent one without arguments): the arguments are unused, pass null.
     */
    public function textInputConfiguration(window:Null<Window>, cx:Null<Context<Dynamic>>):TextInputConfiguration {
        // Masking is a presentation choice, not a reliable content type: a
        // revealed password must not acquire text assistance. Keep assistance
        // opt-in for structured fields such as passwords, email and URLs.
        final autocorrect = this.autocorrect != null ? this.autocorrect : false;
        final inputAction = this.inputAction != null ? this.inputAction : (isMultiLine() && !submitOnEnter ? TextInputAction.Enter : TextInputAction.Done);
        // Modified for Glaze (DEV-017): the input mode
        return new TextInputConfiguration(autocorrect, autocapitalize != null ? autocapitalize : Autocapitalize.None, autocorrect, inputAction, numberInputMode());
    }

    /**
     * Initial port deviation DEV-017: the software keyboard suited to what a
     * number field (a single-line input with a number mask, which
     * `NumberInput` sets) accepts. The numeric and decimal keypads of iOS
     * have no minus sign, so a field that may hold a negative value (no
     * `min`, or a negative one) keeps the text keyboard. A field whose mask
     * drops the fraction (a group separator with `fraction` 0) takes digits
     * only. Any other takes a decimal separator too: the decimal keypad shows
     * the separator of the device's region (a comma in many), which is a
     * decimal separator only when the mask does not group digits with a comma
     * or a dot (DEV-018), so a mask grouping with either keeps the text
     * keyboard. A `pattern` or `validate` check can only narrow what the
     * mask accepts.
     */
    function numberInputMode():TextInputMode {
        switch maskPattern {
            case Number(separator, fraction):
                final min = numberMin;
                if (!isSingleLine() || min == null || !(min >= 0)) {
                    return TextInputMode.Text;
                }
                if (separator != null && fraction == 0) {
                    return TextInputMode.Numeric;
                }
                return MaskPatternTools.commaIsDecimal(separator) ? TextInputMode.Decimal : TextInputMode.Text;
            case _:
                return TextInputMode.Text;
        }
    }

    /** Set whether to show whitespace characters. */
    public function withShowWhitespaces(show:Bool):InputBaseState {
        showWhitespaces = show;
        return this;
    }

    /** Update whether to show whitespace characters. */
    public function setShowWhitespaces(show:Bool, window:Window, cx:Context<InputBaseState>):Void {
        showWhitespaces = show;
        cx.notify();
    }

    /**
     * Empty rows reserved below the last line of content ("scroll beyond
     * last line"), code-editor mode only.
     *
     * - `null` (default): half the viewport, floored at `BOTTOM_MARGIN_ROWS` line-heights.
     * - `0`: no trailing space.
     * - `n`: exactly `n` rows.
     */
    public function withScrollBeyondLastLine(rows:Null<Int>):InputBaseState {
        scrollBeyondLastLine = rows;
        return this;
    }

    /** Update `scrollBeyondLastLine` after construction. */
    public function setScrollBeyondLastLine(rows:Null<Int>, window:Window, cx:Context<InputBaseState>):Void {
        if (scrollBeyondLastLine == rows) {
            return;
        }
        scrollBeyondLastLine = rows;
        cx.notify();
    }

    /**
     * Minimum number of lines the cursor is kept clear of the viewport's
     * top/bottom edge before auto-scroll engages.
     */
    public function withCursorSurroundingLines(lines:Null<Int>):InputBaseState {
        cursorSurroundingLines = lines;
        return this;
    }

    /** Update `cursorSurroundingLines` after construction. */
    public function setCursorSurroundingLines(lines:Null<Int>, window:Window, cx:Context<InputBaseState>):Void {
        if (cursorSurroundingLines == lines) {
            return;
        }
        cursorSurroundingLines = lines;
        cx.notify();
    }

    /** Set the default value of the input field. */
    public function defaultValue(value:String):InputBaseState {
        text = Rope.fromStr(normalizeInput(value));
        final diagnostics = mode.diagnosticsMut();
        if (diagnostics != null) {
            diagnostics.reset(text);
        }
        // Note: We can't call display_map.set_text here because it needs cx.
        // The text will be set during prepare_if_need in element.rs
        _pendingUpdate = true;
        return this;
    }

    /** Return the value of the input field as a string. */
    public function value():String {
        return text.toString();
    }

    /** Return the portion of the value that is selected by the user. */
    public function selectedValue():String {
        return selectedText().toString();
    }

    /** Return the value without mask. */
    public function unmaskValue():String {
        return maskPattern.unmask(text.toString());
    }

    /** Kept so existing render paths keep compiling; does nothing. */
    public function prepare(window:Window, cx:Context<InputBaseState>):Void {}

    /** Return the (0-based) `LspPosition` of the cursor. */
    public function cursorPosition():LspPosition {
        final offset = cursor();
        return text.offsetToPosition(offset);
    }

    /**
     * Set (0-based) `LspPosition` of the cursor.
     *
     * This will move the cursor to the specified line and column, and update the selection range.
     */
    public function setCursorPosition(position:LspPosition, window:Window, cx:Context<InputBaseState>):Void {
        final offset = text.positionToOffset(position);

        this.moveTo(offset, null, cx);
        this.updatePreferredColumn();
        focus(window, cx);
    }

    /** Focus the input field. */
    public function focus(window:Window, cx:Context<InputBaseState>):Void {
        focusHandle.focus(window, cx.app);
        blinkCursor.update(cx, (cursor, cx) -> {
            cursor.start(cx);
        });
    }

    /**
     * Refresh the input, so the next render re-runs syntax highlighting and
     * the LSP providers, not just a redraw.
     */
    public function refresh(cx:Context<InputBaseState>):Void {
        _pendingUpdate = true;
        cx.notify();
    }

    public function selectLeft(_:SelectLeft, window:Window, cx:Context<InputBaseState>):Void {
        undoManager.breakTransactionCoalescing();
        selectAllCursorsTo((s, sel) -> s.previousBoundary(sel.cursorOffset()), cx);
    }

    public function selectRight(_:SelectRight, window:Window, cx:Context<InputBaseState>):Void {
        selectAllCursorsTo((s, sel) -> s.nextBoundary(sel.cursorOffset()), cx);
    }

    public function selectUp(_:SelectUp, window:Window, cx:Context<InputBaseState>):Void {
        if (isSingleLine()) {
            return;
        }
        selectAllCursorsToWithAffinity((s, sel) -> {
            final target = s.verticalSelectionTarget(sel.cursorOffset(), sel.columnAnchor, s.lineEndAffinityFor(sel), -1);
            return {offset: target.offset, lineEndAffinity: target.lineEndAffinity};
        }, true, cx);
    }

    public function selectDown(_:SelectDown, window:Window, cx:Context<InputBaseState>):Void {
        if (isSingleLine()) {
            return;
        }
        selectAllCursorsToWithAffinity((s, sel) -> {
            final target = s.verticalSelectionTarget(sel.cursorOffset(), sel.columnAnchor, s.lineEndAffinityFor(sel), 1);
            return {offset: target.offset, lineEndAffinity: target.lineEndAffinity};
        }, true, cx);
    }

    public function onActionSelectAll(_:SelectAll, window:Window, cx:Context<InputBaseState>):Void {
        selectAll(window, cx);
    }

    public function selectToStart(_:SelectToStart, window:Window, cx:Context<InputBaseState>):Void {
        undoManager.breakTransactionCoalescing();
        selectAllCursorsTo((_, _) -> 0, cx);
    }

    public function selectToEnd(_:SelectToEnd, window:Window, cx:Context<InputBaseState>):Void {
        undoManager.breakTransactionCoalescing();
        final end = text.len();
        selectAllCursorsTo((_, _) -> end, cx);
    }

    public function selectToStartOfLine(_:SelectToStartOfLine, window:Window, cx:Context<InputBaseState>):Void {
        undoManager.breakTransactionCoalescing();
        selectAllCursorsTo((s, sel) -> s.startOfLineAt(sel.cursorOffset(), s.lineEndAffinityFor(sel)), cx);
    }

    public function selectToEndOfLine(_:SelectToEndOfLine, window:Window, cx:Context<InputBaseState>):Void {
        undoManager.breakTransactionCoalescing();
        selectAllCursorsToWithAffinity((s, sel) -> {
            return {offset: s.endOfLineAt(sel.cursorOffset(), s.lineEndAffinityFor(sel)), lineEndAffinity: true};
        }, false, cx);
    }

    public function selectToPreviousWord(_:SelectToPreviousWordStart, window:Window, cx:Context<InputBaseState>):Void {
        undoManager.breakTransactionCoalescing();
        selectAllCursorsTo((s, sel) -> s.previousStartOfWordAt(sel.cursorOffset()), cx);
    }

    public function selectToNextWord(_:SelectToNextWordEnd, window:Window, cx:Context<InputBaseState>):Void {
        undoManager.breakTransactionCoalescing();
        selectAllCursorsTo((s, sel) -> s.nextEndOfWordAt(sel.cursorOffset()), cx);
    }

    /** Return the previous start offset of the word before `offset`. */
    public function previousStartOfWordAt(offset:Int):Int {
        if (masked) {
            // The mask replaces every character, so the displayed text has no
            // word boundaries to move or delete by. Collapse the word to the
            // whole text.
            return 0;
        }

        final offset = offsetFromUtf16(offsetToUtf16(offset));
        // FIXME: Avoid to_string
        final leftPart = text.slice(0, offset).toString();

        var target = 0;
        final iter = UnicodeSegmentation.splitWordBoundIndices(leftPart);
        while (true) {
            final s = iter.next();
            if (s == null)
                break;
            if (!isAllWhitespace(s))
                target = iter.index;
        }
        return this.tokenBoundary(target, Bias.Left);
    }

    /** Return the next end offset of the word after `offset`. */
    public function nextEndOfWordAt(offset:Int):Int {
        if (masked) {
            // See `previousStartOfWordAt`.
            return text.len();
        }

        final offset = offsetFromUtf16(offsetToUtf16(offset));
        final rightPart = text.slice(offset, text.len()).toString();

        var target = text.len();
        final iter = UnicodeSegmentation.splitWordBoundIndices(rightPart);
        while (true) {
            final s = iter.next();
            if (s == null)
                break;
            if (!isAllWhitespace(s)) {
                target = offset + iter.index + Utf8.byteLength(s);
                break;
            }
        }
        return this.tokenBoundary(target, Bias.Right);
    }

    /** Rust `s.trim_start().is_empty()`. */
    static function isAllWhitespace(s:String):Bool {
        for (c in new haxe.iterators.StringIteratorUnicode(s)) {
            if (!Utf8.isWhitespace(c))
                return false;
        }
        return true;
    }

    /**
     * Get start of line byte offset for the given `offset`.
     *
     * When soft wrap is active, first press goes to visual line start,
     * second press (already at visual start) goes to logical line start.
     */
    public function startOfLineAt(offset:Int, lineEndAffinity:Bool):Int {
        if (isSingleLine()) {
            return 0;
        }

        final row = text.offsetToPoint(offset).row;
        final logicalStart = text.lineStartOffset(row);

        if (softWrap && isCodeEditor()) {
            final wrapPoint = displayMap.offsetToWrapDisplayPointWithAffinity(offset, lineEndAffinity);
            final line = displayMap.line(row);
            if (line != null && wrapPoint.localRow < line.wrappedLines.length) {
                final range = line.wrappedLines[wrapPoint.localRow];
                final visualStart = logicalStart + range.start;
                if (offset != visualStart) {
                    return visualStart;
                }
            }
        }

        return logicalStart;
    }

    /**
     * Get end of line byte offset for the given `offset`.
     *
     * When soft wrap is active, first press goes to visual line end,
     * second press (already at visual end) goes to logical line end.
     */
    public function endOfLineAt(offset:Int, lineEndAffinity:Bool):Int {
        if (isSingleLine()) {
            return text.len();
        }

        final row = text.offsetToPoint(offset).row;
        final logicalStart = text.lineStartOffset(row);
        final logicalEnd = text.lineEndOffset(row);

        if (softWrap && isCodeEditor()) {
            // Use the row the caret is drawn on: at a wrap boundary the raw offset would name
            // the next row, and a second End press would keep walking down instead of falling
            // through to the logical line end.
            final wrapPoint = displayMap.offsetToWrapDisplayPointWithAffinity(offset, lineEndAffinity);
            final line = displayMap.line(row);
            if (line != null && wrapPoint.localRow < line.wrappedLines.length) {
                final range = line.wrappedLines[wrapPoint.localRow];
                final visualEnd = logicalStart + range.end;
                if (offset != visualEnd) {
                    return visualEnd;
                }
            }
        }

        return logicalEnd;
    }

    /**
     * Get indent string of next line.
     *
     * To get current and next line indent, to return more depth one.
     */
    public function indentOfNextLine():String {
        return indentOfNextLineAt(cursor());
    }

    /** Get indent string of the next line, relative to the given `offset`. */
    public function indentOfNextLineAt(offset:Int):String {
        if (isSingleLine()) {
            return "";
        }

        var currentIndent = new StringBuf();
        var currentIndentLen = 0;
        final nextIndent = new StringBuf();
        var nextIndentLen = 0;
        final lineEndAffinity = this.lineEndAffinityAt(offset);
        final currentLineStartPos = startOfLineAt(offset, lineEndAffinity);
        final nextLineStartPos = endOfLineAt(offset, lineEndAffinity);
        final chars = text.sliceFrom(currentLineStartPos).chars();
        while (true) {
            final c = chars.next();
            if (c == -1 || !Utf8.isWhitespace(c))
                break;
            if (c == '\n'.code || c == '\r'.code)
                break;
            currentIndent.addChar(c);
            currentIndentLen += Utf8.codePointLength(c);
        }

        final chars = text.sliceFrom(nextLineStartPos).chars();
        while (true) {
            final c = chars.next();
            if (c == -1 || !Utf8.isWhitespace(c))
                break;
            if (c == '\n'.code || c == '\r'.code)
                break;
            nextIndent.addChar(c);
            nextIndentLen += Utf8.codePointLength(c);
        }

        if (nextIndentLen > currentIndentLen) {
            return nextIndent.toString();
        }

        var current = currentIndent.toString();

        // Smart indent: one extra level after lines ending with a trigger.
        // Skipped inside strings and comments: the trigger is literal text.
        final rules = mode.languageConfig();
        if (rules != null) {
            if (mode.isSmartIndent() && modeKind.editingSyntaxContext(this, offset) == SyntaxContext.Code) {
                final lineBefore = text.slice(currentLineStartPos, offset).toString();
                if (rules.opensIndent(StringTools.rtrim(lineBefore))) {
                    final tab = mode.tabSize();
                    if (tab.hardTabs) {
                        current += "\t";
                    }
                    else {
                        for (_ in 0...tab.tabSize) {
                            current += " ";
                        }
                    }
                }
                else {
                    final lineAfter = text.slice(offset, nextLineStartPos).toString();
                    if (rules.closesIndent(lineAfter)) {
                        final tab = mode.tabSize();
                        if (StringTools.endsWith(current, "\t")) {
                            current = current.substr(0, current.length - 1);
                        }
                        else {
                            for (_ in 0...tab.tabSize) {
                                if (!StringTools.endsWith(current, " ")) {
                                    break;
                                }
                                current = current.substr(0, current.length - 1);
                            }
                        }
                    }
                }
            }
        }

        return current;
    }

    /**
     * Delete every selection as one batch. Collapsed cursors are first
     * expanded to a deletion range by `collapsedTarget` and non-empty
     * selections delete their own range.
     *
     * `collapsedIntent` is the intent to record when every cursor is
     * collapsed, which is what makes a run of single-character deletes undo
     * as one gesture. Deleting a real selection is always atomic.
     */
    function deleteSelections(silent:Bool, collapsedIntent:EditIntent, collapsedTarget:(InputBaseState, Int) -> Range, window:Window,
            cx:Context<InputBaseState>):Void {
        if (!isEditable()) {
            return;
        }
        final cursors:Array<CursorSelection> = CursorSelection.copyAll(selections.iter());
        var allEmpty = true;
        for (sel in cursors) {
            if (!sel.isEmpty()) {
                allEmpty = false;
                break;
            }
        }
        final intent = allEmpty ? collapsedIntent : EditIntent.Atomic;
        final newSelections:Array<CursorSelection> = [];
        for (sel in cursors) {
            final range = sel.isEmpty() ? collapsedTarget(this, sel.cursorOffset()) : new Range(sel.start, sel.end);
            final start = range.start < range.end ? range.start : range.end;
            final end = range.start > range.end ? range.start : range.end;
            final selection = sel.copy();
            selection.start = start;
            selection.end = end;
            newSelections.push(selection);
        }
        // Capture the user's selections before expanding or merging deletion
        // ranges. The edit ranges cannot reconstruct their original carets.
        undoManager.beginTransactionWith(intent);
        undoManager.recordSelections(CursorSelection.copyAll(cursors), CursorSelection.copyAll(cursors));
        selections.replaceAll(newSelections);
        undoManager.setPendingIntent(intent);

        final wasSilent = silentReplaceText;
        silentReplaceText = silent;
        replaceTextInRange(null, "", window, cx);
        silentReplaceText = wasSilent;
        undoManager.recordSelections(cursors, CursorSelection.copyAll(selections.iter()));
        undoManager.commitTransaction();
        pauseBlinkCursor(cx);
    }

    /**
     * Decide pairing against the pre-edit text, before an opening quote can
     * change its own syntax context. Ordinary characters never query syntax.
     * Returns the length of the opener and the closer, or null.
     */
    function autoCloseTarget(range:Range, text:String):Null<{openLen:Int, closer:String}> {
        if (silentReplaceText
            || imeMarkedRange != null
            || !selections.isSingle()
            || !activeSelection().isEmpty()
            || !range.isEmpty()
            || range.start != cursor()
            || charCount(text) != 1
            || !mode.isAutoClose()) {
            return null;
        }
        final rules = mode.languageConfig();
        if (rules == null)
            return null;
        final next = this.text.charsAt(range.start).next();
        if (next != -1 && !Utf8.isWhitespace(next) && !stringContainsChar(rules.autoCloseBefore, next)) {
            return null;
        }
        for (pair in rules.closingPairs()) {
            final open = pair.open;
            final close = pair.close;
            if (!StringTools.endsWith(open, text)) {
                continue;
            }
            final prefix = open.substr(0, open.length - text.length);
            if (!textBeforeMatches(range.start, prefix)) {
                continue;
            }
            final start = range.start - Utf8.byteLength(prefix);
            if (open == close) {
                if (isEscapedAt(start))
                    continue;
                final before = this.text.charsAt(start).reversed().next();
                if (before != -1 && (isAlphanumeric(before) || before == '_'.code))
                    continue;
            }
            if (pair.notIn.indexOf(modeKind.editingSyntaxContext(this, start)) != -1) {
                continue;
            }
            return {openLen: Utf8.byteLength(open), closer: close};
        }
        return null;
    }

    function textBeforeMatches(offset:Int, text:String):Bool {
        final len = Utf8.byteLength(text);
        return offset >= len && this.text.isCharBoundary(offset - len) && this.text.slice(offset - len, offset).equalsStr(text);
    }

    function textAfterMatches(offset:Int, text:String):Bool {
        final len = Utf8.byteLength(text);
        return offset + len <= this.text.len() && this.text.isCharBoundary(offset + len) && this.text.slice(offset, offset + len).equalsStr(text);
    }

    function isEscapedAt(offset:Int):Bool {
        final chars = text.charsAt(offset).reversed();
        var count = 0;
        while (chars.next() == '\\'.code) {
            count++;
        }
        return count % 2 == 1;
    }

    /**
     * Cursor target when a typed closer should skip over an existing one.
     *
     * Returns the offset when `newText` is a single closer from the active
     * `LanguageConfig` that already follows the collapsed cursor and is not
     * escaped. The caller then moves the cursor without editing text or
     * history. `null` means insert normally.
     */
    function skipOverTarget(newText:String):Null<Int> {
        if (!mode.isAutoClose() || charCount(newText) != 1) {
            return null;
        }
        final rules = mode.languageConfig();
        if (rules == null)
            return null;
        final cursor = cursor();
        final newTextLen = Utf8.byteLength(newText);
        for (pair in rules.closingPairs()) {
            final open = pair.open;
            final close = pair.close;
            final closeLen = Utf8.byteLength(close);
            var index = 0;
            for (c in new haxe.iterators.StringIteratorUnicode(close)) {
                final rest = Utf8.substringFrom(close, index);
                final head = Utf8.substring(close, 0, index);
                final charIndex = index;
                index += Utf8.codePointLength(c);
                if (!StringTools.startsWith(rest, newText) || !textBeforeMatches(cursor, head) || !textAfterMatches(cursor, rest)) {
                    continue;
                }
                final context = modeKind.editingSyntaxContext(this, cursor);
                final generated = mode.autoClosedPairs().containsCloser(cursor, charIndex, closeLen);
                if (!generated && pair.notIn.indexOf(context) != -1 && !(context == SyntaxContext.String && open == close)) {
                    continue;
                }
                if (isEscapedAt(cursor - charIndex)) {
                    continue;
                }
                return cursor + newTextLen;
            }
        }
        return null;
    }

    public function backspace(_:Backspace, window:Window, cx:Context<InputBaseState>):Void {
        // Nothing to delete at the start of the text. Propagate so an ancestor
        // (e.g. a command palette navigating back a level) can act on it.
        // With multiple cursors the others can still delete, so only the
        // lone-cursor case propagates.
        if (selections.isSingle() && activeSelection().isEmpty() && cursor() == 0) {
            cx.propagate();
            return;
        }

        // Pair deletion follows automatic closing rules, independently of
        // structural brackets used by Enter.
        if (mode.isAutoClose() && selections.isSingle() && activeSelection().isEmpty()) {
            final off = cursor();
            var deletion:Null<Range> = null;
            final rules = mode.languageConfig();
            if (rules != null) {
                for (pair in rules.closingPairs()) {
                    final open = pair.open;
                    final close = pair.close;
                    if (!textBeforeMatches(off, open) || !textAfterMatches(off, close)) {
                        continue;
                    }
                    final start = off - Utf8.byteLength(open);
                    final generated = mode.autoClosedPairs().contains(new Range(start, off), new Range(off, off + Utf8.byteLength(close)));
                    if (isEscapedAt(start) || (!generated && pair.notIn.indexOf(modeKind.editingSyntaxContext(this, start)) != -1)) {
                        continue;
                    }
                    deletion = new Range(start, off + Utf8.byteLength(close));
                    break;
                }
            }
            if (deletion != null) {
                final utf16 = rangeToUtf16(deletion);
                replaceTextInRangeSilent(utf16, "", window, cx);
                return;
            }
        }

        deleteSelections(false, EditIntent.Backspace, (s, offset) -> new Range(s.previousBoundary(offset), offset), window, cx);
    }

    public function delete(_:Delete, window:Window, cx:Context<InputBaseState>):Void {
        deleteSelections(false, EditIntent.DeleteForward, (s, offset) -> new Range(offset, s.nextBoundary(offset)), window, cx);
    }

    public function deleteToBeginningOfLine(_:DeleteToBeginningOfLine, window:Window, cx:Context<InputBaseState>):Void {
        deleteSelections(true, EditIntent.Atomic, (s, offset) -> {
            var start = s.startOfLineAt(offset, s.lineEndAffinityAt(offset));
            if (start == offset) {
                start = saturatingSub(start, 1);
            }
            return new Range(start, offset);
        }, window, cx);
    }

    public function deleteToEndOfLine(_:DeleteToEndOfLine, window:Window, cx:Context<InputBaseState>):Void {
        deleteSelections(true, EditIntent.Atomic, (s, offset) -> {
            var end = s.endOfLineAt(offset, s.lineEndAffinityAt(offset));
            if (end == offset) {
                end = end + 1 > s.text.len() ? s.text.len() : end + 1;
            }
            return new Range(offset, end);
        }, window, cx);
    }

    public function deletePreviousWord(_:DeleteToPreviousWordStart, window:Window, cx:Context<InputBaseState>):Void {
        deleteSelections(true, EditIntent.Atomic, (s, offset) -> new Range(s.previousStartOfWordAt(offset), offset), window, cx);
    }

    public function deleteNextWord(_:DeleteToNextWordEnd, window:Window, cx:Context<InputBaseState>):Void {
        deleteSelections(true, EditIntent.Atomic, (s, offset) -> new Range(offset, s.nextEndOfWordAt(offset)), window, cx);
    }

    public function enter(action:glaze.kit.base.input.InputActions.Enter, window:Window, cx:Context<InputBaseState>):Void {
        if (modeKind.handleContextMenuAction(this, action, window, cx)) {
            return;
        }

        // Clear inline completion on enter (user chose not to accept it)
        if (modeKind.hasInlineCompletion(this)) {
            modeKind.clearInlineCompletion(this, cx);
        }

        // In multi-line mode with `submitOnEnter` enabled, a plain `Enter`
        // (without Shift) is treated as submit: propagate the action and emit
        // PressEnter without inserting a newline. `Shift+Enter` still inserts
        // a newline.
        final insertNewline = isMultiLine() && (!submitOnEnter || action.shift);

        if (insertNewline) {
            if (!selections.isSingle()) {
                // Insert a newline (with per-line indent) at every cursor.
                selections.mergeOverlapping();
                final selections = CursorSelection.copyAll(this.selections.iter());
                final edits:Array<TextEdit> = [];
                for (sel in selections) {
                    final indent = isCodeEditor() ? indentOfNextLineAt(sel.cursorOffset()) : "";
                    edits.push(new TextEdit(new Range(sel.start, sel.end), "\n" + indent));
                }
                stableSortEdits(edits);
                replaceTextInRanges(edits, window, cx);
                pauseBlinkCursor(cx);
            }
            else {
                // Bracket split: Enter between `{|}` produces `{\n  \n}`
                // with the cursor on the middle line. Controlled by smart_indent,
                // independently of automatic closing.
                // Skipped inside strings and comments: splitting there would
                // restructure literal text.
                var split = false;
                if (isCodeEditor() && activeSelection().isEmpty()) {
                    final rules = mode.languageConfig();
                    if (rules != null) {
                        if (mode.isSmartIndent() && modeKind.editingSyntaxContext(this, cursor()) == SyntaxContext.Code) {
                            final off = cursor();
                            var isPair = false;
                            for (p in rules.brackets) {
                                if (p.open.length > 0 && p.close.length > 0 && p.open != p.close && textBeforeMatches(off, p.open)
                                    && textAfterMatches(off, p.close)) {
                                    isPair = true;
                                    break;
                                }
                            }
                            if (isPair) {
                                // Base indent: leading whitespace only.
                                final lineEndAffinity = this.lineEndAffinityAt(off);
                                final lineStart = startOfLineAt(off, lineEndAffinity);
                                final indentBuf = new StringBuf();
                                final chars = text.sliceFrom(lineStart).chars();
                                while (true) {
                                    final c = chars.next();
                                    if (c == -1 || !Utf8.isWhitespace(c) || c == '\n'.code || c == '\r'.code) {
                                        break;
                                    }
                                    indentBuf.addChar(c);
                                }
                                final indent = indentBuf.toString();
                                // Extra level only with smart indent enabled.
                                var inner = indent;
                                if (mode.isSmartIndent()) {
                                    final tab = mode.tabSize();
                                    if (tab.hardTabs) {
                                        inner += "\t";
                                    }
                                    else {
                                        for (_ in 0...tab.tabSize) {
                                            inner += " ";
                                        }
                                    }
                                }
                                final newLineText = '\n$inner\n$indent';
                                replaceTextInRangeSilent(null, newLineText, window, cx);
                                setCursorTo(off + 1 + Utf8.byteLength(inner));
                                this.updatePreferredColumn();
                                final cursors = CursorSelection.copyAll(selections.iter());
                                undoManager.recordSelections(CursorSelection.copyAll(cursors), cursors);
                                pauseBlinkCursor(cx);
                                split = true;
                            }
                        }
                    }
                }
                if (!split) {
                    // Get current line indent
                    final indent = isCodeEditor() ? indentOfNextLine() : "";

                    // Add newline and indent
                    final newLineText = "\n" + indent;
                    replaceTextInRangeSilent(null, newLineText, window, cx);
                    pauseBlinkCursor(cx);
                }
            }
        }
        else {
            // Single line input or submit-on-enter: just emit the event
            // (e.g.: in a dialog to confirm, or a chat textarea to send).
            undoManager.breakTransactionCoalescing();
            cx.propagate();
        }

        cx.emit(InputEvent.PressEnter(action.secondary, action.shift));
    }

    public function clean(window:Window, cx:Context<InputBaseState>):Void {
        replaceText("", window, cx);
        setSelection(0, 0);
        scrollTo(0, null, cx);
    }

    public function escape(action:glaze.kit.base.input.InputActions.Escape, window:Window, cx:Context<InputBaseState>):Void {
        if (modeKind.handleContextMenuAction(this, action, window, cx)) {
            return;
        }

        // Escape also dismisses a request whose popup has not arrived yet.
        modeKind.hideContextMenu(this, cx);

        // Collapse extra cursors back to the active one first.
        if (!selections.isSingle()) {
            undoManager.breakTransactionCoalescing();
            selections.removeAllButActive();
            cx.notify();
            return;
        }

        // Clear inline completion on escape
        if (modeKind.hasInlineCompletion(this)) {
            modeKind.clearInlineCompletion(this, cx);
            return; // Consume the escape, don't propagate
        }
        modeKind.clearInlineCompletion(this, cx);

        // The handles and the edit menu are the topmost surface to dismiss.
        if (InputTouch.touchSelection(this) != null) {
            this.dismissTouchSelection(cx);
            return;
        }

        if (imeMarkedRange != null) {
            unmarkText(window, cx);
        }

        // Android delivers its back button as escape, and back leaves a field's
        // text alone: it closes what is open or navigates (not a target here).
        if (cleanOnEscape) {
            clean(window, cx);
            return;
        }

        cx.propagate();
    }

    /** Show the right-click context menu as a native OS menu. */
    public function handleRightClickMenu(position:Point, offset:Int, window:Window, cx:Context<InputBaseState>):Void {
        if (disabled) {
            return;
        }
        if (GlobalState.isInDeferredContext(cx.app)) {
            return;
        }

        if (!activeSelection().contains(offset)) {
            this.moveTo(offset, null, cx);
        }

        if (isCodeEditor()) {
            modeKind.onHoverDefinition(this, offset, window, cx);
        }

        final handler = contextMenuHandler;
        if (handler != null) {
            final capabilities = contextMenuCapabilities();
            final input = cx.weakEntity();
            // The handler runs with the input released, so a custom builder can
            // read it (cursor, selection, text) to build its items.
            window.defer(cx.app, (window, cx) -> {
                if (input.upgrade() == null) {
                    return;
                }
                final previousFocus = window.focused(cx);
                handler(new NativeMenu(), capabilities, position, window, cx);
                // A drawn menu takes focus synchronously; native menus leave it
                // on the input. Capture it here rather than in the handler.
                input.tryUpdate(cx, (this_, cx) -> {
                    final focused = window.focused(cx.app);
                    if (focused == previousFocus && !this_.focusHandle.isFocused(window) && this_.hasSelectionFocus(window, cx.app)) {
                        // A custom handler can reuse an already-focused popup.
                        return;
                    }
                    final menuFocus = (focused != null && focused != previousFocus && focused != this_.focusHandle) ? focused : null;
                    this_.setSelectionFocus(menuFocus, cx);
                });
            });
        }
    }

    public function addCursorAbove(_:AddCursorAbove, window:Window, cx:Context<InputBaseState>):Void {
        addCursorVertical(-1, cx);
    }

    public function addCursorBelow(_:AddCursorBelow, window:Window, cx:Context<InputBaseState>):Void {
        addCursorVertical(1, cx);
    }

    /**
     * Add a new cursor one display line above (`moveLines < 0`) or below each
     * existing cursor, preserving the column. Cursors that would not move (at
     * the first/last display row) or that would duplicate an existing cursor
     * are skipped.
     */
    function addCursorVertical(moveLines:Int, cx:Context<InputBaseState>):Void {
        if (!isMultiLine()) {
            return;
        }

        pauseBlinkCursor(cx);
        // Changing the cursor set ends the editing gesture that came before it.
        undoManager.breakTransactionCoalescing();

        final sources = [for (sel in selections.iter()) {offset: sel.cursorOffset(), anchor: sel.columnAnchor, lineEndAffinity: this.lineEndAffinityFor(sel)}];
        final offsets = new Map<Int, Bool>();
        for (source in sources) {
            offsets.set(source.offset, true);
        }

        var newest:Null<Int> = null;
        for (source in sources) {
            final offset = source.offset;
            final anchor = source.anchor != null ? source.anchor : this.preferredColumnFor(offset);
            final target = this.verticalTarget(offset, anchor, source.lineEndAffinity, moveLines).offset;
            if (target == offset || offsets.exists(target)) {
                continue;
            }
            offsets.set(target, true);
            final id = selections.generateId();
            final cursor = new CursorSelection(id, target, target);
            cursor.columnAnchor = anchor;
            selections.add(cursor);
            newest = target;
        }

        if (newest != null) {
            scrollTo(newest, null, cx);
        }
        cx.notify();
    }

    /**
     * Add an additional collapsed cursor at `offset`.
     *
     * Rejected when `offset` lands inside an existing selection or exactly on
     * an existing cursor.
     */
    public function addCursorAt(offset:Int, cx:Context<InputBaseState>):Void {
        if (!isMultiLine()) {
            return;
        }

        for (sel in selections.iter()) {
            if (sel.contains(offset)) {
                return;
            }
            if (sel.isCollapsed() && sel.cursorOffset() == offset) {
                return;
            }
        }

        undoManager.breakTransactionCoalescing();
        final id = selections.generateId();
        final selection = new CursorSelection(id, offset, offset);
        selection.columnAnchor = this.preferredColumnFor(offset);
        selections.add(selection);
        cx.notify();
    }

    /**
     * Build a columnar (block) selection spanning the rows between the two
     * points, one selection per display row at the same column span.
     *
     * The span keeps the columns the pointer sat past the end of a short row, so a row
     * that runs out of text does not narrow the block for the rows that do reach that
     * far. Each row is then clipped to its own end.
     */
    public function buildColumnarSelection(start:ColumnarPoint, end:ColumnarPoint, cx:Context<InputBaseState>):Void {
        if (!isMultiLine()) {
            return;
        }

        undoManager.breakTransactionCoalescing();

        final startRc = columnarRowColumn(start);
        final endRc = columnarRowColumn(end);
        final startRow = startRc.row < endRc.row ? startRc.row : endRc.row;
        final endRow = startRc.row > endRc.row ? startRc.row : endRc.row;
        final startCol = startRc.column < endRc.column ? startRc.column : endRc.column;
        final endCol = startRc.column > endRc.column ? startRc.column : endRc.column;

        final newSelections:Array<CursorSelection> = [];
        for (row in startRow...endRow + 1) {
            final selStart = displayMap.displayRowColumnToOffset(row, startCol);
            final selEnd = displayMap.displayRowColumnToOffset(row, endCol);
            final id = selections.generateId();
            final selStart = text.clipOffset(selStart, Bias.Left);
            final selEnd = text.clipOffset(selEnd, Bias.Left);
            newSelections.push(new CursorSelection(id, selStart, selEnd));
        }

        selections.replaceAll(newSelections);
        cx.notify();
    }

    /**
     * Resolve a columnar point to the display row it is on and the column it reaches,
     * counting the columns beyond the row's end so a short row keeps the full span.
     */
    function columnarRowColumn(point:ColumnarPoint):{row:Int, column:Int} {
        final displayPoint = displayMap.offsetToWrapDisplayPoint(point.offset);
        var row = displayMap.wrapRowToDisplayRow(displayPoint.row);
        if (row == null) {
            row = displayMap.nearestVisibleDisplayRow(displayPoint.row);
        }

        return {row: row, column: displayPoint.column + point.columnsPastLineEnd};
    }

    public function onMouseDown(event:MouseDownEvent, window:Window, cx:Context<InputBaseState>):Void {
        // A token that consumed the press (a double click selecting it) must
        // not also place the caret.
        if (window.defaultPrevented()) {
            return;
        }
        // A tap asks for the virtual keyboard. Focus alone does not when it
        // moves from another input, or stays here, after the user hid it.
        if (event.button == MouseButton.Left && GlobalState.isTouchPress(cx.app) && !disabled && !readonly) {
            window.requestVirtualKeyboard();
        }
        undoManager.breakTransactionCoalescing();
        // Treat every press like a cursor move: take focus now rather than
        // after GPUI's focus observer runs, show the caret at once and restart
        // the idle delay, whatever phase the blink was in.
        if (!disabled) {
            focus(window, cx);
            pauseBlinkCursor(cx);
        }
        // Input has its own text selection; suppress the window-level text
        // selection (Root) so it does not start a drag from here.
        GlobalState.suppressTextSelection(cx.app);

        // Clear inline completion on any mouse interaction
        modeKind.clearInlineCompletion(this, cx);
        // A tap on the touch selection asks for its menu back. Any other press
        // places the caret or starts a new drag, and the handles and the menu
        // no longer belong to what is selected.
        if (event.button == MouseButton.Left && event.clickCount == 1 && this.reopenEditMenuAt(event.position, cx)) {
            return;
        }
        this.dismissTouchSelection(cx);

        // If there have IME marked range and is empty (Means pressed Esc to abort IME typing)
        // Clear the marked range.
        final imeMarkedRange = this.imeMarkedRange;
        if (imeMarkedRange != null) {
            if (imeMarkedRange.len() == 0) {
                this.imeMarkedRange = null;
            }
        }

        selecting = true;
        final resolved = resolveMousePosition(event.position);
        final offset = resolved.offset;
        final lineEndAffinity = resolved.lineEndAffinity;
        final columnsPastLineEnd = resolved.columnsPastLineEnd;

        if (modeKind.onClick(this, event, offset, window, cx)) {
            return;
        }

        // Triple click to select line
        if (event.button == MouseButton.Left && event.clickCount >= 3) {
            this.selectLine(offset, window, cx);
            return;
        }

        // Double click to select word
        if (event.button == MouseButton.Left && event.clickCount == 2) {
            this.selectWord(offset, window, cx);
            // A double tap is touch's other way to select a word, and it
            // gets the handles and the menu like a long press does.
            if (GlobalState.isTouchPress(cx.app)) {
                this.keepTouchSelection(cx);
            }
            return;
        }

        // Show Mouse context menu
        if (event.button == MouseButton.Right) {
            if (enableContextMenu) {
                if (!activeSelection().contains(offset)) {
                    this.moveTo(offset, null, cx);
                }
                pendingContextMenu = {position: event.position, offset: offset};
            }
            return;
        }

        // Multi-cursor placement, multi-line only.
        if (isMultiLine() && event.button == MouseButton.Left) {
            if (event.modifiers.alt && (event.modifiers.shift || (glaze.OperatingSystem.current == Linux && event.modifiers.control))) {
                // Alt+Shift starts a block; Linux also accepts Ghostty's Ctrl+Alt.
                // Mark selecting so the drag handler extends the block.
                columnSelectStart = new ColumnarPoint(offset, columnsPastLineEnd);
                selecting = true;
                this.moveToWithAffinity(offset, null, lineEndAffinity, cx);
                return;
            }
            else if (event.modifiers.alt) {
                addCursorAt(offset, cx);
                // Keep click-to-add behavior, but use this press as the block
                // anchor if the user continues dragging with the left button.
                columnSelectStart = new ColumnarPoint(offset, columnsPastLineEnd);
                return;
            }
        }

        if (event.modifiers.shift) {
            selectToWithAffinity(offset, lineEndAffinity, cx);
        }
        else {
            this.moveToWithAffinity(offset, null, lineEndAffinity, cx);
        }
    }

    public function onMouseUp(event:MouseUpEvent, window:Window, cx:Context<InputBaseState>):Void {
        if (event.button == MouseButton.Right) {
            final pending = pendingContextMenu;
            pendingContextMenu = null;
            if (pending != null) {
                handleRightClickMenu(pending.position, pending.offset, window, cx);
            }
        }
        if (activeSelection().isEmpty()) {
            activeSelectionMut().reversed = false;
        }
        selecting = false;
        selectedWordRange = null;
        columnSelectStart = null;
        autoScroll.stop();
    }

    public function onMouseMove(event:MouseMoveEvent, window:Window, cx:Context<InputBaseState>):Void {
        // Check if mouse is within bounds
        final withinBounds = lastBounds != null && lastBounds.contains(event.position);

        if (!withinBounds) {
            // Clear hover when mouse leaves the input
            modeKind.clearHoverState(this, cx);
            return;
        }

        // Show diagnostic popover on mouse move
        final offset = indexForMousePosition(event.position).offset;
        modeKind.onMouseMove(this, offset, event, window, cx);

        if (isCodeEditor()) {
            // Keep the current popover while the pointer stays on the same
            // diagnostic, so moving over a squiggle neither repaints nor
            // rebuilds the popover.
            final set = mode.diagnostics();
            final diagnostic = set != null ? set.forOffset(offset) : null;
            if (diagnostic != null) {
                if (!sameDiagnostic(diagnosticPopover, diagnostic)) {
                    diagnosticPopover = diagnostic;
                    cx.notify();
                }
            }
            else {
                if (diagnosticPopover != null) {
                    diagnosticPopover = null;
                    cx.notify();
                }
            }
        }
    }

    /** Rust `PartialEq` of `DiagnosticEntry` (its range and diagnostic). */
    static function sameDiagnostic(a:Null<DiagnosticEntry>, b:DiagnosticEntry):Bool {
        if (a == null)
            return false;
        if (a == b)
            return true;
        final da = a.diagnostic;
        final db = b.diagnostic;
        return a.range.equals(b.range) && (da == db || (da.message == db.message && da.severity == db.severity && da.range == db.range
            && da.source == db.source && da.code == db.code));
    }

    public function onScrollWheel(event:ScrollEvent, window:Window, cx:Context<InputBaseState>):Void {
        final lineHeight:Float = lastLayout != null ? lastLayout.lineHeight : window.lineHeight();
        final delta = ScrollDelta.ScrollDeltaTools.pixelDelta(event.delta, lineHeight);

        final oldOffset = scrollHandle.offset();
        final precise = event.delta.match(Pixels(_));
        if (!precise || !scrollBounce || cx.app.reduceMotion() || !overflowsVertically()) {
            final displaced = overscroll.offset() != 0.;
            overscroll.reset();
            if (displaced) {
                cx.notify();
            }
        }
        final bounces = scrollBounce && precise && !cx.app.reduceMotion() && Math.abs(delta.y) >= Math.abs(delta.x) && overflowsVertically();
        if (bounces) {
            final stretched = overscroll.packet(delta.y, event.touchPhase, inputBounds.size.height, cx.backgroundExecutor().now(), dy -> {
                final before = scrollHandle.offset();
                updateScrollOffset(new Point(before.x + delta.x, before.y + dy), cx);
                return scrollHandle.offset().y - before.y;
            });
            if (stretched) {
                cx.notify();
            }
        }
        else {
            // Axis drift must not drop the end of a vertical drag.
            if ((event.touchPhase == TouchPhase.Ended || event.touchPhase == TouchPhase.Cancelled) && overscroll.offset() != 0.) {
                overscroll.packet(0., event.touchPhase, inputBounds.size.height, cx.backgroundExecutor().now(), _ -> 0.);
                cx.notify();
            }
            updateScrollOffset(oldOffset.add(delta), cx);
        }

        // Text that has room to scroll keeps a scroll over it even where the
        // text ends, so reaching the end does not scroll the region around the
        // input; text that fits leaves the scroll to that region.
        if (!scrollHandle.offset().equals(oldOffset) || overflowsAlong(delta)) {
            cx.stopPropagation();
        }

        if (diagnosticPopover != null) {
            diagnosticPopover = null;
            cx.notify();
        }
        // The handles follow the text; the menu would sit over whatever
        // scrolls underneath it, so it steps aside until the finger lifts.
        this.editMenuOnScroll(event.touchPhase, cx);
    }

    /**
     * Whether the text takes a wheel event moving by `delta` from the
     * scroll areas around it: it has room to scroll along the axis the
     * event mostly moves on.
     */
    public function takesScroll(delta:Point):Bool {
        if (Math.abs(delta.y) >= Math.abs(delta.x)) {
            return overflowsVertically();
        }
        else {
            return scrollSize.width > inputBounds.size.width;
        }
    }

    /**
     * Whether the text has room to scroll along the axis `delta` mostly
     * moves on. A trackpad swipe drifts a little off its axis, so the drift
     * alone does not claim the scroll.
     */
    function overflowsAlong(delta:Point):Bool {
        if (Math.abs(delta.y) >= Math.abs(delta.x)) {
            return delta.y != 0. && overflowsVertically();
        }
        else {
            return scrollSize.width > inputBounds.size.width;
        }
    }

    /** Whether multi-line text is taller than the input. */
    function overflowsVertically():Bool {
        return isMultiLine() && scrollSize.height > inputBounds.size.height;
    }

    public function updateScrollOffset(offset:Null<Point>, cx:Context<InputBaseState>):Void {
        final offset = offset != null ? offset : scrollHandle.offset();
        final safeYStart = Math.min(-scrollSize.height + inputBounds.size.height, 0.);
        final safeYEnd = 0.;

        final y = isSingleLine() ? 0. : clampF(offset.y, safeYStart, safeYEnd);
        final x = TextElement.clampHorizontalScrollOffset(offset.x, scrollSize.width, inputBounds.size.width, textAlign);
        final offset = new Point(x, y);
        if (!scrollHandle.offset().equals(offset)) {
            scrollHandle.setOffset(offset);
            cx.notify();
        }
    }

    /**
     * Scroll to make the given offset visible.
     *
     * If `direction` is given, will keep edges at the same side.
     */
    public function scrollTo(offset:Int, direction:Null<MoveDirection>, cx:Context<InputBaseState>):Void {
        final padding = direction != null ? ScrollPadding.SurroundingLines : ScrollPadding.Minimal;
        scrollToWithPadding(offset, direction, padding, cx);
    }

    /**
     * Reveal an offset with independently chosen direction restriction and padding.
     * Search uses surrounding lines without restricting movement to match order.
     */
    public function scrollToWithPadding(offset:Int, direction:Null<MoveDirection>, padding:ScrollPadding, cx:Context<InputBaseState>):Void {
        final lastLayout = this.lastLayout;
        if (lastLayout == null) {
            return;
        }
        final bounds = lastBounds;
        if (bounds == null) {
            return;
        }

        var scrollOffset = scrollHandle.offset();
        final wasOffset = scrollOffset;
        final lineHeight = lastLayout.lineHeight;

        final point = text.offsetToPoint(offset);

        final row = point.row;

        // Resolve the wrapped row even when the target is outside the last layout.
        final displayRow = displayMap.offsetToDisplayRow(offset, this.lineEndAffinityAt(offset));
        final rowOffsetY = lineHeight * displayRow;

        // For Right alignment use 0 margin: the cursor indicator is clamped inside bounds
        // in layout_cursors, so shifting the text here would cause a first-click visual jump.
        final safetyMargin:Float = switch lastLayout.textAlign {
            case Left: TextElement.RIGHT_MARGIN;
            case Right: 0.;
            case Center: BlinkCursor.CURSOR_WIDTH;
        };
        var scrollX = scrollOffset.x;
        var scrollY = scrollOffset.y;
        final vi = lastLayout.visibleBufferLines.indexOf(row);
        if (vi != -1) {
            final line = lastLayout.lines[vi];
            final localOffset = saturatingSub(offset, lastLayout.visibleLineByteOffsets[vi]);
            final pos = line.positionForIndex(localOffset, lastLayout, false);
            if (pos != null) {
                final boundsWidth = (bounds.size.width : Float) - (lastLayout.lineNumberWidth : Float);
                final colOffsetX = pos.x;
                if (colOffsetX - safetyMargin < -scrollX) {
                    // If the position is out of the visible area, scroll to make it visible
                    scrollX = -colOffsetX + safetyMargin;
                }
                else if (colOffsetX + safetyMargin > -scrollX + boundsWidth) {
                    scrollX = -(colOffsetX - boundsWidth + safetyMargin);
                }
            }
        }

        // Scroll the row into view. Use the same edge clearance helper as
        // `TextElement.layoutCursors` so both scroll-into-view paths agree.
        final edgeHeight:Float = if (padding == ScrollPadding.SurroundingLines && isCodeEditor()) {
            TextElement.cursorSurroundingPadding(mode.isAutoGrow(), cursorSurroundingLines,
                TextElement.viewportVisibleLines(bounds.size.height, lineHeight), lineHeight);
        }
        else {
            0.;
        }
        scrollY = TextElement.revealRow(scrollY, rowOffsetY, lineHeight, bounds.size.height, edgeHeight);

        // Avoid necessary scroll, when it was already in the correct position.
        if (direction == MoveDirection.Up) {
            scrollY = Math.max(scrollY, wasOffset.y);
        }
        else if (direction == MoveDirection.Down) {
            scrollY = Math.min(scrollY, wasOffset.y);
        }

        // Clamp the deferred target into the same safe range that
        // `updateScrollOffset` enforces on persist, so paint never shows an
        // over-scrolled frame before the post-paint clamp pulls it back.
        final safeYMin = Math.min(-scrollSize.height + inputBounds.size.height, 0.);
        scrollX = Math.min(scrollX, 0.);
        scrollY = clampF(scrollY, safeYMin, 0.);
        deferredScrollOffset = new Point(scrollX, scrollY);
        cx.notify();
    }

    public function showCharacterPalette(_:ShowCharacterPalette, window:Window, cx:Context<InputBaseState>):Void {
        window.showCharacterPalette();
    }

    /** The text of every non-empty selection, in document order. */
    function selectedTexts():Array<String> {
        final selections = [for (sel in this.selections.iter()) if (!sel.isEmpty()) sel];
        stableSortSelections(selections);
        return [for (sel in selections) text.slice(sel.start, sel.end).toString()];
    }

    public function copy(_:Copy, window:Window, cx:Context<InputBaseState>):Void {
        if (!isCopyable()) {
            return;
        }

        final texts = selectedTexts();

        cx.writeToClipboard(ClipboardItem.newString(texts.join("\n")));
    }

    public function cut(_:Cut, window:Window, cx:Context<InputBaseState>):Void {
        if (!isCopyable()) {
            return;
        }

        final texts = selectedTexts();

        cx.writeToClipboard(ClipboardItem.newString(texts.join("\n")));

        undoManager.setPendingIntent(EditIntent.Atomic);
        replaceTextInRangeSilent(null, "", window, cx);
    }

    /**
     * The `Paste` action (Rust `paste`, renamed: `paste` is the
     * `EntityInputHandler` method).
     *
     * Rust falls back to an asynchronous clipboard read when the synchronous
     * one is empty (the web); the port's platform clipboards are synchronous.
     */
    public function pasteAction(_:Paste, window:Window, cx:Context<InputBaseState>):Void {
        if (!isEditable()) {
            return;
        }
        final clipboard = cx.readFromClipboard();
        if (clipboard != null) {
            insertClipboard(clipboard, window, cx);
            return;
        }
    }

    /**
     * Where a paste would go right now: the document as edited so far and
     * the selections it would replace. Two equal targets mean an edit made
     * for one still applies to the other.
     */
    function pasteTarget():PasteTarget {
        return new PasteTarget(documentRevision, CursorSelection.copyAll(selections.iter()));
    }

    /**
     * Inserts the clipboard text the way `Paste` does: one atomic edit,
     * newlines dropped on a single-line input, one line per selection when
     * the counts match on a multi-line one. A clipboard without text (an
     * image, say) is left alone rather than replacing the selection with
     * nothing.
     */
    function insertClipboard(clipboard:ClipboardItem, window:Window, cx:Context<InputBaseState>):Void {
        var newText = clipboard.text();
        if (newText == null || newText.length == 0) {
            return;
        }
        // A paste is one atomic edit, never part of a typing run.
        undoManager.setPendingIntent(EditIntent.Atomic);

        if (!isMultiLine()) {
            newText = StringTools.replace(newText, "\n", "");
            replaceTextInRangeSilent(null, newText, window, cx);
            scrollTo(cursor(), null, cx);
            return;
        }

        // Distribute one clipboard line per selection when the counts match.
        // Otherwise insert the whole clipboard text at each cursor.
        if (!selections.isSingle()) {
            selections.mergeOverlapping();
        }
        final lines = newText.split("\n");
        final count = selections.len();
        if (count > 1 && lines.length == count) {
            final selections = CursorSelection.copyAll(this.selections.iter());
            stableSortSelections(selections);
            final edits:Array<TextEdit> = [for (i in 0...selections.length) new TextEdit(new Range(selections[i].start, selections[i].end), lines[i])];
            replaceTextInRanges(edits, window, cx);
        }
        else {
            replaceTextInRangeSilent(null, newText, window, cx);
        }
        scrollTo(cursor(), null, cx);
    }

    /**
     * The intent of a batch the caller did not label: inserting text at
     * collapsed cursors is typing, anything else stands on its own.
     */
    function typingIntent(edits:Array<TextEdit>, newText:String):EditIntent {
        var allEmpty = true;
        for (edit in edits) {
            if (!edit.range.isEmpty()) {
                allEmpty = false;
                break;
            }
        }
        if (newText.length > 0 && !containsNewline(newText) && allEmpty) {
            return EditIntent.Typing;
        }
        else {
            return EditIntent.Atomic;
        }
    }

    /**
     * Where a cursor stood before an edit made with this intent.
     *
     * Backspace and forward delete expand a collapsed cursor over the text
     * they are about to remove, so the recorded cursor has to collapse back to
     * the side it came from for undo to restore it where the user left it.
     */
    static function collapseForIntent(intent:EditIntent, selection:CursorSelection, range:Range):CursorSelection {
        final selection = selection.copy();
        switch intent {
            case Backspace:
                selection.placeAt(range.end, null);
            case DeleteForward:
                selection.placeAt(range.start, null);
            case Typing | Atomic:
        }
        return selection;
    }

    /**
     * Whether an edit rewrites the character before a collapsed cursor, as the
     * macOS Korean IME does on each keystroke instead of marking text.
     */
    function rewritesTypedChar(selection:CursorSelection, range:Range, oldText:String, newText:String):Bool {
        return !silentReplaceText
            && selection.isCollapsed()
            && selection.cursorOffset() == range.end
            && charCount(oldText) == 1
            && !containsNewline(oldText)
            && !containsNewline(newText);
    }

    function pushHistory(text:Rope, range:Range, newText:String, requestedIntent:Null<EditIntent>, selectionBefore:CursorSelection,
            selectionAfter:Null<CursorSelection>):Bool {
        documentRevision = documentRevision + 1;
        final tokenDelta = this.editTokens(range, Utf8.byteLength(newText));
        if (undoManager.isIgnoring()) {
            return false;
        }

        final range = new Range(text.clipOffset(range.start, Bias.Left), text.clipOffset(range.end, Bias.Right));
        final oldText = text.slice(range.start, range.end).toString();
        final newRange = new Range(range.start, range.start + Utf8.byteLength(newText));

        // Deviation DEV-015: a character typed over the selection starts a
        // typing run (a boundary before it, none after), so the typing that
        // follows undoes with it in one step, like macOS.
        final typesOverSelection = requestedIntent == null
            && !selectionBefore.isCollapsed()
            && selectionBefore.start == range.start
            && selectionBefore.end == range.end
            && charCount(newText) == 1
            && !containsNewline(newText);
        if (typesOverSelection) {
            undoManager.breakTransactionCoalescing();
        }

        final intent = if (requestedIntent != null) {
            requestedIntent;
        }
        else if (range.isEmpty() && oldText.length == 0 && newText.length > 0 && !containsNewline(newText)
            || rewritesTypedChar(selectionBefore, range, oldText, newText)
            || typesOverSelection) {
            EditIntent.Typing;
        }
        else {
            EditIntent.Atomic;
        }

        final selectionBefore = collapseForIntent(intent, selectionBefore, range);
        final selectionAfter = selectionAfter != null ? selectionAfter.copy() : CursorSelection.fromRange(new Range(newRange.end, newRange.end));

        final openTransaction = undoManager.hasOpenTransaction();
        final change = new Change(Selection.fromRange(range), oldText, Selection.fromRange(newRange), newText);
        change.tokenDelta = tokenDelta;
        final recorded = undoManager.recordTransaction(change, intent);
        // A batch records its own cursor sets. This covers a change that is a
        // transaction on its own.
        if (recorded && !openTransaction) {
            undoManager.recordSelections([selectionBefore], [selectionAfter]);
        }
        return recorded;
    }

    public function undo(_:Undo, window:Window, cx:Context<InputBaseState>):Void {
        replayHistory(true, window, cx);
    }

    public function redo(_:Redo, window:Window, cx:Context<InputBaseState>):Void {
        replayHistory(false, window, cx);
    }

    function replayHistory(undo:Bool, window:Window, cx:Context<InputBaseState>):Void {
        if (!isEditable()) {
            return;
        }
        final replay = undo ? undoManager.undo() : undoManager.redo();
        if (replay == null) {
            return;
        }
        var tokenAware = inlineTokens != null;
        if (!tokenAware) {
            for (change in replay.changes) {
                if (change.tokenDelta != null) {
                    tokenAware = true;
                    break;
                }
            }
        }
        final emitEvents = this.emitEvents;
        if (tokenAware) {
            this.emitEvents = false;
        }
        replayingHistory = tokenAware;
        undoManager.setIgnoring(true);
        for (change in replay.changes) {
            final range = undo ? change.newRange.toRange() : change.oldRange.toRange();
            final text = undo ? change.oldText : change.newText;
            final rangeUtf16 = rangeToUtf16(range);
            replaceTextInRangeSilent(rangeUtf16, text, window, cx);
            this.replayTokens(range, Utf8.byteLength(text), change.tokenDelta, undo);
        }
        restoreSelections(replay.selections);
        mode.restoreAutoClosedPairs(replay.autoClosedPairs != null ? replay.autoClosedPairs : AutoClosedPairs.empty());
        if (tokenAware) {
            // Token replay bypasses IME normalization; a stale marked range
            // would otherwise describe text that no longer exists.
            imeMarkedRange = null;
        }
        undoManager.setIgnoring(false);
        replayingHistory = false;
        this.emitEvents = emitEvents;
        if (tokenAware && emitEvents) {
            cx.emit(InputEvent.Change);
        }
        cx.notify();
    }

    /**
     * Restore a set of selections captured in a transaction, clamping offsets
     * to the current text length. `null` leaves the current selections as the
     * replay left them.
     */
    function restoreSelections(selections:Null<Array<CursorSelection>>):Void {
        if (selections == null) {
            return;
        }

        final len = text.len();
        final restored = [for (sel in selections) {
            final sel = sel.copy();
            sel.start = sel.start < len ? sel.start : len;
            sel.end = sel.end < len ? sel.end : len;
            sel;
        }];
        this.selections.replaceAll(restored);
        this.selections.mergeOverlapping();
    }

    /**
     * Get byte offset of the cursor.
     *
     * The offset is the UTF-8 offset.
     */
    public function cursor():Int {
        final imeMarkedRange = this.imeMarkedRange;
        if (imeMarkedRange != null) {
            return imeMarkedRange.end;
        }

        return selections.active().cursorOffset();
    }

    /** Returns the active selection. */
    public inline function activeSelection():CursorSelection {
        return selections.active();
    }

    /** Returns the active selection, to mutate it. */
    public inline function activeSelectionMut():CursorSelection {
        return selections.activeMut();
    }

    /**
     * Sets the active selection to the given range, keeping its `reversed`
     * and `columnAnchor` state untouched.
     */
    public function setSelection(start:Int, end:Int):Void {
        final range = this.normalizeTokenRange(new Range(start, end));
        final active = activeSelectionMut();
        active.start = range.start;
        active.end = range.end;
    }

    /**
     * Collapses the active selection to a cursor at the given offset,
     * clearing `reversed`.
     */
    public function setCursorTo(offset:Int):Void {
        final offset = this.tokenBoundary(offset, Bias.Right);
        final active = activeSelectionMut();
        active.start = offset;
        active.end = offset;
        active.reversed = false;
    }

    /** Visible row range in the last laid-out viewport, `null` before first layout. */
    public function visibleRowRange():Null<Range> {
        return lastLayout != null ? lastLayout.visibleRange : null;
    }

    /** Current scroll offset of the editor viewport. */
    public function scrollOffset():Point {
        return scrollHandle.offset();
    }

    /**
     * Set scroll offset of the editor viewport.
     *
     * The offset will be clamped to the valid range, and applied after the next layout.
     */
    public function setScrollOffset(offset:Point, cx:Context<InputBaseState>):Void {
        deferredScrollOffset = offset;
        cx.notify();
    }

    /** Laid-out line height; `null` before first layout. */
    public function lineHeight():Null<Pixels> {
        return lastLayout != null ? lastLayout.lineHeight : null;
    }

    /**
     * Returns the active selection as a byte range into the text.
     *
     * With multiple cursors, this reads only the active selection. The range
     * is empty when no text is selected; in that case the offset equals
     * `cursor()`.
     */
    public function selectedRange():Range {
        return selections.active().toRange();
    }

    public function selectAll(window:Window, cx:Context<InputBaseState>):Void {
        undoManager.breakTransactionCoalescing();
        selections.removeAllButActive();
        setSelection(0, text.len());
        cx.notify();
    }

    /**
     * Set the selected range using UTF-8 byte offsets, removing additional cursors.
     *
     * Non-empty ranges expand to character boundaries. Empty ranges remain empty and are
     * clipped to the preceding character boundary.
     */
    public function setSelectedRange(range:Range, cx:Context<InputBaseState>):Void {
        final range = this.normalizeTokenRange(range);
        final endBias = range.start == range.end ? Bias.Left : Bias.Right;
        final start = text.clipOffset(range.start, Bias.Left);
        final end = text.clipOffset(range.end, endBias);

        this.moveTo(start, null, cx);
        activeSelectionMut().reversed = false;
        selectedWordRange = null;
        selectTo(end, cx);
    }

    /**
     * Add `range` as an additional selection, keeping the existing ones:
     * the programmatic equivalent of Alt-clicking another cursor into the
     * text.
     *
     * The range is clipped to the text and expanded to character
     * boundaries, like `setSelectedRange`. A range already covered by a
     * selection adds nothing. Overlapping selections are merged. On a
     * single-line input there is no second cursor to add, so the call
     * replaces the selection instead. The view scrolls to the new selection.
     */
    public function addSelection(range:Range, cx:Context<InputBaseState>):Void {
        if (!isMultiLine()) {
            setSelectedRange(range, cx);
            return;
        }

        final range = this.normalizeTokenRange(range);
        final endBias = range.start == range.end ? Bias.Left : Bias.Right;
        final start = cursorBoundary(range.start, Bias.Left);
        // Match set_selected_range: expand UTF-8 boundaries first, then place
        // the selection endpoint without splitting a CRLF newline.
        final end = cursorBoundary(text.clipOffset(range.end, endBias), Bias.Left);

        for (sel in selections.iter()) {
            if (sel.start <= start && end <= sel.end) {
                return;
            }
        }

        undoManager.breakTransactionCoalescing();
        selectedWordRange = null;
        pauseBlinkCursor(cx);
        modeKind.hideContextMenu(this, cx);
        modeKind.clearInlineCompletion(this, cx);
        final id = selections.generateId();
        final selection = new CursorSelection(id, start, end);
        selection.columnAnchor = this.preferredColumnFor(end);
        selections.add(selection);
        selections.mergeOverlapping();
        scrollTo(end, null, cx);
        cx.notify();
    }

    /**
     * Resolve a mouse position to a byte offset in the text.
     *
     * Also reports the caret's line-end affinity for that offset: `true` when the position
     * landed on the wrap boundary of a non-final visual row.
     */
    public function indexForMousePosition(position:Point):MouseIndex {
        final resolved = resolveMousePosition(position);
        return {offset: resolved.offset, lineEndAffinity: resolved.lineEndAffinity};
    }

    /**
     * Resolve a mouse position to a text offset, the caret affinity to use for it, and
     * how many columns the pointer sits past the end of that row.
     */
    public function resolveMousePosition(position:Point):MousePosition {
        // If the text is empty, always return 0
        if (text.len() == 0) {
            return {offset: 0, lineEndAffinity: false, columnsPastLineEnd: 0};
        }

        final bounds = lastBounds;
        final lastLayout = this.lastLayout;
        if (bounds == null || lastLayout == null) {
            return {offset: 0, lineEndAffinity: false, columnsPastLineEnd: 0};
        }

        final lineHeight = lastLayout.lineHeight;
        final lineNumberWidth = lastLayout.lineNumberWidth;

        // The position is relative to the bounds of the text input
        //
        // bounds.origin:
        //
        // - included the input padding.
        // - included the scroll offset.
        final innerPosition = position.sub(bounds.origin).sub(new Point(lineNumberWidth, 0.));

        var yOffset:Float = lastLayout.visibleTop;
        // Position relative to the last line walked, kept for a pointer that ends up
        // below every line.
        var lastLinePos:Null<Point> = null;

        // Traverse visible buffer lines (compact, no hidden entries)
        final count = lastLayout.lines.length < lastLayout.visibleBufferLines.length ? lastLayout.lines.length : lastLayout.visibleBufferLines.length;
        for (vi in 0...count) {
            final lineLayout = lastLayout.lines[vi];
            final lineStartOffset = lastLayout.visibleLineByteOffsets[vi];

            // Calculate line origin for this display row
            final lineOrigin = new Point(0., yOffset);
            final pos = innerPosition.sub(lineOrigin);

            // Return offset by use closest_index_for_x if is single line mode.
            if (isSingleLine()) {
                final localIndex = lineLayout.closestIndexForX(pos.x, lastLayout);
                // A single line never wraps, so there is no boundary to disambiguate.
                return {offset: resolveIndex(lineStartOffset + localIndex), lineEndAffinity: false, columnsPastLineEnd: 0};
            }

            // Check if mouse is in this line's bounds
            final closest = lineLayout.closestIndexForPosition(pos, lastLayout);
            if (closest != null) {
                return {
                    offset: resolveIndex(lineStartOffset + closest.index),
                    lineEndAffinity: closest.lineEndAffinity,
                    columnsPastLineEnd: lineLayout.columnsPastLineEnd(pos, lastLayout)
                };
            }
            else if (pos.y < 0.) {
                // Mouse is above this line, return start of this line
                return {offset: resolveIndex(lineStartOffset), lineEndAffinity: false, columnsPastLineEnd: 0};
            }

            yOffset += lineLayout.size(lineHeight).height;
            lastLinePos = pos;
        }

        // Clamp to the last laid-out row. Returning the end of the whole document
        // would select unseen text before drag autoscroll has reached it.
        if (lastLayout.lines.length > 0 && lastLinePos != null && lastLayout.visibleLineByteOffsets.length > 0) {
            final lineLayout = lastLayout.lines[lastLayout.lines.length - 1];
            final lineStart = lastLayout.visibleLineByteOffsets[lastLayout.visibleLineByteOffsets.length - 1];
            final lastRowTop = Math.max((lineLayout.size(lineHeight).height : Float) - (lineHeight : Float), 0.);
            final pos = new Point(lastLinePos.x, lastRowTop);
            return {
                offset: resolveIndex(lineStart + lineLayout.len()),
                lineEndAffinity: false,
                columnsPastLineEnd: lineLayout.columnsPastLineEnd(pos, lastLayout)
            };
        }

        return {offset: text.len(), lineEndAffinity: false, columnsPastLineEnd: 0};
    }

    /**
     * Map a display byte index back to a text offset, undoing the mask expansion when the input
     * is masked.
     */
    function resolveIndex(index:Int):Int {
        if (masked) {
            return text.charIndexToOffset(Std.int(index / Utf8.codePointLength(TextElement.MASK_CHAR)));
        }
        else {
            return index < text.len() ? index : text.len();
        }
    }

    /**
     * Extend a single selection so its moving end lands at `offset`, flipping
     * `reversed` when the ends cross. When a sticky `wordRange` is given the
     * selection is kept covering it.
     */
    static function extendSelection(sel:CursorSelection, offset:Int, wordRange:Null<CursorSelection>):Void {
        if (sel.reversed) {
            sel.start = offset;
        }
        else {
            sel.end = offset;
        }

        if (sel.end < sel.start) {
            sel.reversed = !sel.reversed;
            final start = sel.start;
            sel.start = sel.end;
            sel.end = start;
        }

        if (wordRange != null) {
            if (sel.start > wordRange.start) {
                sel.start = wordRange.start;
            }
            if (sel.end < wordRange.end) {
                sel.end = wordRange.end;
            }
        }
    }

    /** Extend only the active selection to `offset`. Used by mouse drag. */
    public function selectTo(offset:Int, cx:Context<InputBaseState>):Void {
        selectToWithAffinity(offset, false, cx);
    }

    /**
     * Like `selectTo`, but also carries the caret's line-end affinity.
     *
     * Plain `selectTo` clears the affinity: every offset it is given came from
     * the text rather than from a visual position.
     */
    public function selectToWithAffinity(offset:Int, lineEndAffinity:Bool, cx:Context<InputBaseState>):Void {
        modeKind.clearInlineCompletion(this, cx);

        cursorLineEndAffinity = lineEndAffinity;
        final offset = cursorBoundary(offset, Bias.Left);
        final wordRange = selectedWordRange;
        extendSelection(activeSelectionMut(), offset, wordRange);
        final range = this.normalizeTokenRange(selectedRange());
        setSelection(range.start, range.end);

        if (activeSelection().isEmpty()) {
            this.updatePreferredColumn();
        }
        cx.notify();
    }

    /**
     * Extend every selection to the offset produced by `f`, then merge any
     * selections that now overlap. Used by keyboard selection commands.
     */
    function selectAllCursorsTo(f:(InputBaseState, CursorSelection) -> Int, cx:Context<InputBaseState>):Void {
        selectAllCursorsToWithAffinity((s, sel) -> {offset: f(s, sel), lineEndAffinity: false}, false, cx);
    }

    /**
     * Extend selections with caret affinity, preserving their column anchors even
     * when vertical movement collapses a selection to a cursor.
     */
    function selectAllCursorsToWithAffinity(f:(InputBaseState, CursorSelection) -> {offset:Int, lineEndAffinity:Bool}, preserveColumn:Bool,
            cx:Context<InputBaseState>):Void {
        pauseBlinkCursor(cx);
        undoManager.breakTransactionCoalescing();
        modeKind.clearInlineCompletion(this, cx);

        var activeAffinity = false;
        final newSelections:Array<CursorSelection> = [];
        for (sel in selections.iter()) {
            final result = f(this, sel);
            if (sel.id == activeSelection().id) {
                activeAffinity = result.lineEndAffinity;
            }
            final offset = cursorBoundary(result.offset, Bias.Left);
            final newSel = sel.copy();
            extendSelection(newSel, offset, null);
            final range = this.normalizeTokenRange(new Range(newSel.start, newSel.end));
            newSel.start = range.start;
            newSel.end = range.end;
            if (!preserveColumn) {
                newSel.columnAnchor = this.preferredColumnForWithAffinity(newSel.cursorOffset(), result.lineEndAffinity);
            }
            else if (newSel.columnAnchor == null) {
                newSel.columnAnchor = this.preferredColumnForWithAffinity(sel.cursorOffset(), this.lineEndAffinityFor(sel));
            }
            newSelections.push(newSel);
        }
        cursorLineEndAffinity = activeAffinity;
        selections.replaceAll(newSelections);
        selections.mergeOverlapping();

        scrollTo(cursor(), null, cx);
        cx.notify();
    }

    /** Unselects the currently selected text. */
    public function unselect(window:Window, cx:Context<InputBaseState>):Void {
        undoManager.breakTransactionCoalescing();
        final offset = cursor();
        setCursorTo(offset);
        cx.notify();
    }

    public inline function offsetFromUtf16(offset:Int):Int {
        return text.offsetUtf16ToOffset(offset);
    }

    public inline function offsetToUtf16(offset:Int):Int {
        return text.offsetToOffsetUtf16(offset);
    }

    public inline function rangeToUtf16(range:Range):Range {
        return new Range(offsetToUtf16(range.start), offsetToUtf16(range.end));
    }

    public inline function rangeFromUtf16(rangeUtf16:Range):Range {
        return new Range(offsetFromUtf16(rangeUtf16.start), offsetFromUtf16(rangeUtf16.end));
    }

    /**
     * If offset falls on a hidden (folded) line, clamp backward to the end of
     * the fold header line (last visible position before the fold).
     */
    function clampOffsetToVisibleBackward(offset:Int):Int {
        final line = text.offsetToPoint(offset).row;
        if (displayMap.isBufferLineHidden(line)) {
            for (fold in displayMap.foldedRanges()) {
                if (line > fold.startLine && line <= fold.endLine) {
                    return text.lineEndOffset(fold.startLine);
                }
            }
        }
        return offset;
    }

    /**
     * If offset falls on a hidden (folded) line, clamp forward to the start of
     * the fold end line (first visible position after the fold).
     */
    function clampOffsetToVisibleForward(offset:Int):Int {
        final line = text.offsetToPoint(offset).row;
        if (displayMap.isBufferLineHidden(line)) {
            for (fold in displayMap.foldedRanges()) {
                if (line > fold.startLine && line <= fold.endLine) {
                    return text.lineStartOffset(fold.endLine);
                }
            }
        }
        return offset;
    }

    /**
     * Clip a cursor/selection offset without splitting a CRLF newline. This does
     * not alter the rope or its byte/UTF-16 conversion used for exact source APIs.
     */
    public function cursorBoundary(offset:Int, bias:Bias):Int {
        final offset = this.tokenBoundary(text.clipOffset(offset, bias), bias);
        if (offset > 0 && text.charAt(offset - 1) == '\r'.code && text.charAt(offset) == '\n'.code) {
            return bias == Bias.Left ? offset - 1 : offset + 1;
        }
        else {
            return offset;
        }
    }

    public function previousBoundary(offset:Int):Int {
        final offset = cursorBoundary(saturatingSub(offset, 1), Bias.Left);
        return clampOffsetToVisibleBackward(offset);
    }

    public function nextBoundary(offset:Int):Int {
        final offset = cursorBoundary(offset + 1, Bias.Right);
        return clampOffsetToVisibleForward(offset);
    }

    /**
     * Returns true to let the element render the cursor, when the input is
     * focused and the blink cursor is visible.
     */
    public function showCursor(window:Window, cx:App):Bool {
        return (focusHandle.isFocused(window) || modeKind.isContextMenuOpen(this, cx))
            && !disabled
            && blinkCursor.read(cx).visible()
            && window.isWindowActive();
    }

    function onFocus(window:Window, cx:Context<InputBaseState>):Void {
        blinkCursor.update(cx, (cursor, cx) -> {
            cursor.start(cx);
        });
        cx.emit(InputEvent.Focus);
    }

    function onBlur(window:Window, cx:Context<InputBaseState>):Void {
        revealedViewport = null;
        if (modeKind.isContextMenuOpen(this, cx.app)) {
            return;
        }

        modeKind.hideContextMenu(this, cx);
        undoManager.breakTransactionCoalescing();

        // NOTE: Do not cancel select, when blur.
        // Because maybe user want to copy the selected text by AppMenuBar (will take focus handle).

        modeKind.clearHoverState(this, cx);
        diagnosticPopover = null;
        modeKind.clearInlineCompletion(this, cx);
        this.dismissTouchSelection(cx);
        blinkCursor.update(cx, (cursor, cx) -> {
            cursor.stop(cx);
        });
        clampNumberValue(window, cx);
        cx.emit(InputEvent.Blur);
        cx.notify();
    }

    /**
     * Clamp the number value to the `min`/`max` range, used on blur.
     *
     * Out-of-range values are allowed while typing (e.g. `1` is an
     * intermediate state of `15` when min is 10), and clamped on blur.
     */
    function clampNumberValue(window:Window, cx:Context<InputBaseState>):Void {
        if (!isSingleLine()) {
            return;
        }
        if (!maskPattern.match(Number(_, _))) {
            return;
        }
        if (numberMin == null && numberMax == null) {
            return;
        }

        final value = parseF64(unmaskValue());
        if (value == null) {
            return;
        }

        final clamped = if (numberMin != null && value < numberMin) {
            numberMin;
        }
        else if (numberMax != null && value > numberMax) {
            numberMax;
        }
        else {
            return;
        }

        // The clamped value must pass the `pattern`/`validate` check,
        // otherwise keep the value as is.
        final newText = f64ToString(clamped);
        if (!isValidInput(newText, cx)) {
            return;
        }

        final range = rangeToUtf16(new Range(0, text.len()));
        replaceTextInRangeSilent(range, newText, window, cx);
    }

    public function pauseBlinkCursor(cx:Context<InputBaseState>):Void {
        blinkCursor.update(cx, (cursor, cx) -> {
            cursor.pause(cx);
        });
    }

    public function onDragMove(event:MouseMoveEvent, window:Window, cx:Context<InputBaseState>):Void {
        if (text.len() == 0) {
            return;
        }

        if (lastLayout == null) {
            return;
        }

        if (!focusHandle.isFocused(window)) {
            return;
        }

        if (!selecting) {
            return;
        }

        autoScroll.lastDragPosition = event.position;
        final resolved = resolveMousePosition(event.position);
        final start = columnSelectStart;
        if (start != null) {
            final end = new ColumnarPoint(resolved.offset, resolved.columnsPastLineEnd);
            buildColumnarSelection(start, end, cx);
        }
        else {
            selectToWithAffinity(resolved.offset, resolved.lineEndAffinity, cx);
        }

        if (!isSingleLine()) {
            final delta = AutoScroll.computeDelta(event.position.y, inputBounds);
            // Input's ScrollHandle uses negative-y-is-down; negate the positive-towards-bottom delta.
            final scrollDelta:Null<Float> = delta != null ? -delta : null;
            autoScroll.set(scrollDelta, cx, (delta, state, cx) -> {
                final current = state.scrollHandle.offset();
                state.updateScrollOffset(new Point(current.x, current.y + delta), cx);
                final pos = state.autoScroll.lastDragPosition;
                if (pos != null) {
                    final resolved = state.resolveMousePosition(pos);
                    final start = state.columnSelectStart;
                    if (start != null) {
                        final end = new ColumnarPoint(resolved.offset, resolved.columnsPastLineEnd);
                        state.buildColumnarSelection(start, end, cx);
                    }
                    else {
                        state.selectToWithAffinity(resolved.offset, resolved.lineEndAffinity, cx);
                    }
                }
            });
        }
    }

    /**
     * Normalize the inserted text before applying it to the input.
     *
     * For number inputs (with `MaskPattern.Number`), this converts full-width
     * number characters into their ASCII equivalents, e.g. `12。5` -> `12.5`.
     */
    public function normalizeInput(newText:String):String {
        final normalized = maskPattern.match(Number(_, _)) ? MaskPatternTools.normalizeNumberInput(newText) : newText;

        if (isSingleLine() && containsNewline(normalized)) {
            return StringTools.replace(StringTools.replace(normalized, "\n", ""), "\r", "");
        }
        else {
            return normalized;
        }
    }

    public function isValidInput(newText:String, cx:Context<InputBaseState>):Bool {
        if (newText.length == 0) {
            return true;
        }

        final validate = this.validate;
        if (validate != null) {
            if (!validate(newText, cx.app)) {
                return false;
            }
        }

        if (!maskPattern.isValid(newText)) {
            return false;
        }

        final pattern = this.pattern;
        if (pattern == null) {
            return true;
        }

        return pattern.match(newText);
    }

    /**
     * Set the mask pattern for formatting the input text.
     *
     * The pattern can contain:
     * - 9: Any digit or dot
     * - A: Any letter
     * - *: Any character
     * - Other characters will be treated as literal mask characters
     *
     * Example: "(999)999-999" for phone numbers
     */
    public function withMaskPattern(pattern:IntoMaskPattern):InputBaseState {
        maskPattern = pattern;
        maskPatternSet = true;
        final placeholder = maskPattern.placeholder();
        if (placeholder != null) {
            this.placeholder = placeholder;
        }
        return this;
    }

    public function setMaskPattern(pattern:IntoMaskPattern, window:Window, cx:Context<InputBaseState>):Void {
        maskPattern = pattern;
        maskPatternSet = true;
        final placeholder = maskPattern.placeholder();
        if (placeholder != null) {
            this.placeholder = placeholder;
        }
        cx.notify();
    }

    /** Apply the default numeric mask unless the caller explicitly selected a mask. */
    public function ensureNumberMask():Void {
        if (maskPatternSet) {
            return;
        }
        maskPattern = Number(null, null);
    }

    public function setInputBounds(newBounds:Bounds, cx:Context<InputBaseState>):Void {
        final wrapWidthChanged = inputBounds.size.width != newBounds.size.width;
        inputBounds = newBounds;

        // Update display_map wrap_width if changed.
        final lastLayout = this.lastLayout;
        if (lastLayout != null) {
            if (wrapWidthChanged) {
                // null to disable wrapping
                final wrapWidth:Null<Float> = !softWrap ? null : lastLayout.wrapWidth;

                displayMap.onLayoutChanged(wrapWidth, cx.app);
                if (isMultiLine()) {
                    mode.updateAutoGrow(displayMap);
                }
                cx.notify();
            }
        }
    }

    /** Return the active selection's text, out of the `Rope` the state owns. */
    public function selectedText():RopeSlice {
        final rangeUtf16 = rangeToUtf16(selectedRange());
        final range = rangeFromUtf16(rangeUtf16);
        return text.slice(range.start, range.end);
    }

    /**
     * Return the rendered bounds for a UTF-8 byte range in the current input contents.
     *
     * Returns `null` when the requested range is not currently laid out or visible.
     */
    public function rangeToBounds(range:Range):Null<Bounds> {
        final lastLayout = this.lastLayout;
        if (lastLayout == null) {
            return null;
        }

        final lastBounds = this.lastBounds;
        if (lastBounds == null) {
            return null;
        }

        final startPos = lineAndPositionForOffset(range.start).position;
        final endPos = lineAndPositionForOffset(range.end).position;

        if (startPos == null) {
            return null;
        }
        if (endPos == null) {
            return null;
        }

        return Bounds.fromCorners(lastBounds.origin.add(startPos), lastBounds.origin.add(endPos).add(new Point(0., lastLayout.lineHeight)));
    }

    /**
     * Replace text in range in silent.
     *
     * This will not trigger any UI interaction, such as auto-completion.
     */
    public function replaceTextInRangeSilent(rangeUtf16:Null<Range>, newText:String, window:Window, cx:Context<InputBaseState>):Void {
        silentReplaceText = true;
        replaceTextInRange(rangeUtf16, newText, window, cx);
        silentReplaceText = false;
    }

    /**
     * Apply a batch of edits as one atomic history transaction.
     *
     * `edits` are `(byte range in the current pre-edit document, replacement)`
     * pairs. `InputIndentExt.RangeEdit` (fields `range` and `text`) fits.
     */
    public function replaceTextInRanges(edits:Array<TextEdit>, window:Window, cx:Context<InputBaseState>):Void {
        if (!isEditable() || edits.length == 0) {
            return;
        }

        // Every edit invalidates provider responses for the previous document,
        // including deletion and indentation which do not trigger completion.
        modeKind.hideContextMenu(this, cx);
        modeKind.clearInlineCompletion(this, cx);

        // Sort descending by start so applying front-of-vec first edits the
        // highest offsets first, leaving lower offsets unchanged.
        var sorted:Array<TextEdit> = [for (edit in edits) new TextEdit(this.normalizeTokenRange(edit.range), edit.text)];
        stableSortEditsDescending(sorted);
        if (this.tokenSpans().length > 0) {
            final merged:Array<{range:Range, text:String}> = [];
            for (edit in sorted) {
                final range = edit.range;
                final last = merged.length > 0 ? merged[merged.length - 1] : null;
                if (last != null && (range.end > last.range.start || range.equals(last.range))) {
                    last.range = new Range(range.start < last.range.start ? range.start : last.range.start,
                        range.end > last.range.end ? range.end : last.range.end);
                }
                else {
                    merged.push({range: range, text: edit.text});
                }
            }
            sorted = [for (edit in merged) new TextEdit(edit.range, edit.text)];
        }

        // Wrap multiple edits in one explicit transaction so they undo as a
        // unit. A single edit records directly, which keeps it eligible for
        // the undo manager's typing coalescing.
        final requestedIntent = undoManager.takePendingIntent();
        final selectionBefore = activeSelection().copy();
        final originalSelections = CursorSelection.copyAll(selections.iter());
        // Snapshot the cursors before applying, so undo can restore them. A
        // delete has already expanded them over the text it removes, so they
        // collapse back to where the user left them.
        final selectionsBefore = [for (selection in selections.iter())
            collapseForIntent(requestedIntent != null ? requestedIntent : EditIntent.Atomic, selection, new Range(selection.start, selection.end))];
        final group = sorted.length > 1;
        if (group) {
            undoManager.beginTransaction();
        }

        final autoClosedPairsBefore = mode.autoClosedPairs().clone();
        var recorded = false;
        // Several edits reach the highlighter as one batch, so it reparses
        // once for the change instead of once per edit.
        final highlighterEdits:Array<EditedText> = [];
        for (edit in sorted) {
            final range = edit.range;
            final newText = edit.text;
            final newTextLen = Utf8.byteLength(newText);
            final oldText = text.clone();
            mode.adjustAutoClosedPair(range, newTextLen);
            text.replace(range, newText);

            modeKind.adjustAnnotations(this, range, newTextLen);
            if (pushHistory(oldText, range, newText, requestedIntent, selectionBefore, null)) {
                recorded = true;
            }

            // Incremental, single-range updates must run per edit.
            displayMap.adjustFoldsForEdit(oldText, range, newText);
            displayMap.onTextChanged(text, range, Rope.fromStr(newText), cx.app);

            if (group) {
                if (isCodeEditor()) {
                    final inputEdit = LayoutMode.replacementInputEdit(oldText, text, range, newText);
                    highlighterEdits.push(new EditedText(inputEdit, text.clone()));
                }
            }
            else {
                mode.updateHighlighter(new glaze.kit.base.input.LayoutMode.HighlighterUpdate(range, oldText, text, newText, true), modeKind, window, cx);

                updateFoldCandidatesIncremental(range, newText);
            }
        }

        if (group) {
            mode.updateHighlighterBatch(highlighterEdits, modeKind, window, cx);

            // Fold candidates are read from the reparsed document, so each
            // edit is located where it ended up once every edit was applied.
            // `sorted` runs from the highest offset down.
            var shift = 0;
            var i = sorted.length - 1;
            while (i >= 0) {
                final edit = sorted[i];
                final start = edit.range.start + shift;
                updateFoldCandidatesIncremental(new Range(start, start), edit.text);
                shift += Utf8.byteLength(edit.text) - edit.range.len();
                i--;
            }

            undoManager.commitTransaction();
        }

        // One observable update per batch instead of one per edit.
        final diagnostics = mode.diagnosticsMut();
        if (diagnostics != null) {
            diagnostics.reset(text);
        }
        modeKind.refreshLanguageFeatures(this, window, cx);
        this.updateSearch(cx.app);

        // Compute the resulting cursors.
        // One collapsed cursor per edit, at the end of its inserted text.
        final ascending = sorted.copy();
        stableSortEdits(ascending);
        final textLen = text.len();
        var delta = 0;
        final editResults:Array<{range:Range, offset:Int}> = [];
        for (edit in ascending) {
            final newTextLen = Utf8.byteLength(edit.text);
            var offset = edit.range.start + delta + newTextLen;
            if (offset > textLen)
                offset = textLen;
            editResults.push({range: edit.range, offset: offset});
            delta += newTextLen - (edit.range.end - edit.range.start);
        }

        final used = [for (_ in 0...editResults.length) false];
        final newSelections:Array<CursorSelection> = [];
        for (selection in originalSelections) {
            final index = binarySearchEdit(editResults, selection.start, selection.end);
            if (index >= 0 && !used[index]) {
                final offset = editResults[index].offset;
                used[index] = true;
                final selection = selection.copy();
                selection.placeAt(offset, null);
                newSelections.push(selection);
            }
        }
        for (index in 0...editResults.length) {
            if (!used[index]) {
                final offset = editResults[index].offset;
                newSelections.push(new CursorSelection(selections.generateId(), offset, offset));
            }
        }
        selections.replaceAll(newSelections);
        selections.mergeOverlapping();

        // Record the cursor snapshots for undo/redo restore.
        final selectionsAfter = CursorSelection.copyAll(selections.iter());
        if (recorded) {
            undoManager.recordAutoClosedPairs(autoClosedPairsBefore, mode.autoClosedPairs().clone());
            undoManager.recordSelections(selectionsBefore, selectionsAfter);
        }

        imeMarkedRange = null;
        this.updatePreferredColumn();
        this.dismissTouchSelection(cx);
        if (isMultiLine()) {
            mode.updateAutoGrow(displayMap);
        }
        if (emitEvents) {
            cx.emit(InputEvent.Change);
        }
        cx.notify();
    }

    /**
     * Rust `binary_search_by_key(&(start, end), |(range, _)| (range.start, range.end))`
     * on the edits sorted by start: the index of a match, or -1.
     */
    static function binarySearchEdit(results:Array<{range:Range, offset:Int}>, start:Int, end:Int):Int {
        var size = results.length;
        if (size == 0)
            return -1;
        var base = 0;
        // Rust's `binary_search_by` (1.82+): halve the size, then compare once at the end.
        while (size > 1) {
            final half = size >> 1;
            final mid = base + half;
            final r = results[mid].range;
            final cmp = compareTuple(r.start, r.end, start, end);
            if (cmp <= 0)
                base = mid;
            size -= half;
        }
        final r = results[base].range;
        return compareTuple(r.start, r.end, start, end) == 0 ? base : -1;
    }

    static inline function compareTuple(a0:Int, a1:Int, b0:Int, b1:Int):Int {
        return a0 != b0 ? (a0 < b0 ? -1 : 1) : (a1 != b1 ? (a1 < b1 ? -1 : 1) : 0);
    }

    /**
     * Update fold candidates from the syntax tree (full extraction).
     * Used only on initial load or language changes.
     */
    function updateFoldCandidates():Void {
        if (!mode.isFolding()) {
            return;
        }

        final highlighterCell = mode.highlighter();
        if (highlighterCell == null) {
            return;
        }

        final highlighter = highlighterCell.value;
        if (highlighter == null) {
            return;
        }

        final foldRanges = highlighter.foldRanges(text);
        displayMap.setFoldCandidates(foldRanges);
    }

    /**
     * Incrementally update fold candidates after a text edit.
     * Only traverses the edited region of the syntax tree instead of the full tree.
     */
    function updateFoldCandidatesIncremental(editRange:Range, newText:String):Void {
        if (!mode.isFolding()) {
            return;
        }

        final highlighterCell = mode.highlighter();
        if (highlighterCell == null) {
            return;
        }

        final highlighter = highlighterCell.value;
        if (highlighter == null) {
            return;
        }

        // The new byte range in the updated text after the edit
        final newEnd = editRange.start + Utf8.byteLength(newText);
        displayMap.updateFoldCandidatesForEdit((range, text) -> highlighter.foldRangesForEdit(range, text), new Range(editRange.start, newEnd), text);
    }

    // EntityInputHandler

    public function textForRange(rangeUtf16:Range, adjustedRange:Ref<Null<Range>>, window:Window, cx:Context<Dynamic>):Null<String> {
        final range = rangeFromUtf16(rangeUtf16);
        if (adjustedRange != null)
            adjustedRange.value = rangeToUtf16(range);
        return text.slice(range.start, range.end).toString();
    }

    public function selectedTextRange(ignoreDisabledInput:Bool, window:Window, cx:Context<Dynamic>):Null<UTF16Selection> {
        return new UTF16Selection(rangeToUtf16(selectedRange()), activeSelection().reversed);
    }

    public function markedTextRange(window:Window, cx:Context<Dynamic>):Null<Range> {
        final range = imeMarkedRange;
        return range != null ? rangeToUtf16(range.toRange()) : null;
    }

    public function unmarkText(window:Window, cx:Context<Dynamic>):Void {
        imeMarkedRange = null;
        undoManager.commitTransaction();
    }

    /**
     * Replace text in range.
     *
     * - If the new text is invalid, it will not be replaced.
     * - If `rangeUtf16` is not provided, the current selected range will be used.
     */
    public function replaceTextInRange(rangeUtf16:Null<Range>, newText:String, window:Window, cx:Context<Dynamic>):Void {
        final cx = typedCx(cx);
        final requestedIntent = undoManager.takePendingIntent();
        if (!isEditable()) {
            return;
        }
        final selectionBefore = activeSelection().copy();
        // Committing a composition ends the transaction it opened, whether or
        // not the platform follows up with `unmarkText`.
        final endsComposition = imeMarkedRange != null;

        pauseBlinkCursor(cx);

        // NOTE: The normalization keeps the UTF-16 length, but may change the
        // UTF-8 byte length, so all the byte-offset calculations below must
        // use the normalized text.
        final newText = replayingHistory ? newText : normalizeInput(newText);
        final newTextLen = Utf8.byteLength(newText);

        var range = if (rangeUtf16 != null) {
            rangeFromUtf16(rangeUtf16);
        }
        else if (imeMarkedRange != null) {
            rangeFromUtf16(rangeToUtf16(new Range(imeMarkedRange.start, imeMarkedRange.end)));
        }
        else {
            selectedRange();
        }
        range = this.normalizeTokenRange(range);

        // Skip-over as a pure cursor move: a typed closer that already follows
        // the cursor moves past it without touching text or history, so Undo
        // never exposes a transient duplicate. Only for interactive single
        // keystrokes (current selection, no IME mark, not silent replays).
        if (range.isEmpty()
            && range.start == cursor()
            && imeMarkedRange == null
            && !silentReplaceText
            && isCodeEditor()
            && selections.isSingle()
            && activeSelection().isEmpty()) {
            final target = skipOverTarget(newText);
            if (target != null) {
                setCursorTo(target);
                this.updatePreferredColumn();
                cx.notify();
                return;
            }
        }

        if (isMultiLine()) {
            final multiCursor = rangeUtf16 == null && imeMarkedRange == null && !selections.isSingle();
            if (multiCursor) {
                selections.mergeOverlapping();
                final edits:Array<TextEdit> = [for (sel in selections.iter()) new TextEdit(new Range(sel.start, sel.end), newText)];
                stableSortEdits(edits);
                // One keystroke across several cursors is one batch, committed
                // with the intent of the keystroke so a run of them coalesces
                // into one undo just like single-cursor typing.
                final intent = requestedIntent != null ? requestedIntent : typingIntent(edits, newText);
                undoManager.beginTransactionWith(intent);
                undoManager.setPendingIntent(intent);
                replaceTextInRanges(edits, window, cx);
                undoManager.commitTransaction();
            }
            else {
                if (rangeUtf16 != null) {
                    selections.removeAllButActive();
                }
                if (requestedIntent != null) {
                    undoManager.setPendingIntent(requestedIntent);
                }
                final autoClose = autoCloseTarget(range, newText);
                if (autoClose != null) {
                    // One edit keeps the pair atomic even at undo coalescing limits.
                    final replacement = newText + autoClose.closer;
                    replaceTextInRanges([new TextEdit(range, replacement)], window, cx);
                    final cursor = range.start + newTextLen;
                    mode.trackAutoClosedPair(new Range(cursor - autoClose.openLen, cursor), new Range(cursor, cursor + Utf8.byteLength(autoClose.closer)));
                    undoManager.recordAutoClosedPairsAfter(mode.autoClosedPairs().clone());
                    setCursorTo(cursor);
                    this.updatePreferredColumn();
                    undoManager.recordSelections([selectionBefore], CursorSelection.copyAll(selections.iter()));
                }
                else {
                    replaceTextInRanges([new TextEdit(range, newText)], window, cx);
                }
            }
            if (endsComposition) {
                undoManager.commitTransaction();
            }

            if (!silentReplaceText) {
                modeKind.onTextTyped(this, range, newText, window, cx);
            }
            return;
        }

        // Single-line path
        final oldText = text.clone();
        mode.adjustAutoClosedPair(range, newTextLen);
        text.replace(range, newText);

        var newOffset = range.start + newTextLen;
        if (newOffset > text.len())
            newOffset = text.len();

        // True if the mask has changed the text, e.g. regrouping the
        // separators or completing a leading dot.
        var maskChanged = false;

        if (isSingleLine()) {
            final pendingText = text.toString();
            // Check if the new text is valid.
            //
            // Only reject the edit if the old text was valid, to avoid
            // trapping a pre-existing invalid text (e.g. a `default_value`
            // that does not conform), the user can still edit to fix it.
            if (!replayingHistory && !validatedTokenEdit && !isValidInput(pendingText, cx) && isValidInput(oldText.toString(), cx)) {
                text = oldText;
                return;
            }

            if (!replayingHistory && !maskPattern.isNone()) {
                final maskText = maskPattern.mask(pendingText);
                maskChanged = maskText != pendingText;
                text = Rope.fromStr(maskText);
                final maskTextLen = Utf8.byteLength(maskText);
                final newTextLen2 = saturatingSub(newTextLen + maskTextLen, Utf8.byteLength(pendingText));
                newOffset = range.start + newTextLen2;
                if (newOffset > maskTextLen)
                    newOffset = maskTextLen;
            }
        }

        if (maskChanged) {
            // Masking rewrites the whole document, so ranges recorded against
            // the old text no longer point at anything.
            modeKind.resetAnnotations(this);
        }
        else {
            modeKind.adjustAnnotations(this, range, newTextLen);
        }
        if (maskChanged) {
            // A segment-based history entry no longer matches the masked
            // document, record a whole-document change instead, so that
            // undo/redo can restore the text exactly.
            pushHistory(oldText, new Range(0, oldText.len()), text.toString(), EditIntent.Atomic, selectionBefore,
                CursorSelection.fromRange(new Range(newOffset, newOffset)));
        }
        else {
            pushHistory(oldText, range, newText, requestedIntent, selectionBefore, null);
        }
        final diagnostics = mode.diagnosticsMut();
        if (diagnostics != null) {
            diagnostics.reset(text);
        }
        // Adjust folds before updating wrap map: remove overlapping folds and shift others
        displayMap.adjustFoldsForEdit(oldText, range, newText);
        displayMap.onTextChanged(text, range, Rope.fromStr(newText), cx.app);

        mode.updateHighlighter(new glaze.kit.base.input.LayoutMode.HighlighterUpdate(range, oldText, text, newText, true), modeKind, window, cx);

        updateFoldCandidatesIncremental(range, newText);
        modeKind.refreshLanguageFeatures(this, window, cx);
        setCursorTo(newOffset);
        imeMarkedRange = null;
        // A commit ends the IME composition: macOS delivers `insertText:` for
        // the confirmed candidate without a following `unmarkText`, so close
        // the transaction here. Leaving it open would keep merging every later
        // edit into the same change, which then carries the text and selection
        // of the first composition.
        if (endsComposition) {
            undoManager.recordSelections([selectionBefore], [activeSelection().copy()]);
            undoManager.commitTransaction();
        }
        this.updatePreferredColumn();
        this.updateSearch(cx.app);
        this.dismissTouchSelection(cx);
        if (isMultiLine()) {
            mode.updateAutoGrow(displayMap);
        }
        if (!silentReplaceText) {
            modeKind.onTextTyped(this, range, newText, window, cx);
        }
        // Initial port deviation DEV-009: only when the value changed, not for an
        // edit that left it as it was (a newline dropped by a single-line
        // input, a character rejected by the mask).
        if (emitEvents && (text.len() != oldText.len() || text.toString() != oldText.toString())) {
            cx.emit(InputEvent.Change);
        }
        cx.notify();
    }

    /** Mark text is the IME temporary insert on typing. */
    public function replaceAndMarkTextInRange(rangeUtf16:Null<Range>, newText:String, newSelectedRangeUtf16:Null<Range>, window:Window,
            cx:Context<Dynamic>):Void {
        final cx = typedCx(cx);
        final requestedIntent = undoManager.takePendingIntent();
        if (!isEditable()) {
            return;
        }
        final selectionBefore = activeSelection().copy();

        final startsComposition = imeMarkedRange == null;
        if (startsComposition) {
            // Even a canceled preedit separates the typing gestures on either
            // side; its no-op transaction must not reconnect those gestures.
            undoManager.breakTransactionCoalescing();
            undoManager.beginTransaction();
        }

        // Collapse any extra cursors so we never leave stale secondary cursors behind.
        selections.removeAllButActive();

        modeKind.resetLanguageFeatures(this);

        // See the same NOTE in `replaceTextInRange`.
        final newText = replayingHistory ? newText : normalizeInput(newText);
        final newTextLen = Utf8.byteLength(newText);

        var range = if (rangeUtf16 != null) {
            rangeFromUtf16(rangeUtf16);
        }
        else if (imeMarkedRange != null) {
            rangeFromUtf16(rangeToUtf16(new Range(imeMarkedRange.start, imeMarkedRange.end)));
        }
        else {
            selectedRange();
        }
        range = this.normalizeTokenRange(range);

        final autoClosedPairsBefore = mode.autoClosedPairs().clone();
        final oldText = text.clone();
        mode.adjustAutoClosedPair(range, newTextLen);
        text.replace(range, newText);

        if (isSingleLine()) {
            final pendingText = text.toString();
            // See the same NOTE in `replaceTextInRange`.
            if (!replayingHistory && !validatedTokenEdit && !isValidInput(pendingText, cx) && isValidInput(oldText.toString(), cx)) {
                text = oldText;
                if (startsComposition) {
                    undoManager.commitTransaction();
                }
                return;
            }
        }

        modeKind.adjustAnnotations(this, range, newTextLen);
        final diagnostics = mode.diagnosticsMut();
        if (diagnostics != null) {
            diagnostics.reset(text);
        }
        // Adjust folds before updating wrap map: remove overlapping folds and shift others
        displayMap.adjustFoldsForEdit(oldText, range, newText);
        displayMap.onTextChanged(text, range, Rope.fromStr(newText), cx.app);

        mode.updateHighlighter(new glaze.kit.base.input.LayoutMode.HighlighterUpdate(range, oldText, text, newText, true), modeKind, window, cx);

        updateFoldCandidatesIncremental(range, newText);
        modeKind.refreshLanguageFeatures(this, window, cx);
        if (newText.length == 0) {
            // Cancel selection, when cancel IME input.
            setCursorTo(range.start);
            imeMarkedRange = null;
        }
        else {
            imeMarkedRange = CursorSelection.fromRange(new Range(range.start, range.start + newTextLen));
            final newRange = if (newSelectedRangeUtf16 != null) {
                final newRope = Rope.fromStr(newText);
                new Range(range.start + newRope.offsetUtf16ToOffset(newSelectedRangeUtf16.start),
                    range.start + newRope.offsetUtf16ToOffset(newSelectedRangeUtf16.end));
            }
            else {
                new Range(range.start + newTextLen, range.start + newTextLen);
            }
            setSelection(newRange.start, newRange.end);
        }
        if (isMultiLine()) {
            mode.updateAutoGrow(displayMap);
        }
        if (pushHistory(oldText, range, newText, requestedIntent, selectionBefore, activeSelection().copy())) {
            undoManager.recordSelections([selectionBefore], [activeSelection().copy()]);
            undoManager.recordAutoClosedPairs(autoClosedPairsBefore, mode.autoClosedPairs().clone());
        }
        if (newText.length == 0) {
            undoManager.commitTransaction();
        }
        cx.notify();
    }

    /** Used to position IME candidates. */
    public function boundsForRange(rangeUtf16:Range, bounds:Bounds, window:Window, cx:Context<Dynamic>):Null<Bounds> {
        final lastLayout = this.lastLayout;
        if (lastLayout == null)
            return null;
        final lineHeight = lastLayout.lineHeight;
        final lineNumberWidth = lastLayout.lineNumberWidth;
        final range = rangeFromUtf16(rangeUtf16);

        var startOrigin:Null<Point> = null;
        var endOrigin:Null<Point> = null;
        final lineNumberOrigin = new Point(lineNumberWidth, 0.);
        var yOffset:Float = lastLayout.visibleTop;

        for (vi in 0...lastLayout.lines.length) {
            final line = lastLayout.lines[vi];
            if (startOrigin != null && endOrigin != null) {
                break;
            }

            final indexOffset = lastLayout.visibleLineByteOffsets[vi];

            if (startOrigin == null) {
                final p = line.positionForIndex(saturatingSub(range.start, indexOffset), lastLayout, false);
                if (p != null) {
                    startOrigin = p.add(new Point(0., yOffset));
                }
            }

            if (endOrigin == null) {
                final p = line.positionForIndex(saturatingSub(range.end, indexOffset), lastLayout, false);
                if (p != null) {
                    endOrigin = p.add(new Point(0., yOffset));
                }
            }

            yOffset += line.size(lineHeight).height;
        }

        if (startOrigin == null) {
            final offset:Int = lastCursor != null ? lastCursor : cursor();
            final origin = lineAndPositionForOffset(offset).position;
            if (origin == null)
                return null;
            startOrigin = origin.sub(lineNumberOrigin);
        }
        // Ensure at same line.
        final endX = endOrigin != null ? endOrigin.x : startOrigin.x;
        final endOrigin = new Point(endX, startOrigin.y);

        return Bounds.fromCorners(bounds.origin.add(lineNumberOrigin).add(startOrigin),
            // + line_height for show IME panel under the cursor line.
            bounds.origin.add(lineNumberOrigin).add(new Point(endOrigin.x, endOrigin.y + lineHeight)));
    }

    public function characterIndexForPoint(point:Point, window:Window, cx:Context<Dynamic>):Null<Int> {
        final lastLayout = this.lastLayout;
        if (lastLayout == null)
            return null;
        final lastBounds = this.lastBounds;
        if (lastBounds == null)
            return null;
        final linePoint = lastBounds.localize(point);
        if (linePoint == null)
            return null;

        for (vi in 0...lastLayout.lines.length) {
            final line = lastLayout.lines[vi];
            final offset = lastLayout.visibleLineByteOffsets[vi];
            final utf8Index = line.indexForPosition(linePoint, lastLayout);
            if (utf8Index != null) {
                return offsetToUtf16(offset + utf8Index);
            }
        }

        return null;
    }

    // Render

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx = typedCx(cx);
        // Before anything reads it: the element resolves this style during
        // layout and paint, and both happen after this call in the same frame.
        editorStyle = projectedEditorStyle.resolved(BaseTheme.global(cx.app).tokens);
        final entity:Entity<InputBaseState> = cx.entity();
        if (_pendingUpdate) {
            mode.updateHighlighter(new glaze.kit.base.input.LayoutMode.HighlighterUpdate(new Range(0, 0), text, text, "", false), modeKind, window, cx);

            updateFoldCandidates();
            modeKind.refreshLanguageFeatures(this, window, cx);
            _pendingUpdate = false;
        }

        // The listeners only call this state: made once (GPUI's `cx.listener`
        // makes them each frame)
        var listeners = renderListeners;
        if (listeners == null) {
            listeners = new InputRenderListeners(entity);
            renderListeners = listeners;
        }

        // Accessibility (`InputAccessibility`, `aria_*`, `on_a11y_action`) is
        // not exported: Glaze has no accessibility tree.
        var element = div().id(EDITOR_ELEMENT_ID).keyContext(CONTEXT);
        if (isEditable()) {
            element.onActionEntry(listeners.backspaceEntry)
                .onActionEntry(listeners.deleteEntry)
                .onActionEntry(listeners.deleteToBeginningOfLineEntry)
                .onActionEntry(listeners.deleteToEndOfLineEntry)
                .onActionEntry(listeners.deletePreviousWordEntry)
                .onActionEntry(listeners.deleteNextWordEntry)
                .onActionEntry(listeners.enterEntry)
                .onActionEntry(listeners.escapeEntry)
                .onActionEntry(listeners.pasteActionEntry)
                .onActionEntry(listeners.cutEntry)
                .onActionEntry(listeners.undoEntry)
                .onActionEntry(listeners.redoEntry);
            if (isMultiLine()) {
                element.onActionEntry(listeners.indentInlineEntry)
                    .onActionEntry(listeners.outdentInlineEntry)
                    .onActionEntry(listeners.indentBlockEntry)
                    .onActionEntry(listeners.outdentBlockEntry);
            }
        }
        element.onActionEntry(listeners.leftEntry)
            .onActionEntry(listeners.rightEntry)
            .onActionEntry(listeners.selectLeftEntry)
            .onActionEntry(listeners.selectRightEntry);
        if (isMultiLine()) {
            element.onActionEntry(listeners.upEntry)
                .onActionEntry(listeners.downEntry)
                .onActionEntry(listeners.selectUpEntry)
                .onActionEntry(listeners.selectDownEntry)
                .onActionEntry(listeners.pageUpEntry)
                .onActionEntry(listeners.pageDownEntry)
                .onActionEntry(listeners.addCursorAboveEntry)
                .onActionEntry(listeners.addCursorBelowEntry);
        }
        element.onActionEntry(listeners.onActionSelectAllEntry)
            .onActionEntry(listeners.selectToStartOfLineEntry)
            .onActionEntry(listeners.selectToEndOfLineEntry)
            .onActionEntry(listeners.selectToPreviousWordEntry)
            .onActionEntry(listeners.selectToNextWordEntry)
            .onActionEntry(listeners.homeEntry)
            .onActionEntry(listeners.endEntry)
            .onActionEntry(listeners.moveToStartEntry)
            .onActionEntry(listeners.moveToEndEntry)
            .onActionEntry(listeners.moveToPreviousWordEntry)
            .onActionEntry(listeners.moveToNextWordEntry)
            .onActionEntry(listeners.selectToStartEntry)
            .onActionEntry(listeners.selectToEndEntry)
            .onActionEntry(listeners.showCharacterPaletteEntry)
            .onActionEntry(listeners.activateTokenEntry)
            .onActionEntry(listeners.copyEntry)
            .onActionEntry(listeners.onActionSearchEntry)
            .onActionEntry(listeners.onActionReplaceEntry)
            .onMouseDown(MouseButton.Left, listeners.onMouseDown)
            .onMouseDown(MouseButton.Right, listeners.onMouseDown)
            .onMouseUp(MouseButton.Left, listeners.onMouseUp)
            .onMouseUp(MouseButton.Right, listeners.onMouseUp)
            .onMouseMove(listeners.onMouseMove)
            .onScroll(listeners.onScrollWheel);
        if (isMultiLine() && !disabled) {
            element.onModifiersChanged(listeners.modifiersChanged);
        }
        if (!disabled) {
            if (isMultiLine() && window.modifiers().alt) {
                element.cursorCrosshair();
            }
            else {
                element.cursorText();
            }
        }
        element.flex1();
        // A single line fills the frame and sits at its vertical center,
        // so the frame needs no layout of its own to hold it. It is never
        // shorter than its line, though: this root clips (overflow-x
        // hidden clips both axes), and a frame whose padding leaves less
        // than a line, like Component's Input, would cut off descenders.
        if (isMultiLine()) {
            element.hFull();
        }
        else {
            element.minHFull().flex().itemsCenter();
        }
        element.flexGrow1().overflowXHidden();
        if (isMultiLine()) {
            element.pt(px(editorPaddings.top)).pr(px(editorPaddings.right)).pb(px(editorPaddings.bottom)).pl(px(editorPaddings.left));
        }
        element.child(new TextElement(entity).placeholder(placeholder));
        if (showsScrollbar()) {
            element.child(new EditorScrollbar(entity));
        }

        // Actions only one mode handles are registered by that mode.
        return glaze.kit.base.Observe.testSupport(modeKind.registerActions(element, entity, window)).trackFocus(focusHandle);
    }

    // Helpers

    static inline function saturatingSub(a:Int, b:Int):Int {
        return a > b ? a - b : 0;
    }

    static inline function clampF(value:Float, min:Float, max:Float):Float {
        return value < min ? min : (value > max ? max : value);
    }

    /** Rust `str::chars().count()`. */
    static function charCount(s:String):Int {
        var count = 0;
        for (_ in new haxe.iterators.StringIteratorUnicode(s)) {
            count++;
        }
        return count;
    }

    /** Rust `s.contains(['\n', '\r'])`. */
    static inline function containsNewline(s:String):Bool {
        return s.indexOf("\n") != -1 || s.indexOf("\r") != -1;
    }

    static function stringContainsChar(s:String, c:Int):Bool {
        for (ch in new haxe.iterators.StringIteratorUnicode(s)) {
            if (ch == c)
                return true;
        }
        return false;
    }

    /** Rust `char::is_alphanumeric` (letters and numbers, Unicode). */
    static function isAlphanumeric(c:Int):Bool {
        if (c < 128)
            return Utf8.isAsciiAlphanumeric(c);
        return unicode_segmentation.Tables.isAlphanumeric(c);
    }

    /** Rust's stable `sort_by_key(|edit| edit.range.start)`. */
    static function stableSortEdits(edits:Array<TextEdit>):Void {
        haxe.ds.ArraySort.sort(edits, (a, b) -> a.range.start - b.range.start);
    }

    /** Rust's stable `sort_by_key(|edit| Reverse(edit.range.start))`. */
    static function stableSortEditsDescending(edits:Array<TextEdit>):Void {
        haxe.ds.ArraySort.sort(edits, (a, b) -> b.range.start - a.range.start);
    }

    /** Rust's stable `sort_by_key(|sel| sel.start)`. */
    static function stableSortSelections(selections:Array<CursorSelection>):Void {
        haxe.ds.ArraySort.sort(selections, (a, b) -> a.start - b.start);
    }

    /**
     * Rust `str::parse::<f64>()`: a decimal number with an optional sign,
     * fraction and exponent, `inf`, `infinity` or `nan` (any case), or null.
     */
    static function parseF64(s:String):Null<Float> {
        final number = ~/^[+-]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][+-]?[0-9]+)?$/;
        if (number.match(s)) {
            return Std.parseFloat(s);
        }
        final lower = s.toLowerCase();
        final unsigned = (lower.charAt(0) == "+" || lower.charAt(0) == "-") ? lower.substr(1) : lower;
        if (unsigned == "inf" || unsigned == "infinity") {
            return lower.charAt(0) == "-" ? Math.NEGATIVE_INFINITY : Math.POSITIVE_INFINITY;
        }
        if (unsigned == "nan") {
            return Math.NaN;
        }
        return null;
    }

    /** Rust's `{}` of an `f64` (shortest representation, no exponent for usual values). */
    static function f64ToString(value:Float):String {
        if (Math.isNaN(value))
            return "NaN";
        if (value == Math.POSITIVE_INFINITY)
            return "inf";
        if (value == Math.NEGATIVE_INFINITY)
            return "-inf";
        if (value == Math.ffloor(value) && Math.abs(value) < 1e15) {
            final s = Std.string(value);
            final dot = s.indexOf(".");
            return dot >= 0 ? s.substr(0, dot) : s;
        }
        for (digits in 1...18) {
            final s = toFixedTrimmed(value, digits);
            if (Std.parseFloat(s) == value)
                return s;
        }
        return Std.string(value);
    }

    static function toFixedTrimmed(value:Float, digits:Int):String {
        final scale = Math.pow(10, digits);
        final negative = value < 0;
        final scaled = Math.fround(Math.abs(value) * scale);
        final intPart = Math.ffloor(scaled / scale);
        var frac = Std.string(Std.int(scaled - intPart * scale));
        while (frac.length < digits)
            frac = "0" + frac;
        while (frac.length > 0 && frac.charAt(frac.length - 1) == "0")
            frac = frac.substr(0, frac.length - 1);
        var intString = Std.string(intPart);
        final dot = intString.indexOf(".");
        if (dot >= 0)
            intString = intString.substr(0, dot);
        final s = intString + (frac.length > 0 ? "." + frac : "");
        return negative ? "-" + s : s;
    }

}

/**
 * The listeners of `InputBaseState.render()`: they only call the state, so
 * one set per state serves every frame (no closures per render)
 */
@:access(glaze.kit.base.input.InputBaseState)
private class InputRenderListeners {

    public final backspace:(Dynamic, Window, App) -> Void;
    public final delete:(Dynamic, Window, App) -> Void;
    public final deleteToBeginningOfLine:(Dynamic, Window, App) -> Void;
    public final deleteToEndOfLine:(Dynamic, Window, App) -> Void;
    public final deletePreviousWord:(Dynamic, Window, App) -> Void;
    public final deleteNextWord:(Dynamic, Window, App) -> Void;
    public final enter:(Dynamic, Window, App) -> Void;
    public final escape:(Dynamic, Window, App) -> Void;
    public final pasteAction:(Dynamic, Window, App) -> Void;
    public final cut:(Dynamic, Window, App) -> Void;
    public final undo:(Dynamic, Window, App) -> Void;
    public final redo:(Dynamic, Window, App) -> Void;
    public final indentInline:(Dynamic, Window, App) -> Void;
    public final outdentInline:(Dynamic, Window, App) -> Void;
    public final indentBlock:(Dynamic, Window, App) -> Void;
    public final outdentBlock:(Dynamic, Window, App) -> Void;
    public final left:(Dynamic, Window, App) -> Void;
    public final right:(Dynamic, Window, App) -> Void;
    public final selectLeft:(Dynamic, Window, App) -> Void;
    public final selectRight:(Dynamic, Window, App) -> Void;
    public final up:(Dynamic, Window, App) -> Void;
    public final down:(Dynamic, Window, App) -> Void;
    public final selectUp:(Dynamic, Window, App) -> Void;
    public final selectDown:(Dynamic, Window, App) -> Void;
    public final pageUp:(Dynamic, Window, App) -> Void;
    public final pageDown:(Dynamic, Window, App) -> Void;
    public final addCursorAbove:(Dynamic, Window, App) -> Void;
    public final addCursorBelow:(Dynamic, Window, App) -> Void;
    public final onActionSelectAll:(Dynamic, Window, App) -> Void;
    public final selectToStartOfLine:(Dynamic, Window, App) -> Void;
    public final selectToEndOfLine:(Dynamic, Window, App) -> Void;
    public final selectToPreviousWord:(Dynamic, Window, App) -> Void;
    public final selectToNextWord:(Dynamic, Window, App) -> Void;
    public final home:(Dynamic, Window, App) -> Void;
    public final end:(Dynamic, Window, App) -> Void;
    public final moveToStart:(Dynamic, Window, App) -> Void;
    public final moveToEnd:(Dynamic, Window, App) -> Void;
    public final moveToPreviousWord:(Dynamic, Window, App) -> Void;
    public final moveToNextWord:(Dynamic, Window, App) -> Void;
    public final selectToStart:(Dynamic, Window, App) -> Void;
    public final selectToEnd:(Dynamic, Window, App) -> Void;
    public final showCharacterPalette:(Dynamic, Window, App) -> Void;
    public final copy:(Dynamic, Window, App) -> Void;
    public final onActionSearch:(Dynamic, Window, App) -> Void;
    public final onActionReplace:(Dynamic, Window, App) -> Void;
    public final onMouseDown:(Dynamic, Window, App) -> Void;
    public final onMouseUp:(Dynamic, Window, App) -> Void;
    public final onMouseMove:(Dynamic, Window, App) -> Void;
    public final onScrollWheel:(Dynamic, Window, App) -> Void;
    public final activateToken:(ActivateToken, Window, App) -> Void;
    public final modifiersChanged:(glaze.ModifiersChangedEvent, Window, App) -> Void;

    /** The action entries of the listeners (immutable, added to the element each frame) */
    public final backspaceEntry:glaze.Interactivity.TypedActionListener;
    public final deleteEntry:glaze.Interactivity.TypedActionListener;
    public final deleteToBeginningOfLineEntry:glaze.Interactivity.TypedActionListener;
    public final deleteToEndOfLineEntry:glaze.Interactivity.TypedActionListener;
    public final deletePreviousWordEntry:glaze.Interactivity.TypedActionListener;
    public final deleteNextWordEntry:glaze.Interactivity.TypedActionListener;
    public final enterEntry:glaze.Interactivity.TypedActionListener;
    public final escapeEntry:glaze.Interactivity.TypedActionListener;
    public final pasteActionEntry:glaze.Interactivity.TypedActionListener;
    public final cutEntry:glaze.Interactivity.TypedActionListener;
    public final undoEntry:glaze.Interactivity.TypedActionListener;
    public final redoEntry:glaze.Interactivity.TypedActionListener;
    public final indentInlineEntry:glaze.Interactivity.TypedActionListener;
    public final outdentInlineEntry:glaze.Interactivity.TypedActionListener;
    public final indentBlockEntry:glaze.Interactivity.TypedActionListener;
    public final outdentBlockEntry:glaze.Interactivity.TypedActionListener;
    public final leftEntry:glaze.Interactivity.TypedActionListener;
    public final rightEntry:glaze.Interactivity.TypedActionListener;
    public final selectLeftEntry:glaze.Interactivity.TypedActionListener;
    public final selectRightEntry:glaze.Interactivity.TypedActionListener;
    public final upEntry:glaze.Interactivity.TypedActionListener;
    public final downEntry:glaze.Interactivity.TypedActionListener;
    public final selectUpEntry:glaze.Interactivity.TypedActionListener;
    public final selectDownEntry:glaze.Interactivity.TypedActionListener;
    public final pageUpEntry:glaze.Interactivity.TypedActionListener;
    public final pageDownEntry:glaze.Interactivity.TypedActionListener;
    public final addCursorAboveEntry:glaze.Interactivity.TypedActionListener;
    public final addCursorBelowEntry:glaze.Interactivity.TypedActionListener;
    public final onActionSelectAllEntry:glaze.Interactivity.TypedActionListener;
    public final selectToStartOfLineEntry:glaze.Interactivity.TypedActionListener;
    public final selectToEndOfLineEntry:glaze.Interactivity.TypedActionListener;
    public final selectToPreviousWordEntry:glaze.Interactivity.TypedActionListener;
    public final selectToNextWordEntry:glaze.Interactivity.TypedActionListener;
    public final homeEntry:glaze.Interactivity.TypedActionListener;
    public final endEntry:glaze.Interactivity.TypedActionListener;
    public final moveToStartEntry:glaze.Interactivity.TypedActionListener;
    public final moveToEndEntry:glaze.Interactivity.TypedActionListener;
    public final moveToPreviousWordEntry:glaze.Interactivity.TypedActionListener;
    public final moveToNextWordEntry:glaze.Interactivity.TypedActionListener;
    public final selectToStartEntry:glaze.Interactivity.TypedActionListener;
    public final selectToEndEntry:glaze.Interactivity.TypedActionListener;
    public final showCharacterPaletteEntry:glaze.Interactivity.TypedActionListener;
    public final activateTokenEntry:glaze.Interactivity.TypedActionListener;
    public final copyEntry:glaze.Interactivity.TypedActionListener;
    public final onActionSearchEntry:glaze.Interactivity.TypedActionListener;
    public final onActionReplaceEntry:glaze.Interactivity.TypedActionListener;

    public function new(entity:Entity<InputBaseState>) {
        backspace = (event, window, cx) -> entity.update(cx, (state, cx) -> state.backspace(event, window, cx));
        delete = (event, window, cx) -> entity.update(cx, (state, cx) -> state.delete(event, window, cx));
        deleteToBeginningOfLine = (event, window, cx) -> entity.update(cx, (state, cx) -> state.deleteToBeginningOfLine(event, window, cx));
        deleteToEndOfLine = (event, window, cx) -> entity.update(cx, (state, cx) -> state.deleteToEndOfLine(event, window, cx));
        deletePreviousWord = (event, window, cx) -> entity.update(cx, (state, cx) -> state.deletePreviousWord(event, window, cx));
        deleteNextWord = (event, window, cx) -> entity.update(cx, (state, cx) -> state.deleteNextWord(event, window, cx));
        enter = (event, window, cx) -> entity.update(cx, (state, cx) -> state.enter(event, window, cx));
        escape = (event, window, cx) -> entity.update(cx, (state, cx) -> state.escape(event, window, cx));
        pasteAction = (event, window, cx) -> entity.update(cx, (state, cx) -> state.pasteAction(event, window, cx));
        cut = (event, window, cx) -> entity.update(cx, (state, cx) -> state.cut(event, window, cx));
        undo = (event, window, cx) -> entity.update(cx, (state, cx) -> state.undo(event, window, cx));
        redo = (event, window, cx) -> entity.update(cx, (state, cx) -> state.redo(event, window, cx));
        indentInline = (event, window, cx) -> entity.update(cx, (state, cx) -> state.indentInline(event, window, cx));
        outdentInline = (event, window, cx) -> entity.update(cx, (state, cx) -> state.outdentInline(event, window, cx));
        indentBlock = (event, window, cx) -> entity.update(cx, (state, cx) -> state.indentBlock(event, window, cx));
        outdentBlock = (event, window, cx) -> entity.update(cx, (state, cx) -> state.outdentBlock(event, window, cx));
        left = (event, window, cx) -> entity.update(cx, (state, cx) -> state.left(event, window, cx));
        right = (event, window, cx) -> entity.update(cx, (state, cx) -> state.right(event, window, cx));
        selectLeft = (event, window, cx) -> entity.update(cx, (state, cx) -> state.selectLeft(event, window, cx));
        selectRight = (event, window, cx) -> entity.update(cx, (state, cx) -> state.selectRight(event, window, cx));
        up = (event, window, cx) -> entity.update(cx, (state, cx) -> state.up(event, window, cx));
        down = (event, window, cx) -> entity.update(cx, (state, cx) -> state.down(event, window, cx));
        selectUp = (event, window, cx) -> entity.update(cx, (state, cx) -> state.selectUp(event, window, cx));
        selectDown = (event, window, cx) -> entity.update(cx, (state, cx) -> state.selectDown(event, window, cx));
        pageUp = (event, window, cx) -> entity.update(cx, (state, cx) -> state.pageUp(event, window, cx));
        pageDown = (event, window, cx) -> entity.update(cx, (state, cx) -> state.pageDown(event, window, cx));
        addCursorAbove = (event, window, cx) -> entity.update(cx, (state, cx) -> state.addCursorAbove(event, window, cx));
        addCursorBelow = (event, window, cx) -> entity.update(cx, (state, cx) -> state.addCursorBelow(event, window, cx));
        onActionSelectAll = (event, window, cx) -> entity.update(cx, (state, cx) -> state.onActionSelectAll(event, window, cx));
        selectToStartOfLine = (event, window, cx) -> entity.update(cx, (state, cx) -> state.selectToStartOfLine(event, window, cx));
        selectToEndOfLine = (event, window, cx) -> entity.update(cx, (state, cx) -> state.selectToEndOfLine(event, window, cx));
        selectToPreviousWord = (event, window, cx) -> entity.update(cx, (state, cx) -> state.selectToPreviousWord(event, window, cx));
        selectToNextWord = (event, window, cx) -> entity.update(cx, (state, cx) -> state.selectToNextWord(event, window, cx));
        home = (event, window, cx) -> entity.update(cx, (state, cx) -> state.home(event, window, cx));
        end = (event, window, cx) -> entity.update(cx, (state, cx) -> state.end(event, window, cx));
        moveToStart = (event, window, cx) -> entity.update(cx, (state, cx) -> state.moveToStart(event, window, cx));
        moveToEnd = (event, window, cx) -> entity.update(cx, (state, cx) -> state.moveToEnd(event, window, cx));
        moveToPreviousWord = (event, window, cx) -> entity.update(cx, (state, cx) -> state.moveToPreviousWord(event, window, cx));
        moveToNextWord = (event, window, cx) -> entity.update(cx, (state, cx) -> state.moveToNextWord(event, window, cx));
        selectToStart = (event, window, cx) -> entity.update(cx, (state, cx) -> state.selectToStart(event, window, cx));
        selectToEnd = (event, window, cx) -> entity.update(cx, (state, cx) -> state.selectToEnd(event, window, cx));
        showCharacterPalette = (event, window, cx) -> entity.update(cx, (state, cx) -> state.showCharacterPalette(event, window, cx));
        copy = (event, window, cx) -> entity.update(cx, (state, cx) -> state.copy(event, window, cx));
        onActionSearch = (event, window, cx) -> entity.update(cx, (state, cx) -> state.onActionSearch(event, window, cx));
        onActionReplace = (event, window, cx) -> entity.update(cx, (state, cx) -> state.onActionReplace(event, window, cx));
        onMouseDown = (event, window, cx) -> entity.update(cx, (state, cx) -> state.onMouseDown(event, window, cx));
        onMouseUp = (event, window, cx) -> entity.update(cx, (state, cx) -> state.onMouseUp(event, window, cx));
        onMouseMove = (event, window, cx) -> entity.update(cx, (state, cx) -> state.onMouseMove(event, window, cx));
        onScrollWheel = (event, window, cx) -> entity.update(cx, (state, cx) -> state.onScrollWheel(event, window, cx));
        activateToken = (_, window, cx) -> {
            final state = entity.read(cx);
            var activation:Null<InputTokenPresentation.TokenClickActivation> = null;
            final selected = state.selectedRange();
            for (span in state.tokenSpans()) {
                if (span.range().equals(selected)) {
                    final bounds = state.rangeToBounds(span.range());
                    if (bounds != null) {
                        activation = state.tokenActivation(span.range().start, bounds, ClickEvent.Keyboard(new glaze.ClickEvent.KeyboardClickEvent(glaze.KeyboardButton.Enter, bounds)));
                    }
                    break;
                }
            }
            if (activation != null) {
                activation.listener(activation.event, window, cx);
            }
        };
        modifiersChanged = (_, _, cx) -> entity.update(cx, (_, cx) -> cx.notify());
        backspaceEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(Backspace, backspace);
        deleteEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(Delete, delete);
        deleteToBeginningOfLineEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(DeleteToBeginningOfLine, deleteToBeginningOfLine);
        deleteToEndOfLineEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(DeleteToEndOfLine, deleteToEndOfLine);
        deletePreviousWordEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(DeleteToPreviousWordStart, deletePreviousWord);
        deleteNextWordEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(DeleteToNextWordEnd, deleteNextWord);
        enterEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(glaze.kit.base.input.InputActions.Enter, enter);
        escapeEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(glaze.kit.base.input.InputActions.Escape, escape);
        pasteActionEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(Paste, pasteAction);
        cutEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(Cut, cut);
        undoEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(Undo, undo);
        redoEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(Redo, redo);
        indentInlineEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(IndentInline, indentInline);
        outdentInlineEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(OutdentInline, outdentInline);
        indentBlockEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(glaze.kit.base.input.InputActions.Indent, indentBlock);
        outdentBlockEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(glaze.kit.base.input.InputActions.Outdent, outdentBlock);
        leftEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(MoveLeft, left);
        rightEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(MoveRight, right);
        selectLeftEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(SelectLeft, selectLeft);
        selectRightEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(SelectRight, selectRight);
        upEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(MoveUp, up);
        downEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(MoveDown, down);
        selectUpEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(SelectUp, selectUp);
        selectDownEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(SelectDown, selectDown);
        pageUpEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(MovePageUp, pageUp);
        pageDownEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(MovePageDown, pageDown);
        addCursorAboveEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(AddCursorAbove, addCursorAbove);
        addCursorBelowEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(AddCursorBelow, addCursorBelow);
        onActionSelectAllEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(SelectAll, onActionSelectAll);
        selectToStartOfLineEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(SelectToStartOfLine, selectToStartOfLine);
        selectToEndOfLineEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(SelectToEndOfLine, selectToEndOfLine);
        selectToPreviousWordEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(SelectToPreviousWordStart, selectToPreviousWord);
        selectToNextWordEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(SelectToNextWordEnd, selectToNextWord);
        homeEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(MoveHome, home);
        endEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(MoveEnd, end);
        moveToStartEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(MoveToStart, moveToStart);
        moveToEndEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(MoveToEnd, moveToEnd);
        moveToPreviousWordEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(MoveToPreviousWord, moveToPreviousWord);
        moveToNextWordEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(MoveToNextWord, moveToNextWord);
        selectToStartEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(SelectToStart, selectToStart);
        selectToEndEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(SelectToEnd, selectToEnd);
        showCharacterPaletteEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(ShowCharacterPalette, showCharacterPalette);
        activateTokenEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(ActivateToken, activateToken);
        copyEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(Copy, copy);
        onActionSearchEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(glaze.kit.base.input.InputActions.Search, onActionSearch);
        onActionReplaceEntry = @:privateAccess glaze.Interactivity.bubbleActionEntry(Replace, onActionReplace);
    }
}
