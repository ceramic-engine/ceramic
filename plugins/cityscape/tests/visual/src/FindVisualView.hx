// New code for Cityscape (not a port): the visual check of the find widget.
package;

import cityscape.Cityscape;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.CityscapeEditor;
import cityscape.contrib.find.view.FindController;
import cityscape.contrib.find.view.FindModel.FIND_IDS;
import cityscape.view.CityscapeView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;

import glaze.Prelude.*;

/**
 * The find widget (with the replace row) open over an editor showing the
 * Haxe sample: a search with matches, the current one, and a replace
 * string, in Monaco's `vs-dark` theme.
 */
class FindVisualView extends Model implements Render {

    final context:Cityscape;

    final model:TextModel;

    var editor:Null<CityscapeEditor> = null;

    var opened:Bool = false;

    public function new(cx:Context<FindVisualView>) {
        super();
        context = new Cityscape();
        context.languageService.registerLanguage({id: 'haxe', extensions: ['.hx'], aliases: ['Haxe']});
        context.textMate.registerGrammar({languageId: 'haxe', grammar: Embed.file('../../../../glaze/assets/glaze/grammars/haxe.json'), path: 'haxe.json'});
        context.themeService.setTheme('vs-dark');
        model = new TextModel(@:privateAccess MainScene.VisualView.SAMPLE, 'haxe', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final options:cityscape.common.config.EditorOptions.IEditorOptions = {
            lineNumbers: 'on',
            wordWrap: 'off',
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
     * Selects `count` on line 13 and opens the find and replace widget
     * (Cmd+Alt+F / Ctrl+H), with a replace string and the second match
     * current.
     */
    public function openFind(window:Window, cx:App):Void {
        final editor = this.editor;
        if (opened || editor == null) {
            return;
        }
        opened = true;
        final v:CityscapeView = editor.getView();
        v.focusHandle.focus(window, cx);
        final column = model.getLineContent(13).indexOf('count') + 1;
        editor.setSelection(new Selection(13, column, 13, column + 5));
        final controller:FindController = editor.getContribution(CommonFindController.ID);
        // run directly: the editor gets the focus at the end of this frame,
        // and the action's precondition (editorFocus) would not hold yet
        new StartFindReplaceAction(context.editorExtensions).run(context, controller.editor, null);
        controller.getState().change({replaceString: 'total'}, false);
        editor.trigger('visual', FIND_IDS.NextMatchFindAction, null);
    }

}
