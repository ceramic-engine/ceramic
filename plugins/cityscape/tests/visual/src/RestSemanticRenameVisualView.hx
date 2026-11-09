// New code for Cityscape (not a port): the visual check of the semantic
// tokens and of the rename input.
package;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Event.VoidEvent;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.contrib.rename.view.Rename;
import cityscape.view.CityscapeView;
import glaze.App;
import glaze.Context;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;
import haxe.extern.EitherType;
import haxe.io.UInt32Array;

import glaze.Prelude.*;

/**
 * Semantic tokens of the scene's identifiers: the class of each known name
 * (a type, a property, a parameter, a read-only variable...).
 */
private class SceneSemanticTokensProvider implements DocumentSemanticTokensProvider {

    public var onDidChange(default, null):Null<VoidEvent> = null;

    static final LEGEND:SemanticTokensLegend = {
        tokenTypes: ['type', 'property', 'parameter', 'variable', 'method'],
        tokenModifiers: ['readonly', 'defaultLibrary', 'declaration']
    };

    /**
     * Name to [type index, modifier set].
     */
    static final CLASSES:Map<String, Array<Int>> = [
        'Inventory' => [0, 4],
        'Item' => [0, 0],
        'Float' => [0, 2],
        'Array' => [0, 2],
        'items' => [1, 1],
        'prise' => [1, 0],
        'quantity' => [1, 0],
        'limit' => [2, 0],
        'sum' => [3, 0],
        'item' => [3, 1],
        'result' => [3, 1],
        'total' => [4, 4],
        'cheapest' => [4, 4]
    ];

    public function new() {}

    public function getLegend():SemanticTokensLegend {
        return LEGEND;
    }

    public function provideDocumentSemanticTokens(model:ITextModel, lastResultId:Null<String>, token:CancellationToken, resolve:(result:Null<EitherType<SemanticTokens, SemanticTokensEdits>>) -> Void):Void {
        final data:Array<Int> = [];
        var lastLine = 0;
        var lastChar = 0;
        final word = ~/[A-Za-z_][A-Za-z0-9_]*/;
        for (lineNumber in 1...model.getLineCount() + 1) {
            final line = model.getLineContent(lineNumber);
            var pos = 0;
            while (word.matchSub(line, pos)) {
                final matched = word.matchedPos();
                final name = word.matched(0);
                final cls = CLASSES.get(name);
                if (cls != null) {
                    final lineIndex = lineNumber - 1;
                    final deltaLine = lineIndex - lastLine;
                    data.push(deltaLine);
                    data.push(deltaLine == 0 ? matched.pos - lastChar : matched.pos);
                    data.push(matched.len);
                    data.push(cls[0]);
                    data.push(cls[1]);
                    lastLine = lineIndex;
                    lastChar = matched.pos;
                }
                pos = matched.pos + matched.len;
            }
        }
        final tokens:SemanticTokens = {data: UInt32Array.fromArray(data)};
        resolve(tokens);
    }

    public function releaseDocumentSemanticTokens(resultId:Null<String>):Void {}

}

/**
 * Renames every occurrence of the word at the position.
 */
private class SceneRenameProvider implements RenameProvider {

    public var resolveRenameLocation(default, null):Null<(model:ITextModel, position:Position, token:CancellationToken, resolve:(location:Null<RenameLocation>) -> Void) -> Void> = null;

    public function new() {}

    public function provideRenameEdits(model:ITextModel, position:Position, newName:String, token:CancellationToken, resolve:(edit:Null<WorkspaceEditAndRejection>) -> Void):Void {
        final word = model.getWordAtPosition(position);
        final edits:Array<EitherType<IWorkspaceTextEdit, IWorkspaceFileEdit>> = [];
        if (word != null) {
            for (match in model.findMatches(word.word, false, false, true, null, false)) {
                final edit:IWorkspaceTextEdit = {resource: model.uri, textEdit: {range: match.range, text: newName}, versionId: model.getVersionId()};
                edits.push(edit);
            }
        }
        resolve({edits: edits});
    }

}

/**
 * Semantic tokens and rename (`CITYSCAPE_VISUAL_SCENE=semantic`), one
 * editor on a Haxe model, VS Code's Dark+ theme (Light+ with
 * `CITYSCAPE_VISUAL_THEME=light`), `editor.semanticHighlighting.enabled`
 * on (the theme files of the fixtures do not enable it):
 * - the semantic tokens of the scene's provider color the identifiers by
 *   their class through the TextMate rules of Dark+ (VS Code's probed
 *   scopes): `items`, `prise`, `quantity` (properties), `limit`
 *   (parameter), `sum`, `item`, `result` (variables) in `#9CDCFE`, the
 *   types in `#4EC9B0`, `total` and `cheapest` (methods) in `#DCDCAA`;
 * - the rename input (F2) open on `items` of line 5, below the line, the
 *   name selected, `editorWidget.background` box with the widget shadow.
 */
class RestSemanticRenameVisualView extends Model implements Render {

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
        '            if (item.prise < limit) result.push(item);',
        '        }',
        '        return result;',
        '    }',
        '',
        '}',
    ].join('\n');

    final context:Cityscape;

    final model:TextModel;

    final dark:Bool;

    var editor:Null<CityscapeEditor> = null;

    var step:Int = 0;

    var stepTime:Float = 0;

    inline function elapsed():Float {
        return haxe.Timer.stamp() - stepTime;
    }

    public function new(cx:Context<RestSemanticRenameVisualView>, dark:Bool) {
        super();
        this.dark = dark;
        context = new Cityscape();
        context.languageService.registerLanguage({id: 'haxe', extensions: ['.hx'], aliases: ['Haxe']});
        context.textMate.registerGrammar({languageId: 'haxe', grammar: Embed.file('../../../../glaze/assets/glaze/grammars/haxe.json'), path: 'haxe.json'});
        context.languageConfigurationService.register('haxe', {
            comments: {lineComment: '//', blockComment: ['/*', '*/']},
            brackets: [['{', '}'], ['[', ']'], ['(', ')']],
        });
        DemoThemes.apply(context, dark);
        context.registerDocumentSemanticTokensProvider('haxe', new SceneSemanticTokensProvider());
        context.registerRenameProvider('haxe', new SceneRenameProvider());
        // the semantic coloring sees the models of the model service
        model = context.modelService.createModel(SAMPLE, 'haxe');
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final options:cityscape.common.config.EditorOptions.IEditorOptions = {
            lineNumbers: 'on',
            fontSize: 14,
            lineHeight: 22,
            cursorBlinking: 'solid',
            padding: {top: 8},
            // Monaco's `'semanticHighlighting.enabled': true`
            semanticHighlighting: {enabled: true}
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
                glaze.kit.theme.Theme.setMode(dark ? glaze.kit.theme.ThemeMode.Dark : glaze.kit.theme.ThemeMode.Light, cx);
                focus(editor, window, cx);
                // the cursor in `items` of line 5
                editor.setSelections([new Selection(5, 13, 5, 13)], 'visual');
                step++;
                stepTime = haxe.Timer.stamp();
            case 1:
                // the semantic tokens arrive (asked at once, then debounced)
                if (elapsed() < 0.8) {
                    return false;
                }
                // F2
                widget.trigger('keyboard', RenameAction.ID, null);
                step++;
                stepTime = haxe.Timer.stamp();
            case 2:
                if (elapsed() < 0.8) {
                    return false;
                }
                final renameWidget = RenameController.get(widget).getRenameWidget();
                trace('semantic scene: semantic tokens ' + model.tokenization.hasCompleteSemanticTokens() + ', rename input visible ' + renameWidget.isVisible + ' with ' + renameWidget.getInputValue());
                step++;
                return true;
            case _:
                return true;
        }
        return false;
    }

}
