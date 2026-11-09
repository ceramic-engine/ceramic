// New code for Cityscape (not a port): the visual check of the diff editor.
package;

import cityscape.Cityscape;
import cityscape.CityscapeDiffEditor;
import cityscape.common.model.TextModel;
import cityscape.view.widget.diffEditor.DiffProviderFactoryService.DiffComputationMode;
import glaze.App;
import glaze.Context;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;

import glaze.Prelude.*;

/**
 * The diff editor (`CITYSCAPE_VISUAL_SCENE=diff`), VS Code's Dark+ theme:
 * at the top, two versions of a JavaScript file side by side (inserted,
 * deleted and modified lines, the changed characters, the diagonal fill of
 * the empty side, the +/- signs, the overview ruler) with the unchanged
 * regions hidden behind their "N hidden lines" bars; at the bottom, the
 * same diff in the inline view (the deleted lines between the lines of the
 * modified file). Generic grammar bundled with Glaze.
 */
class DiffVisualView extends Model implements Render {

    static final ORIGINAL = [
        '// Inventory of a small shop',
        "import { readFile } from 'fs';",
        '',
        'export class Store {',
        '    constructor(root) {',
        '        this.root = root;',
        '        this.cache = new Map();',
        '    }',
        '',
        '    read(name) {',
        '        const path = this.root + "/" + name;',
        '        return readFile(path);',
        '    }',
        '',
        '    total(items) {',
        '        let result = 0;',
        '        for (const item of items) {',
        '            result += item.price;',
        '        }',
        '        return result;',
        '    }',
        '',
        '    names(items) {',
        '        return items.map(item => item.name);',
        '    }',
        '',
        '    count(items) {',
        '        return items.length;',
        '    }',
        '',
        '    clear() {',
        '        this.cache.clear();',
        '    }',
        '',
        '    remove(name) {',
        '        this.cache.delete(name);',
        '        return true;',
        '    }',
        '}',
    ].join('\n');

    static final MODIFIED = [
        '// Inventory of a small shop',
        "import { readFile } from 'fs';",
        "import { join } from 'path';",
        '',
        'export class Store {',
        '    constructor(root) {',
        '        this.root = root;',
        '        this.cache = new Map();',
        '    }',
        '',
        '    read(name) {',
        '        const path = join(this.root, name);',
        '        if (!this.cache.has(path)) {',
        '            this.cache.set(path, readFile(path));',
        '        }',
        '        return this.cache.get(path);',
        '    }',
        '',
        '    total(items) {',
        '        let result = 0;',
        '        for (const item of items) {',
        '            result += item.price;',
        '        }',
        '        return result;',
        '    }',
        '',
        '    names(items) {',
        '        return items.map(item => item.name);',
        '    }',
        '',
        '    count(items) {',
        '        return items.length;',
        '    }',
        '',
        '    clear() {',
        '        this.cache.clear();',
        '    }',
        '}',
    ].join('\n');

    final context:Cityscape;
    final original:TextModel;
    final modified:TextModel;
    final inlineOriginal:TextModel;
    final inlineModified:TextModel;

    public function new(cx:Context<DiffVisualView>) {
        super();
        context = new Cityscape();
        context.languageService.registerLanguage({id: 'javascript', extensions: ['.js'], aliases: ['JavaScript']});
        context.textMate.registerGrammar({languageId: 'javascript', grammar: Embed.file('../../../../glaze/assets/glaze/grammars/javascript.json'), path: 'javascript.json'});
        DemoThemes.apply(context, true);

        original = new TextModel(ORIGINAL, 'javascript', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
        modified = new TextModel(MODIFIED, 'javascript', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
        inlineOriginal = new TextModel(ORIGINAL, 'javascript', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
        inlineModified = new TextModel(MODIFIED, 'javascript', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().flex().flexCol().sizeFull().bg(rgb(0x1e1e1e))
            .child(
                CityscapeDiffEditor.component().at('side-by-side')
                    .model({original: original, modified: modified})
                    .context(context)
                    .computationMode(DiffComputationMode.Synchronous)
                    .options({
                        fontSize: 13,
                        lineHeight: 19,
                        cursorBlinking: 'solid',
                        useInlineViewWhenSpaceIsLimited: false,
                        hideUnchangedRegions: {enabled: true, contextLineCount: 2, minimumLineCount: 3},
                    })
                    .flex1()
            )
            .child(div().h(px(1)).wFull().bg(rgb(0x3a3a3a)))
            .child(
                CityscapeDiffEditor.component().at('inline')
                    .model({original: inlineOriginal, modified: inlineModified})
                    .context(context)
                    .computationMode(DiffComputationMode.Synchronous)
                    .options({
                        fontSize: 13,
                        lineHeight: 19,
                        cursorBlinking: 'solid',
                        renderSideBySide: false,
                    })
                    .flex1()
            );
    }

}
