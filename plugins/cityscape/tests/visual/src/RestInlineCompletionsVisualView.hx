// New code for Cityscape (not a port): the visual check of the inline
// completions (ghost text), not registered in MainScene yet (cs7-rest-inline).
package;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.contrib.inlineCompletions.view.controller.InlineCompletionsController;
import cityscape.view.CityscapeView;
import glaze.App;
import glaze.Context;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;

import glaze.Prelude.*;

/**
 * Suggests the body of `total` after its signature (the scene's own
 * provider): a multi line ghost text.
 */
private class TotalInlineCompletionsProvider implements InlineCompletionsProvider {

    public var handleItemDidShow(default, null):Null<(completions:InlineCompletions, item:InlineCompletion, updatedInsertText:String) -> Void> = null;
    public var handlePartialAccept(default, null):Null<(completions:InlineCompletions, item:InlineCompletion, acceptedCharacters:Int, info:PartialAcceptInfo) -> Void> = null;
    public var groupId(default, null):Null<InlineCompletionProviderGroupId> = null;
    public var yieldsToGroupIds(default, null):Null<Array<InlineCompletionProviderGroupId>> = null;

    public function new() {}

    public function provideInlineCompletions(model:ITextModel, position:Position, context:InlineCompletionContext, token:CancellationToken, resolve:(completions:Null<InlineCompletions>) -> Void):Void {
        final line = model.getLineContent(position.lineNumber);
        resolve({items: [{
            insertText: line + ' {\n        var sum = 0.0;\n        for (item in items) {\n            sum += item.price * item.quantity;\n        }\n        return sum;\n    }',
            range: new Range(position.lineNumber, 1, position.lineNumber, line.length + 1)
        }]});
    }

    public function freeInlineCompletions(completions:InlineCompletions):Void {}

}

/**
 * The inline completions (`CITYSCAPE_VISUAL_SCENE=inline`), one editor on a
 * Haxe model, VS Code's Dark+ theme (Light+ with
 * `CITYSCAPE_VISUAL_THEME=light`): the cursor at the end of
 * `public function total():Float` (line 9) and an inline suggestion shown
 * (`editor.action.inlineSuggest.trigger`): ` {` in the ghost color, italic,
 * after the cursor on line 9, then the six next lines of the suggestion
 * (`var sum = 0.0;` ... `}`) in a view zone below line 9 pushing lines 10
 * and after down, in the ghost color and italic, aligned with the code.
 */
class RestInlineCompletionsVisualView extends Model implements Render {

    static final SAMPLE = [
        'package demo;',
        '',
        'class Inventory {',
        '',
        '    final items:Array<Item> = [];',
        '',
        '    public function new() {}',
        '',
        '    public function total():Float',
        '',
        '    public function count():Int {',
        '        return items.length;',
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

    public function new(cx:Context<RestInlineCompletionsVisualView>, dark:Bool) {
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
        context.registerInlineCompletionsProvider('haxe', new TotalInlineCompletionsProvider());
        model = new TextModel(SAMPLE, 'haxe', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
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
                focus(editor, window, cx);
                // the cursor at the end of `public function total():Float`
                editor.setSelections([new Selection(9, 34, 9, 34)], 'visual');
                step++;
                stepTime = haxe.Timer.stamp();
            case 1:
                if (elapsed() < 0.3) {
                    return false;
                }
                // editor.action.inlineSuggest.trigger
                final controller = InlineCompletionsController.get(widget);
                final inlineModel = controller != null ? controller.model.get() : null;
                if (inlineModel != null) {
                    inlineModel.triggerExplicitly();
                }
                step++;
                stepTime = haxe.Timer.stamp();
            case 2:
                if (elapsed() < 0.8) {
                    return false;
                }
                final controller = InlineCompletionsController.get(widget);
                final views = controller != null ? controller.getGhostTextViews() : [];
                final lines = views.length > 0 ? views[0].getAdditionalLines() : null;
                trace('inline scene: ghost text views ' + views.length + ', additional lines ' + (lines != null ? lines.length : 0));
                step++;
                return true;
            case _:
                return true;
        }
        return false;
    }

}
