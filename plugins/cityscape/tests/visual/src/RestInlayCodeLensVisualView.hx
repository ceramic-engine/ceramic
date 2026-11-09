// New code for Cityscape (not a port): the visual check of the inlay hints
// and the code lenses (step 7, cs7-rest-inlay).
package;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Event;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions.EditorOption;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.languages.LanguageKinds.InlayHintKind;
import cityscape.common.model.TextModel;
import cityscape.contrib.codelens.view.CodeLensController.CodeLensContribution;
import cityscape.contrib.hover.view.ContentHoverController;
import cityscape.contrib.inlayHints.view.InlayHintsController;
import cityscape.view.CityscapeView;
import cityscape.view.EditorBrowser;
import glaze.App;
import glaze.Context;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;

import glaze.Prelude.*;

/**
 * Type and parameter hints of the sample (the scene's own provider).
 */
private class SampleInlayHintsProvider implements InlayHintsProvider {

    public var displayName(default, null):Null<String> = 'visual';
    public var onDidChangeInlayHints(default, null):Null<VoidEvent> = null;
    public var resolveInlayHint(default, null):Null<(hint:InlayHint, token:CancellationToken, resolve:(hint:Null<InlayHint>) -> Void) -> Void> = null;

    final hints:Array<InlayHint>;

    public function new(hints:Array<InlayHint>) {
        this.hints = hints;
    }

    public function provideInlayHints(model:ITextModel, range:Range, token:CancellationToken, resolve:(hints:Null<InlayHintList>) -> Void):Void {
        resolve({hints: [for (h in hints) if (range.containsPosition(Position.lift(h.position))) h]});
    }

}

/**
 * `3 references` and `Run` above the functions `main` and `discount`,
 * resolved later (the scene's own provider).
 */
private class SampleCodeLensProvider implements CodeLensProvider {

    public var onDidChange(default, null):Null<Event<CodeLensProvider>> = null;
    public var resolveCodeLens(default, null):Null<(model:ITextModel, codeLens:CodeLens, token:CancellationToken, resolve:(codeLens:Null<CodeLens>) -> Void) -> Void>;

    final lines:Array<Int>;

    public function new(lines:Array<Int>) {
        this.lines = lines;
        this.resolveCodeLens = (model, codeLens, token, resolve) -> {
            resolve({
                range: codeLens.range,
                id: codeLens.id,
                command: codeLens.id == 'run' ? {id: 'visual.run', title: "$(play) Run"} : {id: 'visual.references', title: '3 references'}
            });
        };
    }

    public function provideCodeLenses(model:ITextModel, token:CancellationToken, resolve:(lenses:Null<CodeLensList>) -> Void):Void {
        final lenses:Array<CodeLens> = [];
        for (line in lines) {
            final column = model.getLineFirstNonWhitespaceColumn(line);
            lenses.push({range: new Range(line, column, line, column + 6), id: 'refs'});
            lenses.push({range: new Range(line, column, line, column + 6), id: 'run'});
        }
        resolve({lenses: lenses});
    }

}

/**
 * The inlay hints and code lenses (`CITYSCAPE_VISUAL_SCENE=inlay`), one
 * editor on a Haxe model, VS Code's Dark+ theme (Light+ with
 * `CITYSCAPE_VISUAL_THEME=light`), `inlayHints.padding` on:
 * - code lenses `3 references | Run` above `main` (line 5) and `discount`
 *   (line 14), in `editorCodeLens.foreground` at 90% of the font size;
 * - type hints (`: Float`, `: Array<Item>`) after `total` and `items`, and
 *   parameter hints (`path:`, `cached:`, `price:`, `rate:`) before the
 *   arguments, on their rounded backgrounds;
 * - the hover of the `path:` hint open (its tooltip and "Go to Definition
 *   (cmd + click)").
 */
class RestInlayCodeLensVisualView extends Model implements Render {

    static final LINES = [
        'package demo;',
        '',
        'class Pricing {',
        '',
        '    public static function main() {',
        '        var total = 0.0;',
        '        final items = load("stock.json", true);',
        '        for (item in items) {',
        '            total += discount(item.price, 0.1);',
        '        }',
        '        trace(total);',
        '    }',
        '',
        '    static function discount(price:Float, rate:Float):Float {',
        '        return price * (1 - rate);',
        '    }',
        '',
        '    static function load(path:String, cached:Bool):Array<Item> {',
        '        return [];',
        '    }',
        '',
        '}',
    ];

    final context:Cityscape;

    final model:TextModel;

    final dark:Bool;

    var editor:Null<CityscapeEditor> = null;

    var step:Int = 0;

    var stepTime:Float = 0;

    inline function elapsed():Float {
        return haxe.Timer.stamp() - stepTime;
    }

    /**
     * The model position of a text of the sample (1 based column of the
     * start of `text`, or after it when `after` is true).
     */
    static function at(lineNumber:Int, text:String, after:Bool = false):IPosition {
        final index = LINES[lineNumber - 1].indexOf(text);
        return {lineNumber: lineNumber, column: index + 1 + (after ? text.length : 0)};
    }

    public function new(cx:Context<RestInlayCodeLensVisualView>, dark:Bool) {
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
        model = new TextModel(LINES.join('\n'), 'haxe', TextModel.DEFAULT_CREATION_OPTIONS, null, context);

        final loadDecl:Location = {uri: model.uri, range: new Range(18, 26, 18, 30)};
        context.registerInlayHintsProvider('haxe', new SampleInlayHintsProvider([
            {label: ': Float', position: at(6, 'total', true), kind: InlayHintKind.Type},
            {label: ': Array<Item>', position: at(7, 'items', true), kind: InlayHintKind.Type},
            {label: [{label: 'path', location: loadDecl, tooltip: 'The path of the stock file'}, {label: ':'}], position: at(7, '"stock'), kind: InlayHintKind.Parameter, paddingRight: true},
            {label: 'cached:', position: at(7, 'true'), kind: InlayHintKind.Parameter, paddingRight: true},
            {label: 'price:', position: at(9, 'item.price'), kind: InlayHintKind.Parameter, paddingRight: true},
            {label: 'rate:', position: at(9, '0.1'), kind: InlayHintKind.Parameter, paddingRight: true},
        ]));
        context.registerCodeLensProvider('haxe', new SampleCodeLensProvider([5, 14]));
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final options:cityscape.common.config.EditorOptions.IEditorOptions = {
            lineNumbers: 'on',
            fontSize: 14,
            lineHeight: 22,
            cursorBlinking: 'solid',
            padding: {top: 8},
            inlayHints: {padding: true},
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
                editor.setSelections([new Selection(11, 9, 11, 9)], 'visual');
                step++;
                stepTime = haxe.Timer.stamp();
            case 1:
                // the requests of the hints and lenses, then their resolution
                final hints = InlayHintsController.get(widget);
                final lenses = CodeLensContribution.get(widget);
                if (hints == null || lenses == null) {
                    return false;
                }
                hints._flush();
                lenses._flush();
                lenses._flush();
                widget.render();
                step++;
                stepTime = haxe.Timer.stamp();
            case 2:
                if (elapsed() < 0.5) {
                    return false;
                }
                // the mouse over the `path:` hint: its hover (Monaco shows it
                // after the hover delay)
                final view:CityscapeView = editor.getView();
                final viewModel = view.viewModel;
                final viewLine = viewModel.coordinatesConverter.convertModelPositionToViewPosition(new Position(7, 1)).lineNumber;
                final content = viewModel.getLineContent(viewLine);
                final column = content.indexOf('path') + 2;
                final layoutInfo = widget.getOption(EditorOption.layoutInfo);
                final x = view.elementBounds.origin.x + layoutInfo.contentLeft + view.renderViewLine(viewLine).columnToX(column) - widget.getScrollLeft() + 2;
                final y = view.elementBounds.origin.y + widget.getTopForLineNumber(7) - widget.getScrollTop() + widget.getOption(EditorOption.lineHeight) / 2;
                final target = view.mouseTargetAt(new glaze.Point(x, y));
                final event = new EditorMouseEvent(new EditorMouseEventData(false, false, false, false, false, false, false, 0, x, y), target);
                @:privateAccess widget._fireMouseMove(event);
                step++;
                stepTime = haxe.Timer.stamp();
            case 3:
                if (elapsed() < 1.2) {
                    return false;
                }
                final hover = ContentHoverController.get(widget);
                trace('inlay scene: ' + CodeLensContribution.get(widget).getLenses().length + ' lens lines, hover visible ' + hover.isHoverVisible);
                step++;
                return true;
            case _:
                return true;
        }
        return false;
    }

}
