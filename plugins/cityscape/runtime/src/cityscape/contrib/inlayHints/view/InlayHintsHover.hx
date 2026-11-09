// Ported from vscode src/vs/editor/contrib/inlayHints/browser/inlayHintsHover.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.inlayHints.view;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Errors;
import cityscape.base.common.HtmlContent.IMarkdownString;
import cityscape.base.common.JsValues;
import cityscape.base.common.Platform;
import cityscape.base.common.Uri;
import cityscape.common.Model.IModelDecoration;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.contrib.gotoSymbol.view.GoToCommands.SymbolNavigation;
import cityscape.contrib.hover.view.GetHover;
import cityscape.contrib.hover.view.HoverAnchorType;
import cityscape.contrib.hover.view.HoverTypes;
import cityscape.contrib.hover.view.MarkdownHoverParticipant;
import cityscape.contrib.hover.view.MarkdownRenderer;
import cityscape.contrib.inlayHints.view.InlayHints;
import cityscape.contrib.inlayHints.view.InlayHintsController;
import cityscape.view.EditorBrowser;
import glaze.App;
import glaze.Window;

/**
 * The anchor of the hover of an inlay hint part (Monaco's
 * `HoverForeignElementAnchor` with the part).
 */
class InlayHintsHoverAnchor extends HoverAnchor {

    public final part:RenderedInlayHintLabelPart;

    public function new(part:RenderedInlayHintLabelPart, owner:InlayHintsHover, initialMousePosX:Null<Float>, initialMousePosY:Null<Float>) {
        super(HoverAnchorType.ForeignElement, 10, part.item.anchor.range, initialMousePosX, initialMousePosY, owner, true);
        this.part = part;
    }

}

/**
 * The hover of the inlay hints (Monaco's `InlayHintsHover`): the tooltip of
 * the hint and of the part under the mouse, "Double-click to insert" for a
 * hint with text edits, the "Go to Definition"/"Execute Command" help of a
 * part with a location or a command, and the hovers of the providers at
 * the part's location.
 */
class InlayHintsHover extends MarkdownHoverParticipant {

    public function new(editor:ICodeEditor) {
        super(editor);
        this.hoverOrdinal = 6;
        this.computeAsync = _computeInlayHintsAsync;
    }

    override public function suggestHoverAnchor(mouseEvent:IEditorMouseEvent):Null<HoverAnchor> {
        final controller = InlayHintsController.get(this._editor);
        if (controller == null) {
            return null;
        }
        final part = InlayHintsController.labelPartOf(mouseEvent.target);
        if (part == null) {
            return null;
        }
        return new InlayHintsHoverAnchor(part, this, mouseEvent.event.posx, mouseEvent.event.posy);
    }

    override public function computeSync(anchor:HoverAnchor, lineDecorations:Array<IModelDecoration>):Array<IHoverPart> {
        return [];
    }

    function _computeInlayHintsAsync(anchor:HoverAnchor, lineDecorations:Array<IModelDecoration>, token:CancellationToken, onItem:(part:IHoverPart) -> Void, onDone:() -> Void):Void {
        if (!Std.isOfType(anchor, InlayHintsHoverAnchor)) {
            onDone();
            return;
        }
        final part = (cast anchor : InlayHintsHoverAnchor).part;

        part.item.resolve(token).done(_ -> {

            if (token.isCancellationRequested) {
                onDone();
                return;
            }

            // (1) Inlay Tooltip
            final itemTooltip = InlayHintsHover.tooltipMarkdown(part.item.hint.tooltip);
            if (itemTooltip != null) {
                onItem(new MarkdownHover(this, anchor.range, [itemTooltip], false, 0));
            }
            // (1.2) Inlay dbl-click gesture
            final textEdits = part.item.hint.textEdits;
            if (textEdits != null && textEdits.length > 0) {
                onItem(new MarkdownHover(this, anchor.range, [{value: InlayHintsHover.appendText(this._editor.context.nls.localize('hint.dbl', "Double-click to insert"))}], false, 10001));
            }

            // (2) Inlay Label Part Tooltip
            final labelPart = part.part;
            final partTooltip = InlayHintsHover.tooltipMarkdown(labelPart.tooltip);
            if (partTooltip != null) {
                onItem(new MarkdownHover(this, anchor.range, [partTooltip], false, 1));
            }

            // (2.2) Inlay Label Part Help Hover
            if (labelPart.location != null || labelPart.command != null) {
                var linkHint:Null<IMarkdownString> = null;
                final nls = this._editor.context.nls;
                final useMetaKey = this._editor.getOption(EditorOption.multiCursorModifier) == 'altKey';
                final kb = useMetaKey
                    ? (Platform.isMacintosh
                        ? nls.localize('links.navigate.kb.meta.mac', "cmd + click")
                        : nls.localize('links.navigate.kb.meta', "ctrl + click"))
                    : (Platform.isMacintosh
                        ? nls.localize('links.navigate.kb.alt.mac', "option + click")
                        : nls.localize('links.navigate.kb.alt', "alt + click"));

                if (labelPart.location != null && labelPart.command != null) {
                    linkHint = {value: InlayHintsHover.appendText(nls.localize('hint.defAndCommand', 'Go to Definition ({0}), right click for more', [kb]))};
                } else if (labelPart.location != null) {
                    linkHint = {value: InlayHintsHover.appendText(nls.localize('hint.def', 'Go to Definition ({0})', [kb]))};
                } else if (labelPart.command != null) {
                    linkHint = {
                        value: '[${nls.localize('hint.cmd', "Execute Command")}](${InlayHints.asCommandLink(labelPart.command)} "${labelPart.command.title}") ($kb)',
                        isTrusted: true
                    };
                }
                if (linkHint != null) {
                    onItem(new MarkdownHover(this, anchor.range, [linkHint], false, 10000));
                }
            }

            // (3) Inlay Label Part Location tooltip
            this._resolveInlayHintLabelPartHover(part, token, onItem, onDone);
        }, err -> {
            Errors.onUnexpectedError(err);
            onDone();
        });
    }

    function _resolveInlayHintLabelPartHover(part:RenderedInlayHintLabelPart, token:CancellationToken, onItem:(part:IHoverPart) -> Void, onDone:() -> Void):Void {
        final location = part.part.location;
        if (location == null) {
            onDone();
            return;
        }
        // Monaco resolves the model with its text model service; here a
        // model of the context (the model service or an editor's)
        final model = SymbolNavigation.findModel(this._editor.context, location.uri);
        final registry = this._editor.context.languageFeaturesService.hoverProvider;
        if (model == null || !registry.has(model)) {
            onDone();
            return;
        }
        GetHover.getHoverProviderResults(registry, model, new Position(location.range.startLineNumber, location.range.startColumn), token, item -> {
            if (InlayHintsHover.isEmptyMarkdownContents(item.hover.contents)) {
                return;
            }
            onItem(new MarkdownHover(this, part.item.anchor.range, item.hover.contents, false, 2 + item.ordinal));
        }, onDone);
    }

    /**
     * The markdown of the links: a `command:` link runs its command (Monaco's
     * opener service runs the commands of trusted markdown), other links
     * open like the hover's.
     */
    override function renderMarkdownContents(context:IEditorHoverRenderContext, content:IMarkdownString, id:String, window:Window, cx:App):glaze.Div {
        final fontSize:Float = _editor.getOption(EditorOption.fontInfo).fontSize;
        final blocks = MarkdownRenderer.parseHoverMarkdown(content, fontSize);
        styleBlocks(context, blocks, window, cx);
        return MarkdownRenderer.renderHoverMarkdown(_editor, id, blocks, window, cx, url -> {
            if (!InlayHintsHover.runCommandLink(this._editor, url)) {
                cx.openUrl(url);
            }
        });
    }

    /**
     * Runs the command of a `command:` link (`InlayHints.asCommandLink`):
     * returns false when `url` is not a command link.
     */
    public static function runCommandLink(editor:ICodeEditor, url:String):Bool {
        if (!StringTools.startsWith(url, 'command:')) {
            return false;
        }
        final uri = Uri.parse(url);
        var args:Array<Any> = [];
        if (uri.query != null && uri.query.length > 0) {
            try {
                // Monaco's CommandOpener: `JSON.parse(decodeURIComponent(query))`
                final parsed:Any = haxe.Json.parse(StringTools.urlDecode(uri.query));
                args = JsValues.isArray(parsed) ? parsed : [parsed];
            }
            catch (e:Dynamic) {
                // ignore and retry without arguments
            }
        }
        try {
            editor.context.commandService.executeCommand(uri.path, args);
        }
        catch (err:Dynamic) {
            Errors.onUnexpectedError(err);
        }
        return true;
    }

    /**
     * A tooltip (a string or a markdown string) as markdown: a string is
     * appended as text (Monaco's `new MarkdownString().appendText`).
     */
    static function tooltipMarkdown(tooltip:Any):Null<IMarkdownString> {
        if (tooltip == null) {
            return null;
        }
        if (JsValues.isString(tooltip)) {
            return {value: InlayHintsHover.appendText((tooltip : String))};
        }
        return (tooltip : IMarkdownString);
    }

    static function isEmptyMarkdownContents(contents:Null<Array<IMarkdownString>>):Bool {
        if (contents == null) {
            return true;
        }
        for (c in contents) {
            if (c != null && c.value != null && c.value.length > 0) {
                return false;
            }
        }
        return true;
    }

    /**
     * Monaco's `MarkdownString.appendText` on an empty markdown string (the
     * paragraph newline style): the markdown syntax escaped, spaces and
     * tabs as `&nbsp;`, `>` escaped, a newline as a paragraph break.
     */
    public static function appendText(value:String):String {
        final buf = new StringBuf();
        for (i in 0...value.length) {
            final c = value.charAt(i);
            switch c {
                case '\\' | '`' | '*' | '_' | '{' | '}' | '[' | ']' | '(' | ')' | '#' | '+' | '-' | '!' | '~':
                    buf.add('\\' + c);
                case ' ' | '\t':
                    buf.add('&nbsp;');
                case '>':
                    buf.add('\\>');
                case '\n':
                    buf.add('\n\n');
                case _:
                    buf.add(c);
            }
        }
        return buf.toString();
    }

}
