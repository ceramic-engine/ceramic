// New code for Cityscape (not a port): the visual check of folding.
package;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.base.common.RegExp;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
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
 * Folded regions (`CITYSCAPE_VISUAL_SCENE=folding`): a Python file folded by
 * indentation (an off side language) with its folding controls always shown,
 * and a JavaScript file with `//#region` markers, folded, its controls shown
 * on hover only (the collapsed ones stay). The collapsed lines show the `⋯`
 * and the folded background; the chevrons are the kit's icons in
 * `editorGutter.foldingControlForeground`. Generic grammars bundled with
 * Glaze, Monaco's `vs-dark` theme.
 */
class FoldingVisualView extends Model implements Render {

    static final PYTHON = [
        '# Folding by indentation (off side)',
        'import os',
        '',
        'class Inventory:',
        '    """A small inventory of items."""',
        '',
        '    def __init__(self, items):',
        '        self.items = list(items)',
        '        self.count = len(self.items)',
        '',
        '    def total(self):',
        '        result = 0',
        '        for item in self.items:',
        '            if item.price > 0:',
        '                result += item.price',
        '        return result',
        '',
        '    def names(self):',
        '        return [item.name for item in self.items]',
        '',
        '# region helpers',
        'def load(path):',
        '    with open(path) as f:',
        '        return f.read()',
        '# endregion',
        '',
        'print(Inventory([]).total())',
    ].join('\n');

    static final JAVASCRIPT = [
        '// Folding with region markers',
        '//#region imports',
        "import { readFile } from 'fs';",
        "import { join } from 'path';",
        '//#endregion',
        '',
        'export class Store {',
        '    constructor(root) {',
        '        this.root = root;',
        '        this.cache = new Map();',
        '    }',
        '',
        '    //#region reading',
        '    read(name) {',
        '        const path = join(this.root, name);',
        '        if (!this.cache.has(path)) {',
        '            this.cache.set(path, readFile(path));',
        '        }',
        '        return this.cache.get(path);',
        '    }',
        '    //#endregion',
        '',
        '    clear() {',
        '        this.cache.clear();',
        '    }',
        '}',
    ].join('\n');

    final context:Cityscape;

    final python:TextModel;

    final javascript:TextModel;

    var focused:Bool = false;

    var left:Null<Entity<CityscapeView>> = null;

    public function new(cx:Context<FoldingVisualView>) {
        super();
        context = new Cityscape();
        context.languageService.registerLanguage({id: 'python', extensions: ['.py'], aliases: ['Python']});
        context.languageService.registerLanguage({id: 'javascript', extensions: ['.js'], aliases: ['JavaScript']});
        context.textMate.registerGrammar({languageId: 'python', grammar: Embed.file('../../../../glaze/assets/glaze/grammars/python.json'), path: 'python.json'});
        context.textMate.registerGrammar({languageId: 'javascript', grammar: Embed.file('../../../../glaze/assets/glaze/grammars/javascript.json'), path: 'javascript.json'});
        // The folding rules of VS Code's Python and JavaScript language configurations
        context.languageConfigurationService.register('python', {
            folding: {offSide: true, markers: {start: new RegExp('^\\s*#\\s*region\\b'), end: new RegExp('^\\s*#\\s*endregion\\b')}}
        });
        context.languageConfigurationService.register('javascript', {
            folding: {markers: {start: new RegExp('^\\s*//\\s*#?region\\b'), end: new RegExp('^\\s*//\\s*#?endregion\\b')}}
        });
        context.themeService.setTheme('vs-dark');

        python = new TextModel(PYTHON, 'python', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
        javascript = new TextModel(JAVASCRIPT, 'javascript', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final leftOptions:cityscape.common.config.EditorOptions.IEditorOptions = {
            lineNumbers: 'on',
            fontSize: 14,
            lineHeight: 22,
            showFoldingControls: 'always',
            cursorBlinking: 'solid',
            padding: {top: 8},
        };
        final rightOptions:cityscape.common.config.EditorOptions.IEditorOptions = {
            lineNumbers: 'on',
            fontSize: 13,
            lineHeight: 20,
            cursorBlinking: 'solid',
            padding: {top: 8},
        };
        return div().flex().sizeFull().bg(rgb(0x1e1e1e))
            .child(
                CityscapeEditor.component().model(python).context(context).options(leftOptions)
                    .onCreate(e -> onLeft(e.getView())).flex1()
            )
            .child(div().w(px(1)).hFull().bg(rgb(0x3a3a3a)))
            .child(
                CityscapeEditor.component().model(javascript).context(context).options(rightOptions)
                    .onCreate(e -> onRight(e.getView())).flex1()
            );
    }

    function onLeft(view:Entity<CityscapeView>):Void {
        left = view;
        final v:CityscapeView = view;
        v.foldingController._flushPendingUpdate();
        v.viewModel.setSelections('visual', [new Selection(13, 9, 13, 9)]);
        // `__init__` and the region of helpers folded (0 based selection lines)
        v.runFoldingCommand('editor.fold', {selectionLines: [6]});
        v.runFoldingCommand('editor.fold', {selectionLines: [20]});
    }

    function onRight(view:Entity<CityscapeView>):Void {
        final v:CityscapeView = view;
        v.foldingController._flushPendingUpdate();
        v.viewModel.setSelections('visual', [new Selection(24, 9, 24, 9)]);
        // the marker regions folded (`editor.foldAllMarkerRegions`)
        v.runFoldingCommand('editor.foldAllMarkerRegions');
    }

    public function focusLeft(window:Window, cx:App):Void {
        if (focused || left == null) {
            return;
        }
        focused = true;
        final v:CityscapeView = left;
        v.focusHandle.focus(window, cx);
    }

}
