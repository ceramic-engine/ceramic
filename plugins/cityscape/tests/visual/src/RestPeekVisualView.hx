// New code for Cityscape (not a port): the visual check of the references
// peek view.
package;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Uri;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.view.CityscapeView;
import glaze.App;
import glaze.Context;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;

import glaze.Prelude.*;

/**
 * The references of `total` in the scene's model (the declaration and the
 * three calls).
 */
private class TotalReferences implements ReferenceProvider {

    public function new() {}

    public function provideReferences(model:ITextModel, position:Position, context:ReferenceContext, token:CancellationToken, resolve:(locations:Null<Array<Location>>) -> Void):Void {
        final result:Array<Location> = [];
        for (lineNumber in 1...model.getLineCount() + 1) {
            final line = model.getLineContent(lineNumber);
            var index = line.indexOf('total');
            while (index >= 0) {
                result.push({uri: model.uri, range: new Range(lineNumber, index + 1, lineNumber, index + 6)});
                index = line.indexOf('total', index + 5);
            }
        }
        resolve(result);
    }

}

/**
 * The references peek view (`CITYSCAPE_VISUAL_SCENE=peek`), VS Code's Dark+
 * theme: Shift+F12 on `total` opens the peek view under the line, the
 * preview editor on the left (the peek view's blue background, the
 * references highlighted), the list of the references on the right (the
 * selected one highlighted, the match of each line in orange).
 */
class RestPeekVisualView extends Model implements Render {

    static final SAMPLE = [
        'class Cart {',
        '',
        '    final prices:Array<Float> = [];',
        '',
        '    public function total():Float {',
        '        var sum = 0.0;',
        '        for (price in prices) sum += price;',
        '        return sum;',
        '    }',
        '',
        '    public function summary():String {',
        "        return 'Total: ' + total();",
        '    }',
        '',
        '    public function isEmpty():Bool {',
        '        return total() == 0;',
        '    }',
        '',
        '    public function average():Float {',
        '        return prices.length > 0 ? total() / prices.length : 0;',
        '    }',
        '',
        '}',
    ].join('\n');

    final context:Cityscape;

    final model:ITextModel;

    var editor:Null<CityscapeEditor> = null;

    var step:Int = 0;

    var stepTime:Float = 0;

    public function new(cx:Context<RestPeekVisualView>) {
        super();
        context = new Cityscape();
        context.languageService.registerLanguage({id: 'haxe', extensions: ['.hx'], aliases: ['Haxe']});
        context.textMate.registerGrammar({languageId: 'haxe', grammar: Embed.file('../../../../glaze/assets/glaze/grammars/haxe.json'), path: 'haxe.json'});
        DemoThemes.apply(context, true);
        context.registerReferenceProvider('haxe', new TotalReferences());
        model = context.modelService.createModel(SAMPLE, 'haxe', Uri.parse('file:///demo/Cart.hx'));
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final options:cityscape.common.config.EditorOptions.IEditorOptions = {
            lineNumbers: 'on',
            fontSize: 14,
            lineHeight: 22,
            cursorBlinking: 'solid',
            padding: {top: 8},
        };
        return div().flex().sizeFull().bg(rgb(0x1e1e1e))
            .child(
                CityscapeEditor.component().model(model).context(context).options(options)
                    .onCreate(e -> editor = e).flex1()
            );
    }

    /**
     * Drives the scene, one step per call (once per frame); true when the
     * scene is ready to capture.
     */
    public function update(window:Window, cx:App):Bool {
        if (editor == null || editor.getView() == null) {
            return false;
        }
        switch step {
            case 0:
                final view:CityscapeView = editor.getView();
                view.focusHandle.focus(window, cx);
                editor.setSelections([new Selection(5, 23, 5, 23)], 'visual');
                step++;
                stepTime = haxe.Timer.stamp();
            case 1:
                if (haxe.Timer.stamp() - stepTime < 0.5) {
                    return false;
                }
                editor.trigger('keyboard', 'editor.action.referenceSearch.trigger', null);
                step++;
                stepTime = haxe.Timer.stamp();
            case 2:
                if (haxe.Timer.stamp() - stepTime < 0.8) {
                    return false;
                }
                step++;
                return true;
            case _:
                return true;
        }
        return false;
    }

}
