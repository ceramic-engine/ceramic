// New code for Cityscape (not a port): the visual check of the editing
// contributions (bracket pairs, guides, word highlight, multicursor, sticky
// scroll).
package;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.common.CursorEvents.CursorChangeReason;
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
 * The editing contributions (`CITYSCAPE_VISUAL_SCENE=editing`), three
 * editors on one Haxe model, VS Code's Dark+ theme:
 * - left: scrolled into `cheapest`, the sticky scroll shows the enclosing
 *   scopes (`class`, `function`, `for`, `if`); bracket pair colorization,
 *   bracket pair guides (`guides.bracketPairs`) with the active pair of the
 *   cursor highlighted;
 * - right top (focused): the word under the cursor (`total`) highlighted in
 *   its other occurrences (word highlighter, textual provider; the
 *   highlights show in every editor of the model, like Monaco), the
 *   matching brackets of the cursor;
 * - right bottom: three selections of `item` added with Cmd+D
 *   (`editor.action.addSelectionToNextFindMatch`), the other occurrences
 *   highlighted by the selection highlighter.
 */
class EditingVisualView extends Model implements Render {

    static final SAMPLE = [
        'package demo;',
        '',
        'import ceramic.Color;',
        '',
        'class Inventory {',
        '',
        '    final items:Array<Item> = [];',
        '',
        '    var total:Float = 0;',
        '',
        '    public function new() {}',
        '',
        '    public function add(item:Item):Void {',
        '        items.push(item);',
        '        total += item.price;',
        '    }',
        '',
        '    public function cheapest(limit:Int):Array<Item> {',
        '        final result:Array<Item> = [];',
        '        for (item in items) {',
        '            if (item.price < limit) {',
        '                result.push(item);',
        '            }',
        '        }',
        '        result.sort((a, b) -> Std.int(a.price - b.price));',
        '        return result;',
        '    }',
        '',
        '    public function colors():Array<Color> {',
        '        return [for (i in 0...items.length) Color.fromHSB(i * 30, 0.5, 0.9)];',
        '    }',
        '',
        '}',
        '',
        'typedef Item = {',
        '    var name:String;',
        '    var price:Float;',
        '}',
    ].join('\n');

    final context:Cityscape;

    final model:TextModel;

    var left:Null<CityscapeEditor> = null;

    var rightTop:Null<CityscapeEditor> = null;

    var rightBottom:Null<CityscapeEditor> = null;

    var step:Int = 0;

    var frame:Int = 0;

    /**
     * When the current step started (seconds): the contributions wait in
     * timers (word highlight 50 + 250 ms, sticky model 300 ms), so the steps
     * wait in time, not in frames.
     */
    var stepTime:Float = 0;

    inline function elapsed():Float {
        return haxe.Timer.stamp() - stepTime;
    }

    public function new(cx:Context<EditingVisualView>) {
        super();
        context = new Cityscape();
        context.languageService.registerLanguage({id: 'haxe', extensions: ['.hx'], aliases: ['Haxe']});
        context.textMate.registerGrammar({languageId: 'haxe', grammar: Embed.file('../../../../glaze/assets/glaze/grammars/haxe.json'), path: 'haxe.json'});
        // The brackets and comments of vshaxe's language configuration
        context.languageConfigurationService.register('haxe', {
            comments: {lineComment: '//', blockComment: ['/*', '*/']},
            brackets: [['{', '}'], ['[', ']'], ['(', ')']],
        });
        DemoThemes.apply(context, true);
        model = new TextModel(SAMPLE, 'haxe', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final leftOptions:cityscape.common.config.EditorOptions.IEditorOptions = {
            lineNumbers: 'on',
            fontSize: 14,
            lineHeight: 22,
            cursorBlinking: 'solid',
            guides: {bracketPairs: true},
            padding: {top: 0},
        };
        final rightOptions:cityscape.common.config.EditorOptions.IEditorOptions = {
            lineNumbers: 'on',
            fontSize: 13,
            lineHeight: 20,
            cursorBlinking: 'solid',
            guides: {bracketPairs: 'active'},
            padding: {top: 4},
        };
        return div().flex().sizeFull().bg(rgb(0x1e1e1e))
            .child(
                CityscapeEditor.component().model(model).context(context).options(leftOptions)
                    .onCreate(e -> left = e).flex1()
            )
            .child(div().w(px(1)).hFull().bg(rgb(0x3a3a3a)))
            .child(div().flex().flexCol().w(px(420)).hFull()
                .child(
                    CityscapeEditor.component().model(model).context(context).options(rightOptions)
                        .onCreate(e -> rightTop = e).flex1()
                )
                .child(div().h(px(1)).wFull().bg(rgb(0x3a3a3a)))
                .child(
                    CityscapeEditor.component().model(model).context(context).options(rightOptions)
                        .onCreate(e -> rightBottom = e).flex1()
                )
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
        frame++;
        if (left == null || rightTop == null || rightBottom == null || left.getView() == null || rightTop.getView() == null || rightBottom.getView() == null) {
            return false;
        }
        switch step {
            case 0:
                // right bottom: Cmd+D three times from a cursor in `item`
                focus(rightBottom, window, cx);
                rightBottom.setSelections([new Selection(14, 18, 14, 18)], 'visual');
                rightBottom.revealLineInCenter(18);
                for (i in 0...3) {
                    rightBottom.trigger('visual', 'editor.action.addSelectionToNextFindMatch', null);
                }
                step++;
                frame = 0;
                stepTime = haxe.Timer.stamp();
            case 1:
                if (elapsed() < 0.8) {
                    return false;
                }
                // left: scrolled into `cheapest`, the cursor in `result.push` (the
                // active bracket pair guides follow the primary cursor)
                focus(left, window, cx);
                left.setSelections([new Selection(22, 22, 22, 22)], 'visual');
                left.setScrollTop(20 * 22);
                step++;
                frame = 0;
                stepTime = haxe.Timer.stamp();
            case 2:
                if (elapsed() < 0.8) {
                    return false;
                }
                // right top, focused last: an explicit cursor move into `total`
                // (the word highlighter runs 50 ms after the move and renders 250 ms
                // after it; a cursor change of another editor of the context would
                // clear the highlights, like Monaco's global state)
                focus(rightTop, window, cx);
                @:privateAccess rightTop.widget.setSelections([new Selection(9, 10, 9, 10)], 'visual', CursorChangeReason.Explicit);
                step++;
                frame = 0;
                stepTime = haxe.Timer.stamp();
            case 3:
                if (elapsed() < 1.0) {
                    return false;
                }
                trace('editing scene: left sticky lines ' + cityscape.contrib.stickyScroll.view.StickyScrollController.get(@:privateAccess left.widget).stickyScrollWidget.lineNumbers
                    + ', right top text focus ' + @:privateAccess rightTop.widget.hasTextFocus()
                    + ', left widget focus ' + @:privateAccess left.widget.hasWidgetFocus());
                return true;
            case _:
                return true;
        }
        return false;
    }

}
