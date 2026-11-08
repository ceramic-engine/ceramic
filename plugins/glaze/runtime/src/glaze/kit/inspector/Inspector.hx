// Ported from gpui-kit 0.8.1: crates/component/src/inspector.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.inspector;

import glaze.App;
import glaze.ElementId;
import glaze.GlobalElementId;
import glaze.StyleRefinement;
import glaze.kit.base.input.CompletionContext;
import glaze.kit.base.input.CompletionItem;
import glaze.kit.base.input.CompletionProvider.CompletionProviderBase;
import glaze.kit.base.input.CompletionTextEdit;
import glaze.kit.base.input.Diagnostic;
import glaze.kit.base.input.DiagnosticSeverity;
import glaze.kit.base.input.LspPosition;
import glaze.kit.base.input.LspRange;
import glaze.kit.base.input.LspTextEdit;
import glaze.Task;
import glaze.Window;
import ropey.Rope;

using glaze.StyleRefinementOps;
using glaze.kit.base.input.RopeExt;

#if glaze_inspector
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
import glaze.Subscription;
import glaze.kit.base.input.EditorState;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputEvent;
import glaze.kit.base.input.TabSize;
import glaze.kit.IconName;
import glaze.kit.TitleBar;
import glaze.kit.alert.Alert;
import glaze.kit.button.Button;
import glaze.kit.clipboard.Clipboard;
import glaze.kit.descriptionlist.DescriptionList;
import glaze.kit.input.Editor;
import glaze.kit.link.Link;
import glaze.kit.theme.Theme;
import glaze.kit.inspector.SerdeJson.SerdeError;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;
using glaze.kit.base.input.InputIndentExt;
#end

/**
 * gpui-kit's element inspector (`inspector.rs`).
 *
 * The data side is always available: the reflected style methods
 * (`InspectorStyleMethods`), `rustToStyle` (Rust builder calls to a style,
 * with diagnostics), `styleToRust` and `styleToJson`, and the completion
 * provider of the Rust editor (`InspectorCompletionProvider`).
 *
 * The panel needs GPUI's inspector (define `glaze_inspector`, Rust feature
 * `inspector`): `Inspector.init` (called by `Kit.init`) binds
 * `ToggleInspector` (cmd-alt-i on macOS, ctrl-shift-i elsewhere), registers
 * `DivInspector` for `DivInspectorState` and sets `renderInspector` as the
 * renderer of GPUI's inspector panel.
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
                            Link.component('source-location')
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
 * An editor of the inspector panel, with its parse error.
 */
private class InspectorEditor {

    /** The input state for the editor. */
    public final state:Entity<EditorState>;

    /** Error to display from parsing the input, or if serialization errors somehow occur. */
    public var error:Null<String> = null;

    /** Whether the editor is currently being edited. */
    public var editing:Bool = false;

    public function new(state:Entity<EditorState>) {
        this.state = state;
    }

}

/**
 * The inspector of a `Div` (an element whose state is a `DivInspectorState`):
 * its bounds and its base style, editable as Rust builder calls and as JSON.
 */
class DivInspector extends Model implements Render {

    var inspectorId:Null<InspectorElementId> = null;

    var inspectorState:Null<DivInspectorState> = null;

    final rustState:InspectorEditor;

    final jsonState:InspectorEditor;

    /** Initial style before any edits */
    var initialStyle:StyleRefinement = new StyleRefinement();

    /** Part of the initial style that could not be converted to Rust code */
    var unconvertibleStyle:StyleRefinement = new StyleRefinement();

    final subscriptions:Array<Subscription>;

    public function new(window:Window, cx:Context<DivInspector>) {
        super();
        final lspProvider = new InspectorCompletionProvider();

        final jsonInputState = cx.newEntity((ecx:Context<EditorState>) -> new EditorState(window, ecx)
            .language('json')
            .lineNumber(false));

        final rustInputState = cx.newEntity((ecx:Context<EditorState>) -> (cast new EditorState(window, ecx)
            .language('rust')
            .lineNumber(false)
            .tabSize(new TabSize(4, false)) : EditorState));
        rustInputState.update(cx, (state, scx) -> {
            state.lsp().completionProvider = lspProvider;
            scx.notify();
            return null;
        });

        subscriptions = [
            cx.subscribeIn((cast jsonInputState : Entity<InputBaseState>), InputEvent, window, (this_:DivInspector, state, event, window, cx) -> {
                switch event {
                    case Change:
                        final newStyle = (state : InputBaseState).value();
                        this_.editJson(newStyle, window, cx);
                    case _:
                }
            }),
            cx.subscribeIn((cast rustInputState : Entity<InputBaseState>), InputEvent, window, (this_:DivInspector, state, event, window, cx) -> {
                switch event {
                    case Change:
                        final newStyle = (state : InputBaseState).value();
                        this_.editRust(newStyle, window, cx);
                    case _:
                }
            })
        ];

        rustState = new InspectorEditor(rustInputState);
        jsonState = new InspectorEditor(jsonInputState);
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
        rustState.state.update(cx, (state, scx) -> {
            final set = state.diagnosticsMut();
            if (set != null) {
                set.clear();
                set.extend(result.diagnostics);
            }
            scx.notify();
            return null;
        });
        jsonState.error = null;
        jsonState.editing = false;
        updateJsonFromStyle(result.style, window, cx);
        updateElementStyle(result.style, window, cx);
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
        jsonState.state.update(cx, (state, scx) -> {
            state.setValue(Inspector.styleToJson(style), window, cast scx);
            return null;
        });
    }

    function updateRustFromStyle(style:StyleRefinement, window:Window, cx:Context<DivInspector>):StyleRefinement {
        return rustState.state.update(cx, (state, scx) -> {
            final result = Inspector.styleToRust(style);
            state.setValue(result.code, window, cast scx);
            return result.style;
        });
    }

    /** Rust `Display` of a `Point<Pixels>` */
    static function pointDisplay(point:glaze.Point):String {
        return '(' + StyleJson.absoluteDisplay(Pixels(point.x)) + ', ' + StyleJson.absoluteDisplay(Pixels(point.y)) + ')';
    }

    /** Rust `Display` of a `Size<Pixels>` */
    static function sizeDisplay(size:glaze.Size):String {
        return StyleJson.absoluteDisplay(Pixels(size.width)) + ' × ' + StyleJson.absoluteDisplay(Pixels(size.height));
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final cx:Context<DivInspector> = cast cx;
        final state = inspectorState;
        final root = vFlex().sizeFull().gapY4().textSm();
        if (state == null) {
            return root;
        }
        final rustEditor = vFlex()
            .flex1()
            .gapY1()
            .fontFamily(theme.monoFontFamily)
            .textSize(theme.monoFontSize)
            .child(Editor.component(rustState.state).h(relative(1.)));
        if (rustState.error != null) {
            rustEditor.child(Alert.error('rust-error', rustState.error).textXs());
        }
        final jsonEditor = vFlex()
            .flex1()
            .gapY1()
            .fontFamily(theme.monoFontFamily)
            .textSize(theme.monoFontSize)
            .child(Editor.component(jsonState.state).h(relative(1.)));
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
#end

/**
 * Completes the style methods after a `.` in the Rust editor (Rust
 * `LspProvider`). Rust lists them in the iteration order of a `HashMap`
 * (random); the port lists them in table order.
 */
class InspectorCompletionProvider extends CompletionProviderBase {

    /** LSP `CompletionItemKind::METHOD` */
    static inline final METHOD = 2;

    public function new() {}

    public function completions(rope:Rope, offset:Int, _:CompletionContext, _:Window, cx:App):Task<Array<CompletionItem>> {
        var leftOffset = 0;
        while (leftOffset < 100) {
            final c = rope.charAt(offset - leftOffset > 0 ? offset - leftOffset : 0);
            if (c == '.'.code) {
                break;
            }
            if (c == null) {
                break;
            }
            leftOffset++;
        }
        final start = offset - leftOffset > 0 ? offset - leftOffset : 0;
        final triggerCharacter = rope.slice(start, offset).toString();
        if (!StringTools.startsWith(triggerCharacter, '.')) {
            return Task.ready([]);
        }

        final startPos = rope.offsetToPosition(start);
        final endPos = rope.offsetToPosition(offset);

        return cx.backgroundExecutor().spawn(() -> {
            final methods = InspectorStyleMethods.get();
            final prefix = triggerCharacter.substr(1);
            final styles:Array<CompletionItem> = [];
            for (name in methods.names) {
                if (StringTools.startsWith(name, prefix)) {
                    final method = methods.map.get(name);
                    styles.push(new CompletionItem(name, METHOD, '()', method.documentation, null, prefix, null,
                        CompletionTextEdit.Edit(new LspTextEdit(new LspRange(startPos, endPos), '.$name()'))));
                }
            }
            return styles;
        });
    }

    public function isCompletionTrigger(_:Int, _:String, _:App):Bool {
        return true;
    }

}
