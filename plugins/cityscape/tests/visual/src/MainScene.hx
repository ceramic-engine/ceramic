// New code for Cityscape (not a port): the visual check of the view.
package;

import ceramic.Platform;
import ceramic.Scene;
import cityscape.Cityscape;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.standalone.CityscapeEditor;
import cityscape.view.CityscapeView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.Glaze;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;

import glaze.Prelude.*;

class MainScene extends Scene {

    static inline var SETTLE_FRAMES = 30;

    var ui:Glaze;

    var frames:Int = 0;

    var captured:Bool = false;

    var out:Null<String> = null;

    var view:Null<Entity<VisualView>> = null;

    override function create() {

        out = Platform.getEnv('CITYSCAPE_VISUAL_OUT');

        ui = new Glaze((window, cx) -> {
            view = cx.newEntity((viewCx:Context<VisualView>) -> new VisualView(viewCx));
            return view;
        });
        ui.size(width, height);
        add(ui);

    }

    override function resize(width:Float, height:Float) {

        if (ui != null) ui.size(width, height);

    }

    override function update(delta:Float) {

        // The cursors are drawn while the editor has focus
        if (view != null && ui.window != null) {
            final v:VisualView = view;
            v.focusLeft(ui.window, Glaze.app);
        }

        if (out == null || out == '' || captured) {
            return;
        }
        frames++;
        if (frames < SETTLE_FRAMES) {
            return;
        }
        captured = true;
        final path:String = out;
        screen.toPng(path, () -> {
            log.success('Captured $path');
            #if web
            final runner = backend.ElectronRunner.electronRunner;
            if (runner != null && runner.takeScreenshot != null) {
                runner.takeScreenshot();
            }
            #else
            Sys.exit(0);
            #end
        });

    }

}

/**
 * Two editors on one Haxe model (the Haxe grammar bundled with Glaze, Monaco's
 * `vs-dark` theme), with typed decorations, a hidden range shown again on the
 * cursor line, injected text, wrapping with an indent per level, CJK and
 * emoji.
 */
class VisualView extends Model implements Render {

    static final SAMPLE = [
        '// 日本語のコメント 😀: CJK and emoji',
        'package demo;',
        '',
        'import ceramic.Color;',
        '',
        '/**',
        ' * A small sample for the visual check of the Cityscape view.',
        ' */',
        'class Greeter {',
        '',
        '    public static final DEFAULT_NAME:String = "world";',
        '',
        '    var count:Int = 0;',
        '',
        '    public function new() {}',
        '',
        '    public function greet(?name:String):String {',
        '        count++;',
        '        final who = name != null ? name : DEFAULT_NAME; /* tag */',
        "        return 'Hello, $who! This is a long line that wraps, to show the indent of the continuation lines in the editor.';",
        '    }',
        '',
        '    public function colors():Array<Color> {',
        '        return [for (i in 0...count) Color.fromHSB(i * 30, 0.5, 0.9)];',
        '    }',
        '',
        '}',
    ].join('\n');

    final context:Cityscape;

    final model:TextModel;

    var focused:Bool = false;

    var left:Null<Entity<CityscapeView>> = null;

    public function new(cx:Context<VisualView>) {
        super();
        context = new Cityscape();
        context.languageService.registerLanguage({id: 'haxe', extensions: ['.hx'], aliases: ['Haxe']});
        context.textMate.registerGrammar({languageId: 'haxe', grammar: Embed.file('../../../../glaze/assets/glaze/grammars/haxe.json'), path: 'haxe.json'});
        context.themeService.setTheme('vs-dark');

        context.registerDecorationStyle('demo-type', {background: '#2c313c', borderRadius: 4, paddingTop: 1, paddingBottom: 1});

        model = new TextModel(SAMPLE, 'haxe', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
        inline function col(lineNumber:Int, needle:String):Int {
            return model.getLineContent(lineNumber).indexOf(needle) + 1;
        }
        final tagStart = col(19, ' /* tag */');
        model.deltaDecorations([], [
            // A typed style through a registered class name
            {range: new Range(9, col(9, 'Greeter'), 9, col(9, 'Greeter') + 7), options: {description: 'type', inlineClassName: 'demo-type'}},
            // Injected text with a typed style
            {range: new Range(13, model.getLineMaxColumn(13), 13, model.getLineMaxColumn(13)), options: {description: 'hint', showIfCollapsed: true, after: {content: '  (field)', inlineStyle: {color: '#6a9955', fontStyle: 'italic'}}}},
            // A hidden range, shown again on the cursor line of each editor
            {range: new Range(19, tagStart, 19, tagStart + 10), options: {description: 'tag', hidden: true, revealOnCursorLine: true}},
            // A whole line style and an overview ruler mark
            {range: new Range(17, 1, 17, 5), options: {description: 'line', isWholeLine: true, lineStyle: {background: '#2a2a22'}, overviewRuler: {color: '#d7ba7d', position: 4}}},
        ]);
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final editorOptions:cityscape.common.config.EditorOptions.IEditorOptions = {
            lineNumbers: 'on',
            wordWrap: 'on',
            wrappingIndent: 'indent',
            fontSize: 14,
            lineHeight: 22,
            rulers: [80],
            renderWhitespace: 'boundary',
            cursorBlinking: 'solid',
            padding: {top: 8},
        };
        final rightOptions:cityscape.common.config.EditorOptions.IEditorOptions = {
            lineNumbers: 'on',
            wordWrap: 'off',
            fontSize: 13,
            lineHeight: 20,
            cursorStyle: 'block',
            cursorBlinking: 'solid',
            renderWhitespace: 'all',
        };
        return div().flex().sizeFull().bg(rgb(0x1e1e1e))
            .child(
                CityscapeEditor.component().model(model).context(context).options(editorOptions)
                    .wrappingIndentColumns(2).onCreate(v -> onLeft(v)).flex1()
            )
            .child(div().w(px(1)).hFull().bg(rgb(0x3a3a3a)))
            .child(
                CityscapeEditor.component().model(model).context(context).options(rightOptions)
                    .onCreate(v -> onRight(v)).w(px(300))
            );
    }

    function onLeft(view:Entity<CityscapeView>):Void {
        left = view;
        final v:CityscapeView = view;
        // A selection over a wrapped line, and a second cursor in the CJK text
        v.viewModel.setSelections('visual', [
            new Selection(20, 30, 20, 90),
            new Selection(1, 6, 1, 6),
        ]);
    }

    function onRight(view:Entity<CityscapeView>):Void {
        final v:CityscapeView = view;
        // On the line of the hidden range: shown in this editor only
        v.viewModel.setSelections('visual', [new Selection(19, 9, 19, 9)]);
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
