// Ported from vscode src/vs/editor/contrib/hover/browser/markerHoverParticipant.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.hover.view;

import cityscape.base.common.Async;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.JsValues;
import cityscape.common.Languages.CodeActionTriggerType;
import cityscape.common.Model.IModelDecoration;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Range;
import cityscape.contrib.codeAction.common.CodeActionTypes;
import cityscape.contrib.codeAction.view.CodeAction;
import cityscape.contrib.codeAction.view.CodeActionController;
import cityscape.contrib.hover.view.HoverTypes;
import cityscape.platform.markers.common.Markers;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorWidgets;
import cityscape.view.SymbolIcons;
import glaze.App;
import glaze.IntoElement;
import glaze.Window;
import glaze.kit.Icon;

import glaze.Prelude.*;

class MarkerHover implements IHoverPart {

    public var owner(default, null):IEditorHoverParticipant;
    public var range(default, null):Range;
    public var forceShowAtRange(default, null):Bool = false;
    public var isBeforeContent(default, null):Bool = false;
    public final marker:IMarker;

    public function new(owner:IEditorHoverParticipant, range:Range, marker:IMarker) {
        this.owner = owner;
        this.range = range;
        this.marker = marker;
    }

    public function isValidForHoverAnchor(anchor:HoverAnchor):Bool {
        return (
            anchor.type == cityscape.contrib.hover.view.HoverAnchorType.Range
            && this.range.startColumn <= anchor.range.startColumn
            && this.range.endColumn >= anchor.range.endColumn
        );
    }
}

/**
 * The markers of the hover (Monaco's `MarkerHoverParticipant`): the
 * message, the source and code, the related information, the severity
 * (shown with its icon and color, the loreline-monaco patch that styles
 * the diagnostics hover by severity), and the status bar actions "View
 * Problem" (go to the marker) and "Quick Fix..." (the quick fixes of the
 * marker, in the code action menu).
 */
class MarkerHoverParticipant implements IEditorHoverParticipant {

    public var hoverOrdinal(default, null):Int = 1;

    public var computeAsync(default, null):Null<(anchor:HoverAnchor, lineDecorations:Array<IModelDecoration>, token:CancellationToken, onItem:(part:IHoverPart) -> Void, onDone:() -> Void) -> Void> = null;

    var recentMarkerCodeActionsInfo:Null<{marker:IMarker, hasCodeActions:Bool}> = null;

    final _editor:ICodeEditor;

    static final markerCodeActionTrigger:CodeActionTrigger = {
        type: CodeActionTriggerType.Invoke,
        filter: {include: CodeActionKind.QuickFix},
        triggerAction: CodeActionTriggerSource.QuickFixHover
    };

    public function new(editor:ICodeEditor) {
        this._editor = editor;
    }

    public function suggestHoverAnchor(mouseEvent:IEditorMouseEvent):Null<HoverAnchor> {
        return null;
    }

    public function createLoadingMessage(anchor:HoverAnchor):Null<IHoverPart> {
        return null;
    }

    public function computeSync(anchor:HoverAnchor, lineDecorations:Array<IModelDecoration>):Array<IHoverPart> {
        if (!this._editor.hasModel() || anchor.type != cityscape.contrib.hover.view.HoverAnchorType.Range && !anchor.supportsMarkerHover) {
            return [];
        }

        final model = this._editor.getModel();
        final lineNumber = anchor.range.startLineNumber;
        final maxColumn = model.getLineMaxColumn(lineNumber);
        final result:Array<IHoverPart> = [];
        for (d in lineDecorations) {
            final startColumn = (d.range.startLineNumber == lineNumber) ? d.range.startColumn : 1;
            final endColumn = (d.range.endLineNumber == lineNumber) ? d.range.endColumn : maxColumn;

            final marker = this._editor.context.markerDecorationsService.getMarker(model.uri, d);
            if (marker == null) {
                continue;
            }

            final range = new Range(anchor.range.startLineNumber, startColumn, anchor.range.startLineNumber, endColumn);
            result.push(new MarkerHover(this, range, marker));
        }

        return result;
    }

    /**
     * The codicon and theme color of a severity.
     */
    public static function severityStyle(editor:ICodeEditor, severity:MarkerSeverity):{codicon:String, color:glaze.Hsla} {
        final dark = EditorWidgets.isDark(editor);
        return switch severity {
            case MarkerSeverity.Error: {codicon: 'error', color: EditorWidgets.color(editor, 'editorError.foreground', dark ? rgb(0xF14C4C).toHsla() : rgb(0xE51400).toHsla())};
            case MarkerSeverity.Warning: {codicon: 'warning', color: EditorWidgets.color(editor, 'editorWarning.foreground', dark ? rgb(0xCCA700).toHsla() : rgb(0xBF8803).toHsla())};
            case _: {codicon: 'info', color: EditorWidgets.color(editor, 'editorInfo.foreground', dark ? rgb(0x3794FF).toHsla() : rgb(0x1A85FF).toHsla())};
        };
    }

    public function renderHoverParts(context:IEditorHoverRenderContext, hoverParts:Array<IHoverPart>, window:Window, cx:App):Array<IntoElement> {
        if (hoverParts.length == 0) {
            return [];
        }
        final result:Array<IntoElement> = [];
        for (hoverPart in hoverParts) {
            result.push(this._renderMarkerHover(cast hoverPart));
        }
        final parts:Array<MarkerHover> = [for (p in hoverParts) cast p];
        if (parts.length > 1) {
            haxe.ds.ArraySort.sort(parts, (a, b) -> MarkerSeverityUtils.compare(a.marker.severity, b.marker.severity));
        }
        this.renderMarkerStatusbar(context, parts[0]);
        return result;
    }

    public function getAccessibleContent(hoverPart:IHoverPart):String {
        return (cast hoverPart : MarkerHover).marker.message;
    }

    function _renderMarkerHover(markerHover:MarkerHover):IntoElement {
        final marker = markerHover.marker;
        final source = marker.source;
        final message = marker.message;
        final code:Any = marker.code;
        final relatedInformation = marker.relatedInformation;

        final style = severityStyle(_editor, marker.severity);
        final fontFamily = EditorWidgets.editorFontFamily(_editor);
        final fontSize = _editor.getOption(EditorOption.fontSize);

        final markerElement = div()
            .flex()
            .flexCol()
            .gap(px(2))
            .fontFamily(fontFamily)
            .textSize(px(fontSize));

        final first = div().flex().flexRow().itemsStart().gap(px(6));
        first.child(div().flexNone().pt(px(2)).child(Icon.empty().data(SymbolIcons.codiconSvg(style.codicon)).withSize(Math.round(fontSize * 1.1)).textColor(style.color)));
        final messageBox = div().flex().flexRow().flexWrap().gap(px(6)).minW0();
        messageBox.child(div().whitespaceNormal().child(message));

        if ((source != null && source.length > 0) || code != null) {
            var details:String;
            // Code has link
            if (code != null && !JsValues.isString(code) && JsValues.isObject(code)) {
                final value:String = JsValues.toJsString(JsValues.field(code, 'value'));
                details = source != null && source.length > 0 ? source + '(' + value + ')' : value;
            }
            else {
                final c:Null<String> = code != null ? JsValues.toJsString(code) : null;
                details = source != null && source.length > 0 && c != null ? source + '(' + c + ')' : (source != null && source.length > 0 ? source : '(' + c + ')');
            }
            messageBox.child(div().opacity(0.6).child(details));
        }
        first.child(messageBox);
        markerElement.child(first);

        if (relatedInformation != null && relatedInformation.length > 0) {
            for (info in relatedInformation) {
                final resource = info.resource;
                final path = resource.path;
                final basename = path.substr(path.lastIndexOf('/') + 1);
                markerElement.child(div().mt(px(8)).flex().flexRow().gap(px(4))
                    .child(div().textColor(EditorWidgets.color(_editor, 'textLink.foreground', rgb(0x3794FF).toHsla())).child(basename + '(' + info.startLineNumber + ', ' + info.startColumn + '): '))
                    .child(info.message));
            }
        }

        return div().px(px(8)).py(px(4)).child(markerElement);
    }

    function renderMarkerStatusbar(context:IEditorHoverRenderContext, markerHover:MarkerHover):Void {
        final severity = markerHover.marker.severity;
        if (severity == MarkerSeverity.Error || severity == MarkerSeverity.Warning || severity == MarkerSeverity.Info) {
            final markerController = cityscape.contrib.gotoError.view.GotoError.MarkerController.get(this._editor);
            final shown = markerController != null ? markerController.getShownMarker() : null;
            if (shown != null && shown.marker == markerHover.marker) {
                // the title of Monaco's marker navigation widget
                context.addStatusBarText(shown.total > 1
                    ? _editor.context.nls.localize('problems', "{0} of {1} problems", [shown.index, shown.total])
                    : _editor.context.nls.localize('change', "{0} of {1} problem", [shown.index, shown.total]));
            }
            if (markerController != null) {
                context.addStatusBarAction(_editor.context.nls.localize('view problem', "View Problem"), cityscape.contrib.gotoError.view.GotoError.NextMarkerAction.ID, () -> {
                    context.hide();
                    markerController.showAtMarker(markerHover.marker);
                    this._editor.focus();
                });
            }
        }

        if (!this._editor.getOption(EditorOption.readOnly)) {
            var setText:Null<(text:Null<String>) -> Void> = null;
            final noQuickFixes = _editor.context.nls.localize('noQuickFixes', "No quick fixes available");
            var initial = ' ';
            if (this.recentMarkerCodeActionsInfo != null) {
                if (makeKey(this.recentMarkerCodeActionsInfo.marker) == makeKey(markerHover.marker)) {
                    if (!this.recentMarkerCodeActionsInfo.hasCodeActions) {
                        initial = noQuickFixes;
                    }
                }
                else {
                    this.recentMarkerCodeActionsInfo = null;
                }
            }
            setText = context.addStatusBarText(initial);
            final checkingTimer = (this.recentMarkerCodeActionsInfo != null && !this.recentMarkerCodeActionsInfo.hasCodeActions) ? null : Async.setTimeout(() -> {
                if (setText != null) {
                    setText(_editor.context.nls.localize('checkingForQuickFixes', "Checking for quick fixes..."));
                }
            }, 200);
            final source = new CancellationTokenSource();
            CodeActionUtils.getCodeActions(
                this._editor.context.languageFeaturesService.codeActionProvider,
                this._editor.getModel(),
                new Range(markerHover.marker.startLineNumber, markerHover.marker.startColumn, markerHover.marker.endLineNumber, markerHover.marker.endColumn),
                markerCodeActionTrigger,
                null,
                source.token
            ).done(actions -> {
                if (checkingTimer != null) {
                    checkingTimer();
                }
                this.recentMarkerCodeActionsInfo = {marker: markerHover.marker, hasCodeActions: actions.validActions.length > 0};

                if (!this.recentMarkerCodeActionsInfo.hasCodeActions) {
                    actions.dispose();
                    setText(noQuickFixes);
                    context.onContentsChanged();
                    return;
                }
                setText(null);

                context.addStatusBarAction(_editor.context.nls.localize('quick fixes', "Quick Fix..."), CodeActionCommandIds.quickFixCommandId, () -> {
                    final controller = CodeActionController.get(this._editor);
                    // Hide the hover pre-emptively, otherwise the editor can close the code actions
                    // context menu as well when using keyboard navigation
                    final at = context.statusBarBounds();
                    context.hide();
                    if (controller != null) {
                        controller.showCodeActions(markerCodeActionTrigger, actions, at);
                    }
                });
                context.onContentsChanged();
            }, e -> Errors.onUnexpectedError(e));
        }
    }

    /**
     * Monaco's `IMarkerData.makeKey`.
     */
    static function makeKey(marker:IMarker):String {
        final result:Array<String> = [''];
        result.push(marker.source != null ? marker.source.split('¦').join('\\¦') : '');
        final code:Any = marker.code;
        if (code != null) {
            if (JsValues.isString(code)) {
                result.push((code : String).split('¦').join('\\¦'));
            }
            else {
                result.push(JsValues.toJsString(JsValues.field(code, 'value')).split('¦').join('\\¦'));
            }
        }
        else {
            result.push('');
        }
        result.push(Std.string((marker.severity : Int)));
        result.push(marker.message != null ? marker.message.split('¦').join('\\¦') : '');
        result.push(Std.string(marker.startLineNumber));
        result.push(Std.string(marker.startColumn));
        result.push(Std.string(marker.endLineNumber));
        result.push(Std.string(marker.endColumn));
        result.push('');
        return result.join('¦');
    }

}
