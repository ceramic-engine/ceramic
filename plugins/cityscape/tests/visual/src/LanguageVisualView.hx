// New code for Cityscape (not a port): the visual check of the language
// features (suggest widget, marker hover with a quick fix).
package;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.languages.CompletionItemKind;
import cityscape.common.model.TextModel;
import cityscape.contrib.hover.view.ContentHoverController;
import cityscape.contrib.hover.view.HoverOperation;
import cityscape.contrib.suggest.view.SuggestController;
import cityscape.platform.markers.common.Markers;
import cityscape.view.CityscapeView;
import glaze.App;
import glaze.Context;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;

import glaze.Prelude.*;

/**
 * Completions of the members of `Item` (the scene's own provider).
 */
private class MembersCompletionProvider implements CompletionItemProvider {

    public var _debugDisplayName(default, null):Null<String> = 'visual';
    public var triggerCharacters(default, null):Null<Array<String>> = ['.'];
    public var resolveCompletionItem(default, null):Null<(item:CompletionItem, token:CancellationToken, resolve:(item:Null<CompletionItem>) -> Void) -> Void> = null;

    public function new() {}

    public function provideCompletionItems(model:ITextModel, position:Position, context:CompletionContext, token:CancellationToken, resolve:(list:Null<CompletionList>) -> Void):Void {
        final word = model.getWordUntilPosition(position);
        final range = new Range(position.lineNumber, word.startColumn, position.lineNumber, word.endColumn);
        resolve({
            suggestions: [
                {label: 'name', kind: CompletionItemKind.Field, detail: 'String', insertText: 'name', range: range},
                {label: 'price', kind: CompletionItemKind.Field, detail: 'Float', insertText: 'price', range: range,
                    documentation: {value: 'The unit price of the item.'}},
                {label: 'quantity', kind: CompletionItemKind.Field, detail: 'Int', insertText: 'quantity', range: range},
                {label: 'discount', kind: CompletionItemKind.Method, detail: '(rate:Float) -> Float', insertText: "discount(${1:rate})",
                    insertTextRules: CompletionItemInsertTextRule.InsertAsSnippet, range: range},
                {label: 'toString', kind: CompletionItemKind.Method, detail: '() -> String', insertText: 'toString()', range: range},
                {label: 'Category', kind: CompletionItemKind.Enum, detail: 'enum Category', insertText: 'Category', range: range},
                {label: 'MAX_PRICE', kind: CompletionItemKind.Constant, detail: 'Float', insertText: 'MAX_PRICE', range: range},
                {label: 'tags', kind: CompletionItemKind.Property, detail: 'Array<String>', insertText: 'tags', range: range},
                {label: 'fmt', kind: CompletionItemKind.Snippet, detail: 'format the price', insertText: 'fmt', range: range},
            ]
        });
    }

}

/**
 * A quick fix for the scene's marker: replaces `prise` with `price`.
 */
private class TypoCodeActionProvider implements CodeActionProvider {

    public var displayName(default, null):Null<String> = 'visual';
    public var resolveCodeAction(default, null):Null<(codeAction:CodeAction, token:CancellationToken, resolve:(codeAction:Null<CodeAction>) -> Void) -> Void> = null;
    public var providedCodeActionKinds(default, null):Null<Array<String>> = ['quickfix'];
    public var documentation(default, null):Null<Array<CodeActionProviderDocumentation>> = null;

    public function new() {}

    public function provideCodeActions(model:ITextModel, range:Range, context:CodeActionContext, token:CancellationToken, resolve:(list:Null<CodeActionList>) -> Void):Void {
        final actions:Array<CodeAction> = [];
        if (context.markers != null) {
            for (marker in context.markers) {
                actions.push({
                    title: 'Change spelling to \'price\'',
                    kind: 'quickfix',
                    isPreferred: true,
                    diagnostics: [marker],
                    edit: {edits: [{
                        resource: model.uri,
                        versionId: model.getVersionId(),
                        textEdit: {range: new Range(marker.startLineNumber, marker.startColumn, marker.endLineNumber, marker.endColumn), text: 'price'}
                    }]}
                });
            }
        }
        resolve({actions: actions});
    }

}

/**
 * The language features (`CITYSCAPE_VISUAL_SCENE=suggest`, `hover` or `quickfix`), one
 * editor on a Haxe model, VS Code's Dark+ theme (Light+ with
 * `CITYSCAPE_VISUAL_THEME=light`):
 * - `suggest`: `item.` typed in `cheapest`, the suggest widget open with
 *   the members of `Item` (fields, methods, an enum, a constant, a snippet),
 *   the first one focused with its detail;
 * - `hover`: an error marker on `prise` (squiggle), the marker hover shown
 *   at it with its status bar (View Problem, Quick Fix...) and the lightbulb
 *   of the quick fix in the gutter;
 * - `quickfix`: the quick fix menu of the marker open (Cmd+.).
 */
class LanguageVisualView extends Model implements Render {

    static final SAMPLE = [
        'package demo;',
        '',
        'class Inventory {',
        '',
        '    final items:Array<Item> = [];',
        '',
        '    public function new() {}',
        '',
        '    public function total():Float {',
        '        var sum = 0.0;',
        '        for (item in items) {',
        '            sum += item.prise * item.quantity;',
        '        }',
        '        return sum;',
        '    }',
        '',
        '    public function cheapest(limit:Float):Array<Item> {',
        '        final result:Array<Item> = [];',
        '        for (item in items) {',
        '            if (item.',
        '        }',
        '        return result;',
        '    }',
        '',
        '}',
    ].join('\n');

    final context:Cityscape;

    final model:TextModel;

    final scene:String;

    final dark:Bool;

    var editor:Null<CityscapeEditor> = null;

    var step:Int = 0;

    var stepTime:Float = 0;

    inline function elapsed():Float {
        return haxe.Timer.stamp() - stepTime;
    }

    public function new(cx:Context<LanguageVisualView>, scene:String, dark:Bool) {
        super();
        this.scene = scene;
        this.dark = dark;
        context = new Cityscape();
        context.languageService.registerLanguage({id: 'haxe', extensions: ['.hx'], aliases: ['Haxe']});
        context.textMate.registerGrammar({languageId: 'haxe', grammar: Embed.file('../../../../glaze/assets/glaze/grammars/haxe.json'), path: 'haxe.json'});
        context.languageConfigurationService.register('haxe', {
            comments: {lineComment: '//', blockComment: ['/*', '*/']},
            brackets: [['{', '}'], ['[', ']'], ['(', ')']],
        });
        DemoThemes.apply(context, dark);
        context.registerCompletionItemProvider('haxe', new MembersCompletionProvider());
        context.registerCodeActionProvider('haxe', new TypoCodeActionProvider());
        model = new TextModel(SAMPLE, 'haxe', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
        final line = model.getLineContent(12);
        final start = line.indexOf('prise') + 1;
        Cityscape.setModelMarkers(model, 'visual', [{
            severity: MarkerSeverity.Error,
            message: 'Item has no field prise',
            source: 'haxe',
            code: 'E1001',
            startLineNumber: 12,
            startColumn: start,
            endLineNumber: 12,
            endColumn: start + 5
        }]);
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final options:cityscape.common.config.EditorOptions.IEditorOptions = {
            lineNumbers: 'on',
            fontSize: 14,
            lineHeight: 22,
            cursorBlinking: 'solid',
            padding: {top: 8},
        };
        return div().flex().sizeFull().bg(rgb(dark ? 0x1e1e1e : 0xffffff))
            .child(
                CityscapeEditor.component().model(model).context(context).options(options)
                    .onCreate(e -> editor = e).flex1()
            );
    }

    static function focus(editor:CityscapeEditor, window:Window, cx:App):Void {
        final view:CityscapeView = editor.getView();
        view.focusHandle.focus(window, cx);
        view.syncFocus(window, cx);
    }

    /**
     * Drives the scene, one step per call (once per frame); true when the
     * scene is ready to capture.
     */
    public function update(window:Window, cx:App):Bool {
        if (editor == null || editor.getView() == null) {
            return false;
        }
        final widget = @:privateAccess editor.widget;
        switch step {
            case 0:
                // the kit's popups (the quick fix menu) follow the host's theme mode
                glaze.kit.theme.Theme.setMode(dark ? glaze.kit.theme.ThemeMode.Dark : glaze.kit.theme.ThemeMode.Light, cx);
                focus(editor, window, cx);
                if (scene == 'suggest') {
                    // the cursor after `item.`, completions invoked (Ctrl+Space)
                    editor.setSelections([new Selection(20, 22, 20, 22)], 'visual');
                    SuggestController.get(widget).triggerSuggest();
                }
                else {
                    // the cursor on `prise`: the lightbulb of the quick fix shows in
                    // the gutter, then the marker hover at the marker
                    editor.setSelections([new Selection(12, 26, 12, 26)], 'visual');
                }
                step++;
                stepTime = haxe.Timer.stamp();
            case 1:
                if (elapsed() < 0.8) {
                    return false;
                }
                if (scene == 'hover') {
                    ContentHoverController.get(widget).showContentHover(new Range(12, 26, 12, 26), HoverStartMode.Immediate, HoverStartSource.Keyboard, false);
                }
                else if (scene == 'quickfix') {
                    // Cmd+. (the action runs directly: the editor gets the focus at
                    // the end of the frame, after the precondition is checked)
                    cityscape.contrib.codeAction.view.CodeActionController.get(widget).manualTriggerAtCurrentPosition(
                        'No code actions available', cityscape.contrib.codeAction.common.CodeActionTypes.CodeActionTriggerSource.QuickFix);
                }
                step++;
                stepTime = haxe.Timer.stamp();
            case 2:
                if (elapsed() < 0.8) {
                    return false;
                }
                final hover = ContentHoverController.get(widget);
                trace('language scene: hover visible ' + hover.isHoverVisible + ', suggest visible ' + SuggestController.get(widget).widget.isVisible());
                step++;
                return true;
            case _:
                return true;
        }
        return false;
    }

}
