// Ported from gpui-kit 0.8.1: crates/component/src/inspector.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.inspector;

import glaze.App;
import glaze.ElementId;
import glaze.GlobalElementId;
import glaze.StyleRefinement;
import glaze.kit.base.input.Diagnostic;
import glaze.kit.base.input.DiagnosticSeverity;
import glaze.kit.base.input.LspPosition;
import glaze.Window;
import ropey.Rope;

using glaze.StyleRefinementOps;
using glaze.kit.base.input.RopeExt;

#if glaze_inspector
#if !plugin_cityscape
#error 'The Glaze inspector (define glaze_inspector) edits styles with Cityscape: list the cityscape plugin next to glaze in the plugins of ceramic.yml'
#end
import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages.CompletionContext;
import cityscape.common.Languages.CompletionItem;
import cityscape.common.Languages.CompletionItemProvider;
import cityscape.common.Languages.CompletionList;
import cityscape.common.languages.CompletionItemKind;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions.IEditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range as CityscapeRange;
import cityscape.common.model.TextModel;
import cityscape.kit.KitGrammars;
import cityscape.kit.KitTheme;
import cityscape.platform.markers.common.Markers.MarkerSeverity;
import glaze.AnyElement;
import glaze.Context;
import glaze.DivInspectorState;
import glaze.Entity;
import glaze.InspectorElementId;
import glaze.IntoElement;
import glaze.KeyBinding;
import glaze.Model;
import glaze.OperatingSystem;
import glaze.Render;
import glaze.kit.IconName;
import glaze.kit.TitleBar;
import glaze.kit.alert.Alert;
import glaze.kit.button.Button;
import glaze.kit.clipboard.Clipboard;
import glaze.kit.descriptionlist.DescriptionList;
import glaze.kit.highlighter.Highlighter;
import glaze.kit.link.Link;
import glaze.kit.theme.Theme;
import glaze.kit.inspector.SerdeJson.SerdeError;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;
#end

/**
 * gpui-kit's element inspector (`inspector.rs`).
 *
 * The data side is always available: the reflected style methods
 * (`InspectorStyleMethods`), `rustToStyle` (Rust builder calls to a style,
 * with diagnostics), `styleToRust` and `styleToJson`, and the completions of
 * the Rust editor (`styleMethodCompletions`).
 *
 * The panel needs GPUI's inspector (define `glaze_inspector`, Rust feature
 * `inspector`): `Inspector.init` (called by `Kit.init`) binds
 * `ToggleInspector` (cmd-alt-i on macOS, ctrl-shift-i elsewhere), registers
 * `DivInspector` for `DivInspectorState` and sets `renderInspector` as the
 * renderer of GPUI's inspector panel.
 *
 * The panel's style editors are Cityscape editors (gpui-kit's code editor
 * is not part of Glaze), so a project built with `glaze_inspector` lists the
 * `cityscape` plugin next to `glaze` in its `ceramic.yml` (a Ceramic plugin
 * cannot enable another one): the build stops with an error saying so
 * otherwise. Without `glaze_inspector`, Glaze does not depend on Cityscape.
 */
class Inspector {

    #if glaze_inspector
    /**
     * Initialize the inspector and register the action to toggle it.
     */
    public static function init(cx:App):Void {
        cx.bindKeys([
            OperatingSystem.current.isMac()
                ? new KeyBinding('cmd-alt-i', new ToggleInspector(), null)
                : new KeyBinding('ctrl-shift-i', new ToggleInspector(), null)
        ]);

        cx.onAction(ToggleInspector, (_, cx) -> {
            final activeWindow = cx.activeWindow();
            if (activeWindow == null) {
                return;
            }

            cx.defer(cx -> {
                if (!@:privateAccess activeWindow.destroyed) {
                    activeWindow.toggleInspector(cx);
                }
            });
        });

        cx.registerInspectorElement(DivInspectorState, (window, cx) -> {
            final divInspector = cx.newEntity((dcx:Context<DivInspector>) -> new DivInspector(window, dcx));
            return (id:InspectorElementId, state:DivInspectorState, window:Window, cx:App) -> {
                return divInspector.update(cx, (this_, dcx) -> {
                    this_.updateInspectedElement(id, state.clone(), window, dcx);
                    return this_.render(window, cast dcx);
                });
            };
        });

        cx.setInspectorRenderer(renderInspector);
    }
    #end

    /** `serde_json::to_string_pretty(style)` (Rust `style_to_json`) */
    public static function styleToJson(style:StyleRefinement):String {
        return StyleJson.toJson(style);
    }

    /**
     * Rust `style_to_rust`: the builder calls of the reflected methods
     * whose style is part of `inputStyle`, in table order, and the style
     * they make (the rest of `inputStyle` cannot be written as such calls).
     */
    public static function styleToRust(inputStyle:StyleRefinement):{code:String, style:StyleRefinement} {
        final methods = [for (entry in InspectorStyleMethods.get().table) if (inputStyle.isSupersetOf(entry.style)) entry.method];
        final code = new StringBuf();
        code.add('fn build() -> Div {\n    div()\n');
        var style = new StyleRefinement();
        for (method in methods) {
            final beforeInvoke = style.clone();
            style = method.invoke(style);
            if (!style.equalsIgnoringDebug(beforeInvoke)) {
                code.add('        .${method.name}()\n');
            }
        }
        code.add('}');
        return {code: code.toString(), style: style};
    }

    /**
     * Applies the style methods called in `source` (Rust builder code such
     * as `div().p_1().mx_2()`) to `style`, after `div()`, skipping comment
     * lines. Unknown methods are reported as errors at their position.
     */
    public static function rustToStyle(style:StyleRefinement, source:String):{style:StyleRefinement, diagnostics:Array<Diagnostic>} {
        final rope = Rope.fromStr(source);
        final divIndex = byteIndexOf(source, 'div()');
        if (divIndex < 0) {
            final startPos = new LspPosition(0, 0);
            final endPos = rope.offsetToPosition(rope.len());
            return {
                style: style,
                diagnostics: [new Diagnostic(startPos, endPos, 'expected `div()`').withSeverity(DiagnosticSeverity.Error)]
            };
        }
        final begin = divIndex + 'div()'.length;

        final methods:Array<{offset:Int, name:String}> = [];
        var offset = 0;
        var methodOffset = 0;
        var method = new StringBuf();
        var methodLength = 0;
        for (line in rope.iterLines()) {
            if (StringTools.startsWith(StringTools.trim(line.toString()), '//')) {
                offset += line.len() + 1;
                continue;
            }

            for (c in line.chars()) {
                offset += utf8Len(c);
                if (offset < begin) {
                    continue;
                }

                if (isAsciiAlphanumeric(c) || c == '_'.code) {
                    method.addChar(c);
                    methodLength++;
                    methodOffset = offset;
                }
                else {
                    if (methodLength > 0) {
                        methods.push({offset: methodOffset, name: method.toString()});
                    }
                    method = new StringBuf();
                    methodLength = 0;
                }
            }

            // +1 \n
            offset += 1;
        }

        final diagnostics:Array<Diagnostic> = [];
        final styleMethods = InspectorStyleMethods.get();

        for (entry in methods) {
            final reflection = styleMethods.map.get(entry.name);
            if (reflection != null) {
                style = reflection.invoke(style);
            }
            else {
                final message = 'unknown method `${entry.name}`';
                final startOffset = entry.offset - entry.name.length;
                final start = rope.offsetToPosition(startOffset > 0 ? startOffset : 0);
                final end = rope.offsetToPosition(entry.offset);
                diagnostics.push(new Diagnostic(start, end, message).withSeverity(DiagnosticSeverity.Error));
            }
        }

        return {style: style, diagnostics: diagnostics};
    }

    /**
     * The style methods to complete at `offset` (a UTF-16 offset in `text`,
     * the code of the Rust editor), the logic of the Rust `LspProvider`:
     * looking left of the cursor (at most 100 characters) for a `.`, the
     * methods whose name starts with what follows it. Null when the text
     * before the cursor does not start with a dot. `start` is the offset of
     * the dot (the completion replaces the dot and the typed prefix).
     *
     * Rust lists the methods in the iteration order of a `HashMap`
     * (random); the port lists them in table order.
     */
    public static function styleMethodCompletions(text:String, offset:Int):Null<{start:Int, prefix:String, methods:Array<{name:String, documentation:Null<String>}>}> {
        // Rust `rope.char_at(offset - left_offset)`: the character at the
        // cursor first (none at the very end of the text), then leftwards
        var leftOffset = 0;
        while (leftOffset < 100) {
            final index = offset - leftOffset > 0 ? offset - leftOffset : 0;
            if (index >= text.length) {
                break;
            }
            if (StringTools.fastCodeAt(text, index) == '.'.code) {
                break;
            }
            leftOffset++;
        }
        final start = offset - leftOffset > 0 ? offset - leftOffset : 0;
        final triggerCharacter = text.substring(start, offset);
        if (!StringTools.startsWith(triggerCharacter, '.')) {
            return null;
        }
        final methods = InspectorStyleMethods.get();
        final prefix = triggerCharacter.substr(1);
        final result:Array<{name:String, documentation:Null<String>}> = [];
        for (name in methods.names) {
            if (StringTools.startsWith(name, prefix)) {
                result.push({name: name, documentation: methods.map.get(name).documentation});
            }
        }
        return {start: start, prefix: prefix, methods: result};
    }

    static inline function isAsciiAlphanumeric(c:Int):Bool {
        return (c >= '0'.code && c <= '9'.code) || (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code);
    }

    static inline function utf8Len(c:Int):Int {
        return c < 0x80 ? 1 : c < 0x800 ? 2 : c < 0x10000 ? 3 : 4;
    }

    /** Rust `str::find`: the UTF-8 byte offset of `needle`, or -1. */
    static function byteIndexOf(text:String, needle:String):Int {
        final index = text.indexOf(needle);
        if (index < 0) return -1;
        return haxe.io.Bytes.ofString(text.substr(0, index)).length;
    }

    /**
     * Rust `Display` of an `ElementId` (the port keeps `view-` followed by
     * its own entity ids, and code locations without a column).
     */
    public static function elementIdDisplay(id:ElementId):String {
        return switch id {
            case View(entityId): 'view-' + entityId;
            case Integer(id): '' + id;
            case Name(name): name;
            case NamedInteger(name, id): name + '-' + id;
            case CodeLocation(file, line): file + ':' + line;
            case NamedChild(parent, name): elementIdDisplay(parent) + '-' + name;
        }
    }

    /** Rust `Display` of a `GlobalElementId`: the ids joined by `.` */
    public static function globalIdDisplay(id:GlobalElementId):String {
        return [for (elementId in id.ids()) elementIdDisplay(elementId)].join('.');
    }

    #if glaze_inspector
    /**
     * Renders GPUI's inspector panel (Rust `render_inspector`).
     */
    public static function renderInspector(inspector:glaze.Inspector, window:Window, cx:Context<glaze.Inspector>):AnyElement {
        final theme = Theme.global(cx.app);
        final inspectorElementId = inspector.activeElementId();
        final sourceLocation = inspectorElementId != null ? InspectorElementId.InspectorElementPath.formatLocation(inspectorElementId.path.sourceLocation) : null;
        final elementGlobalId = inspectorElementId != null ? globalIdDisplay(inspectorElementId.path.globalId) : null;

        final body = vFlex()
            .flex1()
            .p3()
            .gapY3()
            .textSm()
            .whenSome(sourceLocation, (this_, sourceLocation) -> {
                return this_.child(
                    hFlex()
                        .gapX2()
                        .textSm()
                        .child(
                            // Qualified: `Link` alone is the `ButtonVariant.Link` constructor of the imported `Button` module
                            glaze.kit.link.Link.component('source-location')
                                .href('file://' + sourceLocation)
                                .child(sourceLocation)
                                .flex1()
                                .overflowXHidden()
                        )
                        .child(Clipboard.component('copy-source-location').value(sourceLocation))
                );
            });
        if (elementGlobalId != null) {
            body.child(elementGlobalId);
        }
        body.children(cast inspector.renderInspectorStates(window, cx));

        return vFlex()
            .id('inspector')
            .fontFamily(theme.fontFamily)
            .sizeFull()
            .bg(theme.tokens.background.background)
            .borderL1()
            .borderColor(theme.border)
            .textColor(theme.foreground)
            .child(
                hFlex()
                    .wFull()
                    .justifyBetween()
                    .gap2()
                    .h(TitleBar.TITLE_BAR_HEIGHT)
                    .lineHeight(TitleBar.TITLE_BAR_HEIGHT)
                    .overflowXHidden()
                    .px2()
                    .borderB1()
                    .borderColor(theme.titleBarBorder)
                    .bg(theme.tokens.titleBar.background)
                    .child(
                        hFlex()
                            .gap2()
                            .textSm()
                            .child(
                                Button.component('inspect')
                                    .icon(IconName.Inspector)
                                    .selected(inspector.isPicking())
                                    .toggled(inspector.isPicking())
                                    .small()
                                    .ghost()
                                    .onClick(cx.listener((this_:glaze.Inspector, _, window:Window, _) -> {
                                        this_.startPicking();
                                        window.refresh();
                                    }))
                            )
                            .child('Inspector')
                    )
                    .child(
                        Button.component('close')
                            .icon(IconName.Close)
                            .small()
                            .ghost()
                            .onClick((_, window, cx) -> {
                                window.dispatchAction(new ToggleInspector(), cx);
                            })
                    )
            )
            .child(body)
            .intoAnyElement();
    }
    #end

}

#if glaze_inspector
/**
 * Toggles the inspector of the active window.
 */
@:action(namespace = inspector) class ToggleInspector implements glaze.Action {}

/**
 * An editor of the inspector panel (a Cityscape model), with its parse error.
 */
private class InspectorEditor {

    /** The text of the editor. */
    public final model:ITextModel;

    /** Error to display from parsing the input, or if serialization errors somehow occur. */
    public var error:Null<String> = null;

    /** Whether the editor is currently being edited. */
    public var editing:Bool = false;

    /**
     * True while the panel sets the text itself: gpui-kit's `set_value`
     * emits no change event, so these edits do not reach `editJson` and
     * `editRust`.
     */
    public var settingValue:Bool = false;

    /** The editor showing the model, once on screen. */
    public var editor:Null<CityscapeEditor> = null;

    public function new(model:ITextModel) {
        this.model = model;
    }

    /** The text of the editor (Rust `InputState::value`). */
    public function value():String {
        return model.getValue();
    }

    /**
     * Replaces the text, without a change event, and scrolls the editor back
     * to the start (Rust `InputState::set_value`).
     */
    public function setValue(value:String):Void {
        settingValue = true;
        model.setValue(value);
        settingValue = false;
        final editor = this.editor;
        if (editor != null && editor.getEditor() != null) {
            editor.setScrollPosition({scrollLeft: 0, scrollTop: 0}, cityscape.common.EditorCommon.ScrollType.Immediate);
        }
    }

}

/**
 * The inspector of a `Div` (an element whose state is a `DivInspectorState`):
 * its bounds and its base style, editable as Rust builder calls and as JSON.
 *
 * gpui-kit edits them with its code editor; Glaze uses Cityscape
 * (`CityscapeEditor`), configured to look like gpui-kit's: the kit's mono
 * font and size with rows of 1.5 times the size, the kit theme's colors
 * (`cityscape.kit.KitTheme`), indent guides, no line numbers, the text where
 * gpui-kit's editor puts it (after its folding gutter), the kit's frame and
 * scrollbar. Rust and JSON are colored when the kit's highlighter is enabled
 * (`glaze.kit.highlighter.Highlighter.enable`), like gpui-kit's editor.
 */
class DivInspector extends Model implements Render {

    /** Where the text starts in the editor frame: gpui-kit's left padding (6) and folding gutter (6 + 18). */
    static inline final TEXT_LEFT:Float = 30.;

    /** The vertical padding of gpui-kit's editor (`Size.Medium.inputPy`). */
    static inline final PADDING_Y:Int = 8;

    /** The rows of gpui-kit's code editor: 1.5 times the font size. */
    static inline final LINE_HEIGHT:Float = 1.5;

    static inline final MARKER_OWNER = 'inspector';

    var inspectorId:Null<InspectorElementId> = null;

    var inspectorState:Null<DivInspectorState> = null;

    /** The Cityscape context of the two editors (languages, theme, providers). */
    final context:Cityscape;

    final rustState:InspectorEditor;

    final jsonState:InspectorEditor;

    /** Initial style before any edits */
    var initialStyle:StyleRefinement = new StyleRefinement();

    /** Part of the initial style that could not be converted to Rust code */
    var unconvertibleStyle:StyleRefinement = new StyleRefinement();

    /** Whether the bundled grammars were registered (once the highlighter is enabled). */
    var grammarsRegistered:Bool = false;

    /** The editors on screen, by key (`rust-editor`, `json-editor`). */
    @:allow(tests) final editors:Map<String, CityscapeEditor> = new Map();

    /** The options of the editors, and the font they were made for. */
    var options:Null<IEditorOptions> = null;

    var optionsFontKey:String = '';

    public function new(window:Window, cx:Context<DivInspector>) {
        super();
        context = new Cityscape();
        context.languageService.registerLanguage({id: 'rust', extensions: ['.rs'], aliases: ['Rust']});
        context.languageService.registerLanguage({id: 'json', extensions: ['.json'], aliases: ['JSON']});
        context.registerCompletionItemProvider('rust', new InspectorCompletionProvider());

        // gpui-kit's editors: JSON indented by 2 spaces (its default
        // `TabSize`), Rust by 4. The models are filled later with
        // `setValue`, which does not detect the indentation (Monaco detects
        // it at creation only): the sizes are set, indent guides included
        // (`indentSize`)
        final jsonModel = new TextModel('', 'json', modelOptions(2), null, context);
        final rustModel = new TextModel('', 'rust', modelOptions(4), null, context);

        rustState = new InspectorEditor(rustModel);
        jsonState = new InspectorEditor(jsonModel);
        registerGrammars();
        KitTheme.apply(context, Theme.global(cx.app), true);

        // The edits of the user (the changes the panel makes itself are
        // skipped, see `InspectorEditor.setValue`) go to `editJson` and
        // `editRust` (Rust: the `InputEvent::Change` subscriptions)
        final app = cx.app;
        final entity = cx.weakEntity();
        jsonModel.onDidChangeContent(_ -> {
            if (jsonState.settingValue) {
                return;
            }
            entity.tryUpdate(app, (this_, cx) -> this_.editJson(this_.jsonState.value(), window, cx));
        });
        rustModel.onDidChangeContent(_ -> {
            if (rustState.settingValue) {
                return;
            }
            entity.tryUpdate(app, (this_, cx) -> this_.editRust(this_.rustState.value(), window, cx));
        });
    }

    /** Model options with `size` spaces per indentation level, no detection. */
    static function modelOptions(size:Int):cityscape.common.Model.ITextModelCreationOptions {
        final options = Reflect.copy(TextModel.DEFAULT_CREATION_OPTIONS);
        options.tabSize = size;
        options.indentSize = size;
        options.insertSpaces = true;
        options.detectIndentation = false;
        return options;
    }

    /** The bundled Rust and JSON grammars, once the kit's highlighter is enabled. */
    function registerGrammars():Void {
        if (grammarsRegistered || !Highlighter.enabled) {
            return;
        }
        final rust = KitGrammars.register(context, 'rust');
        final json = KitGrammars.register(context, 'json');
        grammarsRegistered = rust && json;
    }

    public function updateInspectedElement(inspectorId:InspectorElementId, state:DivInspectorState, window:Window, cx:Context<DivInspector>):Void {
        // Skip updating if the inspector ID hasn't changed
        if (inspectorId.equals(this.inspectorId)) {
            return;
        }

        final initialStyle = state.baseStyle;
        this.initialStyle = initialStyle.clone();
        jsonState.editing = false;
        updateJsonFromStyle(initialStyle, window, cx);
        rustState.editing = false;
        final rustStyle = updateRustFromStyle(initialStyle, window, cx);
        unconvertibleStyle = initialStyle.subtract(rustStyle);
        this.inspectorId = inspectorId;
        this.inspectorState = state;
        cx.notify();
    }

    function editJson(code:String, window:Window, cx:Context<DivInspector>):Void {
        if (!jsonState.editing) {
            jsonState.editing = true;
            return;
        }

        try {
            final newStyle = StyleJson.fromJson(code);
            jsonState.error = null;
            rustState.error = null;
            rustState.editing = false;
            final rustStyle = updateRustFromStyle(newStyle, window, cx);
            unconvertibleStyle = newStyle.subtract(rustStyle);
            updateElementStyle(newStyle, window, cx);
        }
        catch (e:SerdeError) {
            jsonState.error = StringTools.rtrim(e.toString());
            window.refresh();
        }
    }

    function editRust(code:String, window:Window, cx:Context<DivInspector>):Void {
        if (!rustState.editing) {
            rustState.editing = true;
            return;
        }

        final result = Inspector.rustToStyle(unconvertibleStyle.clone(), code);
        // The parse errors as markers of the Rust editor (gpui-kit sets them
        // as the diagnostics of its editor)
        Cityscape.setModelMarkers(rustState.model, MARKER_OWNER, [
            for (diagnostic in result.diagnostics) {
                severity: markerSeverity(diagnostic.severity),
                message: diagnostic.message,
                startLineNumber: diagnostic.range.start.line + 1,
                startColumn: diagnostic.range.start.character + 1,
                endLineNumber: diagnostic.range.end.line + 1,
                endColumn: diagnostic.range.end.character + 1
            }
        ]);
        jsonState.error = null;
        jsonState.editing = false;
        updateJsonFromStyle(result.style, window, cx);
        updateElementStyle(result.style, window, cx);
        cx.notify();
    }

    static function markerSeverity(severity:DiagnosticSeverity):MarkerSeverity {
        return switch severity {
            case Error: MarkerSeverity.Error;
            case Warning: MarkerSeverity.Warning;
            case Info: MarkerSeverity.Info;
            case Hint: MarkerSeverity.Hint;
        }
    }

    function updateElementStyle(style:StyleRefinement, window:Window, cx:Context<DivInspector>):Void {
        window.withInspectorState(inspectorId, DivInspectorState, cx.app, (state, _window) -> {
            if (state.value != null) {
                state.value.baseStyle = style;
            }
            return null;
        });
        window.refresh();
    }

    function resetStyle(window:Window, cx:Context<DivInspector>):Void {
        rustState.editing = false;
        final rustStyle = updateRustFromStyle(initialStyle, window, cx);
        unconvertibleStyle = initialStyle.subtract(rustStyle);
        jsonState.editing = false;
        updateJsonFromStyle(initialStyle, window, cx);
        if (inspectorState != null) {
            inspectorState.baseStyle = initialStyle.clone();
        }
    }

    function updateJsonFromStyle(style:StyleRefinement, window:Window, cx:Context<DivInspector>):Void {
        jsonState.setValue(Inspector.styleToJson(style));
        cx.notify();
    }

    function updateRustFromStyle(style:StyleRefinement, window:Window, cx:Context<DivInspector>):StyleRefinement {
        final result = Inspector.styleToRust(style);
        rustState.setValue(result.code);
        cx.notify();
        return result.style;
    }

    /** Rust `Display` of a `Point<Pixels>` */
    static function pointDisplay(point:glaze.Point):String {
        return '(' + StyleJson.absoluteDisplay(Pixels(point.x)) + ', ' + StyleJson.absoluteDisplay(Pixels(point.y)) + ')';
    }

    /** Rust `Display` of a `Size<Pixels>` */
    static function sizeDisplay(size:glaze.Size):String {
        return StyleJson.absoluteDisplay(Pixels(size.width)) + ' × ' + StyleJson.absoluteDisplay(Pixels(size.height));
    }

    /** The options of both editors: gpui-kit's code editor look. */
    static function editorOptions(theme:Theme):IEditorOptions {
        return {
            fontFamily: theme.monoFontFamily,
            fontSize: theme.monoFontSize,
            lineHeight: LINE_HEIGHT,
            fontLigatures: true,
            lineNumbers: 'off',
            glyphMargin: false,
            folding: false,
            lineDecorationsWidth: TEXT_LEFT,
            lineNumbersMinChars: 0,
            padding: {top: PADDING_Y, bottom: PADDING_Y},
            // gpui-kit's code editor scrolls past its last line by max(half
            // the viewport, 3 lines), the viewport without its padding
            // (element.rs `empty_bottom_height`), and its scrollbar measures
            // the thumb without the padding (Cityscape additions)
            scrollBeyondLastLine: true,
            scrollBeyondLastLineGap: {viewportFraction: 0.5, minLines: 3},
            scrollbarThumbExcludesPadding: true,
            // gpui-kit's scrollbar lies over the text: no track (Cityscape's
            // opaque track by default)
            scrollbar: {trackColor: 'transparent'},
            renderLineHighlight: 'none',
            guides: {indentation: true, highlightActiveIndentation: false, bracketPairs: false},
            matchBrackets: 'never',
            occurrencesHighlight: 'off',
            selectionHighlight: false,
            stickyScroll: {enabled: false},
            bracketPairColorization: {enabled: false},
            overviewRulerLanes: 0,
            overviewRulerBorder: false,
            hideCursorInOverviewRuler: true,
            cursorWidth: 1,
            wordWrap: 'off',
            renderWhitespace: 'none',
            links: false,
            colorDecorators: false
        };
    }

    /**
     * A Cityscape editor in gpui-kit's editor frame: the kit's editor
     * background, the input border and radius, the full height of its
     * column (Rust `Editor::new(state).h(relative(1.))`).
     */
    function editorFrame(key:String, model:ITextModel, theme:Theme, options:IEditorOptions):IntoElement {
        return div()
            .flex()
            .sizeFull()
            .h(relative(1.))
            .relative()
            .bg(KitTheme.editorBackground(theme))
            .rounded(theme.radius)
            .border1()
            .borderColor(theme.input)
            .child(
                CityscapeEditor.component()
                    .at(key)
                    .onCreate(editor -> {
                        editors.set(key, editor);
                        (key == 'rust-editor' ? rustState : jsonState).editor = editor;
                    })
                    .model(model)
                    .context(context)
                    .options(options)
                    .sizeFull()
            );
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final cx:Context<DivInspector> = cast cx;
        registerGrammars();
        KitTheme.apply(context, theme, true);
        final state = inspectorState;
        final root = vFlex().sizeFull().gapY4().textSm();
        if (state == null) {
            return root;
        }
        // The same options object while the font does not change: a new
        // one would make the editors apply their options again at each render
        final fontKey = theme.monoFontFamily + '|' + theme.monoFontSize;
        if (options == null || fontKey != optionsFontKey) {
            options = editorOptions(theme);
            optionsFontKey = fontKey;
        }
        final options = this.options;
        final rustEditor = vFlex()
            .flex1()
            .gapY1()
            .fontFamily(theme.monoFontFamily)
            .textSize(theme.monoFontSize)
            .child(editorFrame('rust-editor', rustState.model, theme, options));
        if (rustState.error != null) {
            rustEditor.child(Alert.error('rust-error', rustState.error).textXs());
        }
        final jsonEditor = vFlex()
            .flex1()
            .gapY1()
            .fontFamily(theme.monoFontFamily)
            .textSize(theme.monoFontSize)
            .child(editorFrame('json-editor', jsonState.model, theme, options));
        if (jsonState.error != null) {
            jsonEditor.child(Alert.error('json-error', jsonState.error).textXs());
        }
        return root
            .child(
                DescriptionList.component()
                    .columns(1)
                    .labelWidth(px(110.))
                    .bordered(false)
                    .item('Origin', pointDisplay(state.bounds.origin), 1)
                    .item('Size', sizeDisplay(state.bounds.size), 1)
                    .item('Content Size', sizeDisplay(state.contentSize), 1)
            )
            .child(
                vFlex()
                    .flex1()
                    .h2_5()
                    .gapY3()
                    .child(
                        hFlex()
                            .justifyBetween()
                            .gapX2()
                            .child('Rust Styles')
                            .child(Button.component('rust-reset').label('Reset').small().onClick(
                                cx.listener((this_:DivInspector, _, window:Window, cx:Context<DivInspector>) -> {
                                    this_.resetStyle(window, cx);
                                })
                            ))
                    )
                    .child(rustEditor)
            )
            .child(
                vFlex()
                    .flex1()
                    .gapY3()
                    .h2_5()
                    .flexShrink0()
                    .child(
                        hFlex()
                            .gapX2()
                            .child(div().flex1().child('JSON Styles'))
                            .child(Button.component('json-reset').label('Reset').small().onClick(
                                cx.listener((this_:DivInspector, _, window:Window, cx:Context<DivInspector>) -> {
                                    this_.resetStyle(window, cx);
                                })
                            ))
                    )
                    .child(jsonEditor)
            );
    }

}

/**
 * Completes the style methods after a `.` in the Rust editor (Rust
 * `LspProvider`, as a Cityscape completion provider): the items of
 * `Inspector.styleMethodCompletions`, each replacing the dot and the typed
 * prefix with `.name()`.
 */
class InspectorCompletionProvider implements CompletionItemProvider {

    public var _debugDisplayName(default, null):Null<String> = 'inspector';

    /** Rust `is_completion_trigger` returns true for every character: Monaco's quick suggestions ask while typing, the dot asks too. */
    public var triggerCharacters(default, null):Null<Array<String>> = ['.'];

    public var resolveCompletionItem(default, null):Null<(item:CompletionItem, token:CancellationToken, resolve:(item:Null<CompletionItem>) -> Void) -> Void> = null;

    public function new() {}

    public function provideCompletionItems(model:ITextModel, position:Position, context:CompletionContext, token:CancellationToken,
            resolve:(list:Null<CompletionList>) -> Void):Void {
        final text = model.getValue();
        final offset = model.getOffsetAt(position);
        final completions = Inspector.styleMethodCompletions(text, offset);
        if (completions == null) {
            resolve({suggestions: []});
            return;
        }
        final start = model.getPositionAt(completions.start);
        final range = new CityscapeRange(start.lineNumber, start.column, position.lineNumber, position.column);
        resolve({
            suggestions: [
                for (method in completions.methods) {
                    label: method.name,
                    kind: CompletionItemKind.Method,
                    detail: '()',
                    documentation: method.documentation,
                    filterText: '.' + method.name,
                    insertText: '.' + method.name + '()',
                    range: range
                }
            ]
        });
    }

}
#end
