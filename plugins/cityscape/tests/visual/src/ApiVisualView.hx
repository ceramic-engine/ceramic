// New code for Cityscape (not a port): the visual check of the editor API.
package;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.Uri;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Selection;
import cityscape.platform.markers.common.Markers;
import glaze.App;
import glaze.Context;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;

import glaze.Prelude.*;

/**
 * Two editors of one context through the public API: models created with
 * `Cityscape.createModel`, the left editor switched to another model and
 * back (its selection restored from the per-model view state), markers
 * (an error, a warning, an info) drawn as squiggles with overview ruler
 * marks, an action with a keybinding, `vs` theme.
 */
class ApiVisualView extends Model implements Render {

    final context:Cityscape;

    final notes:ITextModel;

    final todo:ITextModel;

    final scratch:ITextModel;

    var focused:Bool = false;

    var left:Null<CityscapeEditor> = null;

    public function new(cx:Context<ApiVisualView>) {
        super();
        context = new Cityscape();
        // VS Code's Light+ (DemoThemes.hx), set through the public API
        DemoThemes.apply(context, false);
        Cityscape.setTheme('light-plus', context);
        notes = Cityscape.createModel([
            'Release notes',
            '=============',
            '',
            'version 1.2.0',
            '  - faster startup',
            '  - the settings file is read once',
            '  - fixed a crash when the list is emtpy',
            '',
            'version 1.1.0',
            '  - first public release',
            '  - TODO: write the migration guide',
        ].join('\n'), null, Uri.parse('inmemory://demo/notes.txt'), context);
        todo = Cityscape.createModel([
            'Shopping list',
            '',
            '[x] bread',
            '[ ] milk',
            '[ ] coffee',
        ].join('\n'), null, Uri.parse('inmemory://demo/todo.txt'), context);
        scratch = Cityscape.createModel('scratch model, shown for a moment', null, Uri.parse('inmemory://demo/scratch.txt'), context);

        Cityscape.setModelMarkers(notes, 'demo', [{
            severity: MarkerSeverity.Error,
            message: 'Misspelled word',
            startLineNumber: 7,
            startColumn: 36,
            endLineNumber: 7,
            endColumn: 41
        }, {
            severity: MarkerSeverity.Warning,
            message: 'Unfinished task',
            startLineNumber: 11,
            startColumn: 5,
            endLineNumber: 11,
            endColumn: 9
        }, {
            severity: MarkerSeverity.Info,
            message: 'Version',
            startLineNumber: 4,
            startColumn: 9,
            endLineNumber: 4,
            endColumn: 14
        }]);
        Cityscape.setModelMarkers(todo, 'demo', [{
            severity: MarkerSeverity.Warning,
            message: 'Not bought yet',
            startLineNumber: 4,
            startColumn: 5,
            endLineNumber: 4,
            endColumn: 9
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
        return div().flex().sizeFull().bg(rgb(0xffffff))
            .child(
                CityscapeEditor.component().model(notes).context(context).options(options)
                    .onCreate(onLeft).flex1()
            )
            .child(div().w(px(1)).hFull().bg(rgb(0xd0d0d0)))
            .child(
                CityscapeEditor.component().model(todo).context(context).options(options)
                    .w(px(280))
            );
    }

    function onLeft(editor:CityscapeEditor):Void {
        left = editor;
        // An action with a keybinding (Monaco's addAction)
        editor.addAction({
            id: 'demo.uppercase',
            label: 'Uppercase Selection',
            keybindings: [KeyMod.CtrlCmd | KeyMod.Shift | KeyCode.KeyU],
            run: (ed, _) -> {
                final selection = ed.getSelection();
                final model = ed.getModel();
                if (selection != null && model != null) {
                    ed.executeEdits('demo', [{range: selection, text: model.getValueInRange(selection).toUpperCase()}]);
                }
            }
        });
        // Run it once on a word of the first line
        editor.setSelection(new Selection(1, 9, 1, 14));
        editor.trigger('demo', 'demo.uppercase', null);
        // A selection on the notes, kept while another model is shown, then
        // restored when the notes come back
        editor.setSelection(new Selection(6, 5, 6, 38));
        editor.setModel(scratch);
        editor.setPosition({lineNumber: 1, column: 8});
        editor.setModel(notes);
    }

    public function focusLeft(window:Window, cx:App):Void {
        if (focused || left == null) {
            return;
        }
        focused = true;
        left.focus();
        final view = left.getView();
        if (view != null) {
            (view : cityscape.view.CityscapeView).focusHandle.focus(window, cx);
        }
    }

}
