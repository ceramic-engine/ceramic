// Ported from vscode src/vs/editor/test/browser/testCodeEditor.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package testing;

import cityscape.Cityscape;
import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.CursorEvents;
import cityscape.common.ViewModelEventDispatcher;
import cityscape.common.EditorCommon;
import cityscape.common.Model;
import cityscape.common.ViewModel.IViewModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.config.EditorViewOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.common.viewModel.MonospaceLineBreaksComputer;
import cityscape.common.viewModel.ViewModelImpl;
import cityscape.view.EditorExtensions.IEditorContributionDescription;
import cityscape.view.widget.codeEditor.CodeEditorWidget;
import cityscape.view.config.EditorConfiguration;
import haxe.extern.EitherType;
import tests.TestTextModel;

/**
 * vscode's test code editor: a `CodeEditorWidget` without a view, with the
 * test configuration (Monaco's `TestConfiguration`: 100x100, the mock font
 * of 19 px lines and 10 px characters, which is what `EditorConfiguration`
 * computes without a font measurer) and no contribution unless asked for
 * (vscode's `contributions` option).
 *
 * `context` is the `Cityscape` context of the test (vscode's test services:
 * languages, language configurations, tokenizers, undo/redo, commands).
 */
class TestCodeEditor extends CodeEditorWidget {

    /**
     * `envConfig` is vscode's `TestCodeEditorCreationOptions.envConfig`
     * (`outerWidth`, `outerHeight`; 100x100 by default).
     */
    public function new(context:Cityscape, model:Null<TextModel>, options:IEditorOptions, ?contributions:Array<IEditorContributionDescription>, ?envConfig:{?outerWidth:Float, ?outerHeight:Float}) {
        super(context, new EditorConfiguration(false, options, {
            width: envConfig != null && envConfig.outerWidth != null ? envConfig.outerWidth : 100,
            height: envConfig != null && envConfig.outerHeight != null ? envConfig.outerHeight : 100
        }), {
            contributions: contributions != null ? contributions : [],
            keepViewStatePerModel: false
        });
        if (model != null) {
            this.setModel(model);
        }
    }

    public function registerDisposable(disposable:IDisposable):Void {
        _register(disposable);
    }

    /**
     * The contributions created by `registerAndInstantiateContribution`.
     */
    final _testContributions = new Map<String, IEditorContribution>();

    /**
     * vscode's `registerAndInstantiateContribution`: creates a contribution
     * of this editor, returned by `getContribution(id)` and disposed with
     * the editor.
     */
    public function registerAndInstantiateContribution<T:IEditorContribution>(id:String, ctor:(editor:TestCodeEditor) -> T):T {
        final r = ctor(this);
        _testContributions.set(id, r);
        _register(Lifecycle.toDisposable(() -> r.dispose()));
        return r;
    }

    override public function getContribution<T:IEditorContribution>(id:String):Null<T> {
        final r = _testContributions.get(id);
        if (r != null) {
            return cast r;
        }
        return super.getContribution(id);
    }

    // ---- withTestCodeEditor

    /**
     * vscode's `withTestCodeEditor`: `text` is a model, a string or an array
     * of lines (joined with `\n`). A model given is not disposed; a model
     * created here is. The editor has the focus.
     */
    public static function withTestCodeEditor(text:EitherType<TextModel, EitherType<String, Array<String>>>, options:Null<IEditorOptions>, callback:(editor:TestCodeEditor, viewModel:ViewModel) -> Void, ?context:Cityscape):Void {
        var model:TextModel;
        var ownModel = false;
        if (Std.isOfType(text, TextModel)) {
            model = cast text;
        }
        else {
            final ctx = context != null ? context : new Cityscape();
            final str:String = Std.isOfType(text, Array) ? (cast text : Array<String>).join('\n') : cast text;
            model = TestTextModel.instantiateTextModel(ctx, str);
            ownModel = true;
        }
        final ctx = context != null ? context : model.context;
        final editor = new TestCodeEditor(ctx, model, options != null ? options : {});
        final viewModel:ViewModel = editor.getViewModel();
        viewModel.setHasFocus(true);
        try {
            callback(editor, viewModel);
        }
        catch (e:Dynamic) {
            editor.dispose();
            if (ownModel) {
                model.dispose();
            }
            throw e;
        }
        editor.dispose();
        if (ownModel) {
            model.dispose();
        }
    }

}
