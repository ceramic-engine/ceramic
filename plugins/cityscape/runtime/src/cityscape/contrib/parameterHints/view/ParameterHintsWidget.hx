// Ported from vscode src/vs/editor/contrib/parameterHints/browser/parameterHintsWidget.ts
// (its DOM and parameterHints.css replaced by the Glaze view
// `ParameterHintsView`)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.parameterHints.view;

import cityscape.base.common.HtmlContent.IMarkdownString;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.RegExp;
import cityscape.base.common.Strings;
import cityscape.common.Languages.ParameterInformation;
import cityscape.common.Languages.SignatureHelp;
import cityscape.common.Languages.SignatureInformation;
import cityscape.common.config.EditorOptions;
import cityscape.contrib.hover.view.MarkdownRenderer;
import cityscape.contrib.parameterHints.view.ProvideSignatureHelp;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.view.ContentWidgetPositioner;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorWidgets;
import glaze.App;
import glaze.Bounds;
import glaze.Context;
import glaze.Empty;
import glaze.Entity;
import glaze.HighlightStyle;
import glaze.HighlightStyle.TextHighlight;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Model;
import glaze.MouseButton;
import glaze.Render;
import glaze.StyledText;
import glaze.Window;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.scroll.Scrollable.ScrollableElement;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;

/**
 * The documentation of a signature or a parameter: a plain string or
 * markdown (null for none).
 */
enum ParameterHintsDoc {
    Plain(text:String);
    Markdown(markdown:IMarkdownString);
}

/**
 * What the widget shows for a signature help (computed like Monaco's
 * `render`): the label of the active signature and the range of its
 * active parameter, the documentations, the overload counter.
 */
class ParameterHintsContent {

    /** More than one signature (Monaco's `multiple` class). */
    public final multiple:Bool;
    /** The label of the active signature (null when there is none). */
    public final label:Null<String>;
    /** Whether the signature has parameters (the active one is highlighted). */
    public final hasParameters:Bool;
    /** The range of the active parameter in `label` (UTF-16 offsets, `[0, 0]` for none). */
    public final activeStart:Int;
    public final activeEnd:Int;
    /** The documentation of the active parameter. */
    public final parameterDocumentation:Null<ParameterHintsDoc>;
    /** The documentation of the signature. */
    public final signatureDocumentation:Null<ParameterHintsDoc>;
    /** Monaco's `has-docs` (the line under the signature, the docs shown). */
    public final hasDocs:Bool;
    /** The overload counter (`1/3`, the index padded like the count). */
    public final overloads:String;

    public function new(multiple:Bool, label:Null<String>, hasParameters:Bool, activeStart:Int, activeEnd:Int, parameterDocumentation:Null<ParameterHintsDoc>, signatureDocumentation:Null<ParameterHintsDoc>, hasDocs:Bool, overloads:String) {
        this.multiple = multiple;
        this.label = label;
        this.hasParameters = hasParameters;
        this.activeStart = activeStart;
        this.activeEnd = activeEnd;
        this.parameterDocumentation = parameterDocumentation;
        this.signatureDocumentation = signatureDocumentation;
        this.hasDocs = hasDocs;
        this.overloads = overloads;
    }

    /** The text before the active parameter. */
    public function before():String {
        return label != null ? label.substring(0, activeStart) : '';
    }

    /** The active parameter. */
    public function active():String {
        return label != null ? label.substring(activeStart, activeEnd) : '';
    }

    /** The text after the active parameter. */
    public function after():String {
        return label != null ? label.substring(activeEnd) : '';
    }

}

/**
 * The parameter hints on screen (Monaco's `ParameterHintsWidget`, a content
 * widget above the cursor, else below it): its state for the controller,
 * its Glaze view `ParameterHintsView` placed by `ContentWidgetPositioner`
 * (an overlay widget with a null position). The aria announcements and
 * the telemetry of the markdown rendering are not ported.
 */
class ParameterHintsWidget extends Disposable {

    static inline final ID = 'editor.widget.parameterHintsWidget';

    final editor:ICodeEditor;
    final model:ParameterHintsModel;
    final keyVisible:IContextKey<Bool>;
    final keyMultipleSignatures:IContextKey<Bool>;

    var created = false;
    var visible:Bool = false;
    var hints:Null<SignatureHelp> = null;
    final overlay:ParameterHintsOverlay;

    /** The window bounds of the widget, from its last layout. */
    public var bounds(default, null):Null<Bounds> = null;

    /** The side the widget took at its last layout, null before. */
    public var positionPreference(default, null):Null<ContentWidgetPositionPreference> = null;

    // Editor.IContentWidget.allowEditorOverflow
    public final allowEditorOverflow = true;

    public function new(editor:ICodeEditor, model:ParameterHintsModel) {
        super();
        this.editor = editor;
        this.model = model;
        this.keyVisible = ParameterHintsContext.Visible.bindTo(editor.contextKeyService);
        this.keyMultipleSignatures = ParameterHintsContext.MultipleSignatures.bindTo(editor.contextKeyService);
        this.overlay = new ParameterHintsOverlay(this, editor);
    }

    function createParameterHintDOMNodes():Void {
        this.created = true;

        // editor.addContentWidget(this)
        this.editor.addOverlayWidget(this.overlay);
        this._register(Lifecycle.toDisposable(() -> this.editor.removeOverlayWidget(this.overlay)));
        this.hide();

        this._register(this.editor.onDidChangeCursorSelection(e -> {
            if (this.visible) {
                this.layout();
            }
        }));

        // the widget follows its position (Monaco's content widgets are
        // laid out by the view at every render)
        this._register(this.editor.onDidScrollChange(e -> {
            if (this.visible) {
                this.layout();
            }
        }));

        this._register(this.editor.onDidChangeConfiguration(e -> {
            if (e.hasChanged(EditorOption.fontInfo)) {
                this.layout();
            }
        }));

        this._register(this.editor.onDidLayoutChange(e -> this.updateMaxHeight()));
        this.updateMaxHeight();
    }

    public function show():Void {
        if (this.visible) {
            return;
        }

        if (!this.created) {
            this.createParameterHintDOMNodes();
        }

        this.keyVisible.set(true);
        this.visible = true;
        this.layout();
    }

    public function hide():Void {
        if (!this.visible) {
            return;
        }

        this.keyVisible.reset();
        this.visible = false;
        this.bounds = null;
        this.positionPreference = null;
        this.layout();
    }

    public var isVisible(get, never):Bool;
    function get_isVisible():Bool {
        return this.visible;
    }

    public function render(hints:SignatureHelp):Void {
        if (!this.created) {
            return;
        }

        final multiple = hints.signatures.length > 1;
        this.keyMultipleSignatures.set(multiple);

        this.hints = hints;
        this.layout();
    }

    /**
     * The content of the widget for `hints` (Monaco's `render`, without
     * the DOM).
     */
    public static function content(hints:SignatureHelp):ParameterHintsContent {
        final multiple = hints.signatures.length > 1;
        final overloads = StringTools.lpad(Std.string(hints.activeSignature + 1), '0', Std.string(hints.signatures.length).length) + '/' + hints.signatures.length;

        final signature = hints.activeSignature >= 0 && hints.activeSignature < hints.signatures.length ? hints.signatures[hints.activeSignature] : null;
        if (signature == null) {
            return new ParameterHintsContent(multiple, null, false, 0, 0, null, null, false, overloads);
        }

        final hasParameters = signature.parameters.length > 0;
        final activeParameterIndex:Int = signature.activeParameter != null ? signature.activeParameter : hints.activeParameter;

        var start = 0;
        var end = 0;
        if (hasParameters) {
            final offsets = getParameterLabelOffsets(signature, activeParameterIndex);
            start = offsets[0];
            end = offsets[1];
        }

        final activeParameter:Null<ParameterInformation> = activeParameterIndex >= 0 && activeParameterIndex < signature.parameters.length ? signature.parameters[activeParameterIndex] : null;
        final parameterDocumentation = activeParameter != null ? toDoc(activeParameter.documentation) : null;
        final signatureDocumentation = toDoc(signature.documentation);

        return new ParameterHintsContent(multiple, signature.label, hasParameters, start, end, parameterDocumentation, signatureDocumentation, hasDocs(signature, activeParameter), overloads);
    }

    static function toDoc(documentation:Any):Null<ParameterHintsDoc> {
        if (documentation == null) {
            return null;
        }
        if (JsValues.isString(documentation)) {
            final text:String = documentation;
            // `if (activeParameter?.documentation)`: an empty string shows nothing
            return Plain(text);
        }
        return Markdown(documentation);
    }

    static function hasDocs(signature:SignatureInformation, activeParameter:Null<ParameterInformation>):Bool {
        if (activeParameter != null && activeParameter.documentation != null) {
            final doc:Any = activeParameter.documentation;
            if (JsValues.isString(doc)) {
                if ((doc : String).length > 0) {
                    return true;
                }
            }
            else if ((doc : IMarkdownString).value.length > 0) {
                return true;
            }
        }
        if (signature.documentation != null) {
            final doc:Any = signature.documentation;
            if (JsValues.isString(doc)) {
                if ((doc : String).length > 0) {
                    return true;
                }
            }
            else if ((doc : IMarkdownString).value.length > 0) {
                return true;
            }
        }
        return false;
    }

    /**
     * The range of a parameter in the label of its signature (UTF-16
     * offsets): its label offsets, or where its label string is found as a
     * whole word; `[0, 0]` when there is none.
     */
    public static function getParameterLabelOffsets(signature:SignatureInformation, paramIdx:Int):Array<Int> {
        final param:Null<ParameterInformation> = paramIdx >= 0 && paramIdx < signature.parameters.length ? signature.parameters[paramIdx] : null;
        if (param == null) {
            return [0, 0];
        }
        else if (Std.isOfType(param.label, Array)) {
            final offsets:Array<Int> = param.label;
            return [offsets[0], offsets[1]];
        }
        final label:String = param.label;
        if (label.length == 0) {
            return [0, 0];
        }
        else {
            final regex = new RegExp('(\\W|^)' + Strings.escapeRegExpCharacters(label) + '(?=\\W|$)', 'g');
            regex.test(signature.label);
            final idx = regex.lastIndex - label.length;
            return idx >= 0
                ? [idx, regex.lastIndex]
                : [0, 0];
        }
    }

    public function next():Void {
        this.editor.focus();
        this.model.next();
    }

    public function previous():Void {
        this.editor.focus();
        this.model.previous();
    }

    public function getId():String {
        return ParameterHintsWidget.ID;
    }

    /**
     * The maximum height (Monaco's `updateMaxHeight`): a quarter of the
     * editor's height, at least 250 pixels.
     */
    public var maxHeight(default, null):Float = 250;

    function updateMaxHeight():Void {
        this.maxHeight = Math.max(this.editor.getLayoutInfo().height / 4, 250);
        if (this.visible) {
            this.layout();
        }
    }

    /** What the widget shows (null when hidden). */
    public function getContent():Null<ParameterHintsContent> {
        return this.visible && this.hints != null ? content(this.hints) : null;
    }

    /** The signature help shown (null when hidden). */
    public function getHints():Null<SignatureHelp> {
        return this.visible ? this.hints : null;
    }

    /** `editor.layoutContentWidget(this)`: renders the view again. */
    function layout():Void {
        this.overlay.changed();
    }

    @:allow(cityscape.contrib.parameterHints.view)
    function setPlacement(placement:ContentWidgetPlacement):Void {
        this.bounds = placement.bounds;
        this.positionPreference = placement.preference;
    }

}

/**
 * The overlay widget of the parameter hints (Monaco's content widget, its
 * DOM node replaced by the Glaze view `ParameterHintsView`, which places
 * itself).
 */
class ParameterHintsOverlay implements IOverlayWidget {

    final widget:ParameterHintsWidget;
    final editor:ICodeEditor;
    var _view:Null<Entity<ParameterHintsView>> = null;
    var _app:Null<App> = null;

    public function new(widget:ParameterHintsWidget, editor:ICodeEditor) {
        this.widget = widget;
        this.editor = editor;
    }

    public function getId():String {
        return widget.getId();
    }

    public function getPosition():Null<IOverlayWidgetPosition> {
        return null;
    }

    public function changed():Void {
        final v = _view;
        final app = _app;
        if (v != null && app != null) {
            app.notify(v.entityId());
        }
        else {
            editor.layoutOverlayWidget(this);
        }
    }

    public function render(window:Window, cx:App):Null<IntoElement> {
        var v = _view;
        if (v == null) {
            _app = cx;
            v = cityscape.base.common.DebugCounters.trackEntity(cx.newEntity((c:Context<ParameterHintsView>) -> new ParameterHintsView(widget, editor)), cx);
            _view = v;
        }
        return v;
    }

}

/**
 * The Glaze view of the parameter hints (Monaco's DOM of
 * parameterHintsWidget.ts styled by parameterHints.css): the colors of
 * the hover (`editorHoverWidget.background`, `.foreground`, `.border`),
 * the editor's font size and line height; on the left, when there are
 * several signatures, the controls (the up and down chevrons around the
 * overload counter `1/3` in `--monaco-monospace-font`, 12 pixels high) and
 * a line of `editorHoverWidget.border` at 50%; the signature in the editor's
 * font (4 and 5 pixels of padding), its active parameter in bold and
 * `editorHoverWidget.highlightForeground`; under a line of the border color
 * at 50%, the documentation of the parameter then of the signature
 * (paragraphs with 8 pixel margins, markdown rendered like the hover's);
 * at most 440 pixels wide and `max(the editor's height / 4, 250)` high,
 * scrolling beyond. Placed by `ContentWidgetPositioner` above the cursor,
 * else below (`[ABOVE, BELOW]`).
 */
class ParameterHintsView extends Model implements Render {

    /** parameterHints.css `.phwrapper { max-width: 440px }` */
    public static inline final MAX_WIDTH = 440;

    /** parameterHints.css `p { margin: 8px 0 }` */
    static inline final P_MARGIN = 8;

    final widget:ParameterHintsWidget;
    final editor:ICodeEditor;

    public function new(widget:ParameterHintsWidget, editor:ICodeEditor) {
        super();
        this.widget = widget;
        this.editor = editor;
    }

    static function utf8Offset(s:String, utf16Offset:Int):Int {
        var bytes = 0;
        var i = 0;
        while (i < utf16Offset && i < s.length) {
            final c = StringTools.fastCodeAt(s, i);
            if (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length) {
                bytes += 4;
                i += 2;
            }
            else {
                bytes += c < 0x80 ? 1 : (c < 0x800 ? 2 : 3);
                i++;
            }
        }
        return bytes;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final hints = widget.getHints();
        if (hints == null || !editor.hasModel()) {
            return new Empty();
        }
        final position = editor.getPosition();
        final primary = EditorWidgets.positionBounds(editor, position);
        final editorBounds = EditorWidgets.editorBounds(editor);
        if (primary == null || editorBounds == null || !EditorWidgets.isPositionVisible(editor, position)) {
            // Monaco hides a content widget whose position is out of the viewport
            return new Empty();
        }
        final app:App = cx.app;
        final theme = Theme.global(cx);
        final background = EditorWidgets.color(editor, 'editorHoverWidget.background', EditorWidgets.color(editor, 'editorWidget.background', theme.popover));
        final foreground = EditorWidgets.color(editor, 'editorHoverWidget.foreground', EditorWidgets.color(editor, 'editor.foreground', theme.popoverForeground));
        final border = EditorWidgets.color(editor, 'editorHoverWidget.border', EditorWidgets.color(editor, 'editorWidget.border', theme.border));
        final highlight = EditorWidgets.color(editor, 'editorHoverWidget.highlightForeground', EditorWidgets.color(editor, 'list.highlightForeground', theme.link));
        final fontInfo = editor.getOption(EditorOption.fontInfo);
        final fontSize:Float = fontInfo.fontSize;
        final lineHeight:Float = fontInfo.lineHeight;
        // `overflowWidgetsBounds: 'editor'`: no higher than the room in the editor
        final page = EditorWidgets.overflowPage(editor);
        final maxHeight = page != null ? Math.min(widget.maxHeight, ContentWidgetPositioner.maxHeightInPageWithPreferences(primary, page)) : widget.maxHeight;

        final content = ParameterHintsWidget.content(hints);

        // .signature > .code: the label, the active parameter highlighted
        final signature = div()
            .id('cityscape-parameter-hints-signature')
            .flex()
            .flexCol()
            .px(px(5))
            .py(px(4))
            .minW0();
        if (content.label != null) {
            final label:String = content.label;
            final highlights:Array<TextHighlight> = [];
            if (content.hasParameters && content.activeEnd > content.activeStart) {
                // `.parameter.active`: bold, editorHoverWidget.highlightForeground
                highlights.push(new TextHighlight(utf8Offset(label, content.activeStart), utf8Offset(label, content.activeEnd), new HighlightStyle(highlight, glaze.FontWeight.BOLD)));
            }
            signature.child(div()
                .fontFamily(EditorWidgets.editorFontFamily(editor))
                .child(new StyledText(label).withHighlights(highlights)));
        }
        if (content.hasDocs) {
            // `.signature.has-docs::after`: a line of the border at 50%
            signature.borderB1().borderColor(border.opacity(0.5));
        }

        final body = div()
            .id('cityscape-parameter-hints-body')
            .flex()
            .flexCol()
            .minW0()
            .child(signature);

        if (content.hasDocs) {
            // .docs: 5 pixels on the left, 10 on the right, paragraphs
            // with 8 pixel margins (collapsed between them like CSS)
            final docs = div().id('cityscape-parameter-hints-docs').flex().flexCol().minW0().pl(px(5)).pr(px(10));
            var previousMarginBottom:Null<Float> = null;
            function addPiece(element:IntoElement, marginTop:Float, marginBottom:Float):Void {
                final top = previousMarginBottom == null ? marginTop : MarkdownRenderer.collapseMargins(previousMarginBottom, marginTop);
                docs.child(div().flex().flexCol().minW0().mt(px(top)).child(element));
                previousMarginBottom = marginBottom;
            }
            function addDoc(doc:Null<ParameterHintsDoc>, index:Int, inParagraph:Bool):Void {
                if (doc == null) {
                    return;
                }
                switch doc {
                    case Plain(text):
                        if (text.length > 0 || !inParagraph) {
                            addPiece(div().minW0().child(text), P_MARGIN, P_MARGIN);
                        }
                    case Markdown(markdown):
                        final blocks = MarkdownRenderer.parseHoverMarkdown(markdown, fontSize);
                        if (blocks.length == 0) {
                            if (inParagraph) {
                                addPiece(div(), P_MARGIN, P_MARGIN);
                            }
                            return;
                        }
                        // the margins of the first and last blocks go
                        // outside (collapsed with the paragraph around the
                        // parameter's documentation)
                        var top = blocks[0].marginTop;
                        var bottom = blocks[blocks.length - 1].marginBottom;
                        if (inParagraph) {
                            top = MarkdownRenderer.collapseMargins(P_MARGIN, top);
                            bottom = MarkdownRenderer.collapseMargins(P_MARGIN, bottom);
                        }
                        blocks[0].marginTop = 0;
                        blocks[blocks.length - 1].marginBottom = 0;
                        final rendered = MarkdownRenderer.renderHoverMarkdown(editor, 'cityscape-parameter-hints-doc-' + index, blocks, window, app);
                        // `.markdown-docs` has no padding of its own
                        rendered.px(px(0)).py(px(0));
                        addPiece(rendered, top, bottom);
                }
            }
            // the parameter's documentation in a paragraph, then the signature's
            addDoc(content.parameterDocumentation, 0, true);
            addDoc(content.signatureDocumentation, 1, false);
            if (previousMarginBottom != null) {
                docs.child(div().flexNone().h(px(previousMarginBottom)));
            }
            body.child(docs);
        }

        if (content.multiple) {
            // `.multiple .body::before`: a line of the border at 50% on the left
            body.borderL1().borderColor(border.opacity(0.5));
        }

        // the body scrolls beyond the maximum height (Monaco's
        // DomScrollableElement), inside the 1 pixel border
        final scrollable = ScrollableElement.overflowYScrollbar(body.maxH(px(maxHeight - 2))).id('cityscape-parameter-hints-scroll');

        final wrapper = div()
            .id('cityscape-parameter-hints-wrapper')
            .flex()
            .flexRow()
            .maxW(px(page != null ? Math.min(MAX_WIDTH, Math.max(0, page.size.width - ContentWidgetPositioner.LEFT_PADDING - ContentWidgetPositioner.RIGHT_PADDING)) : MAX_WIDTH))
            .maxH(px(maxHeight - 2));

        if (content.multiple) {
            // .controls: a column at the bottom, at least 22 pixels wide,
            // 2 pixels of padding on the sides
            final iconSize = 16;
            final controls = div()
                .id('cityscape-parameter-hints-controls')
                .flex()
                .flexCol()
                .itemsCenter()
                .justifyEnd()
                .minW(px(22))
                .px(px(2))
                .flexNone()
                .child(div()
                    .id('cityscape-parameter-hints-previous')
                    .w(px(iconSize))
                    .h(px(iconSize))
                    .flexNone()
                    .cursorPointer()
                    .onMouseDown(MouseButton.Left, (_, _, cx) -> {
                        cx.stopPropagation();
                        widget.previous();
                    })
                    .child(new Icon(IconName.ChevronUp).withSize(iconSize).textColor(foreground)))
                .child(div()
                    .id('cityscape-parameter-hints-overloads')
                    .h(px(12))
                    .lineHeight(px(12))
                    .flexNone()
                    .whitespaceNowrap()
                    .fontFamily(EditorWidgets.monospaceFontFamily(editor))
                    .child(content.overloads))
                .child(div()
                    .id('cityscape-parameter-hints-next')
                    .w(px(iconSize))
                    .h(px(iconSize))
                    .flexNone()
                    .cursorPointer()
                    .onMouseDown(MouseButton.Left, (_, _, cx) -> {
                        cx.stopPropagation();
                        widget.next();
                    })
                    .child(new Icon(IconName.ChevronDown).withSize(iconSize).textColor(foreground)));
            wrapper.child(controls);
        }
        wrapper.child(div().flex().flexCol().flex1().minW0().child(scrollable));

        final element = div()
            .id('cityscape-parameter-hints')
            .flex()
            .flexCol()
            .maxH(px(maxHeight))
            .bg(background)
            .textColor(foreground)
            .border1()
            .borderColor(border)
            .textSize(px(fontSize))
            .lineHeight(px(lineHeight))
            .overflowHidden()
            .onMouseDown(MouseButton.Left, (_, _, cx) -> cx.stopPropagation())
            .child(wrapper);
        if (content.multiple) {
            // `.multiple { min-height: 3.3em }`
            element.minH(px(3.3 * fontSize));
        }

        final positioner = new ContentWidgetPositioner({
            primary: primary,
            secondary: null,
            editor: editorBounds,
            typicalFullwidthCharacterWidth: fontInfo.typicalFullwidthCharacterWidth,
            page: page
        }, true)
            .preferences([ContentWidgetPositionPreference.ABOVE, ContentWidgetPositionPreference.BELOW])
            .onPlacement(placement -> widget.setPlacement(placement))
            .child(element);
        // below the suggest widget (parameterHints.css: z-index 39, the suggest widget's is 40)
        return deferred(positioner).withPriority(glaze.kit.base.Popup.POPUP_PRIORITY - 1).intoAnyElement();
    }

}
