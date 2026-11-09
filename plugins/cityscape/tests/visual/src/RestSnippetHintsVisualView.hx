// New code for Cityscape (not a port): the visual check of the parameter
// hints and of an active snippet (step 7, cs7-rest-snip).
package;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.contrib.parameterHints.view.ParameterHints;
import cityscape.contrib.snippet.view.SnippetController2;
import cityscape.view.CityscapeView;
import glaze.App;
import glaze.Context;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;

import glaze.Prelude.*;

/**
 * The signature help of `clamp` (the scene's own provider): two
 * overloads, the active parameter counted from the commas before the
 * cursor.
 */
private class ClampSignatureHelpProvider implements SignatureHelpProvider {

    public var signatureHelpTriggerCharacters(default, null):Null<Array<String>> = ['('];
    public var signatureHelpRetriggerCharacters(default, null):Null<Array<String>> = [','];

    public function new() {}

    public function provideSignatureHelp(model:ITextModel, position:Position, token:CancellationToken, context:SignatureHelpContext, resolve:(result:Null<SignatureHelpResult>) -> Void):Void {
        final before = model.getLineContent(position.lineNumber).substring(0, position.column - 1);
        final open = before.lastIndexOf('clamp(');
        if (open < 0) {
            resolve(null);
            return;
        }
        final activeParameter = before.substring(open + 6).split(',').length - 1;
        resolve({
            value: {
                signatures: [{
                    label: 'clamp(value:Float, min:Float, max:Float):Float',
                    documentation: ({value: 'Returns `value` limited to **[min, max]**.'} : cityscape.base.common.HtmlContent.IMarkdownString),
                    parameters: [
                        {label: 'value:Float', documentation: 'The value to clamp.'},
                        {label: 'min:Float', documentation: 'The lower bound.'},
                        {label: 'max:Float', documentation: 'The upper bound.'}
                    ]
                }, {
                    label: 'clamp(value:Float, range:Range):Float',
                    parameters: [
                        {label: 'value:Float'},
                        {label: 'range:Range'}
                    ]
                }],
                activeSignature: 0,
                activeParameter: activeParameter
            },
            dispose: () -> {}
        });
    }

}

/**
 * The parameter hints and an active snippet (not registered in
 * `MainScene`: the coordinator wires it), one editor on a Haxe model,
 * VS Code's Dark+ theme (Light+ with `CITYSCAPE_VISUAL_THEME=light`):
 * the snippet `clamp(${1:value}, ${2:0.0}, ${3:1.0})$0` inserted at the end
 * of `final ratio = `, moved to its second tab stop (Tab): `0.0` selected
 * in its active placeholder box, `value` and `1.0` in inactive placeholder
 * boxes (`editor.snippetTabstopHighlightBackground`), the final tab stop
 * after `)` a thin box (`editor.snippetFinalTabstopHighlightBorder`); the
 * parameter hints open above the line (Cmd+Shift+Space): the overload
 * counter `1/2` with its chevrons on the left, the signature
 * `clamp(value:Float, min:Float, max:Float):Float` in the editor's font
 * with `min:Float` in bold and `editorHoverWidget.highlightForeground`,
 * then under a line the documentation of `min` ("The lower bound.") and of
 * the signature (markdown, `value` as inline code and **[min, max]** bold).
 */
class RestSnippetHintsVisualView extends Model implements Render {

    static final SAMPLE = [
        'package demo;',
        '',
        'class Gauge {',
        '',
        '    var level:Float = 0.0;',
        '',
        '    public function new() {}',
        '',
        '    public function clamp(value:Float, min:Float, max:Float):Float {',
        '        return value < min ? min : (value > max ? max : value);',
        '    }',
        '',
        '    public function update(raw:Float):Void {',
        '        final ratio = ',
        '        level = ratio;',
        '    }',
        '',
        '}',
    ].join('\n');

    static inline final LINE = 14;

    final context:Cityscape;

    final model:TextModel;

    final dark:Bool;

    var editor:Null<CityscapeEditor> = null;

    var step:Int = 0;

    var stepTime:Float = 0;

    inline function elapsed():Float {
        return haxe.Timer.stamp() - stepTime;
    }

    public function new(cx:Context<RestSnippetHintsVisualView>, dark:Bool) {
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
        context.registerSignatureHelpProvider('haxe', new ClampSignatureHelpProvider());
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
                glaze.kit.theme.Theme.setMode(dark ? glaze.kit.theme.ThemeMode.Dark : glaze.kit.theme.ThemeMode.Light, cx);
                focus(editor, window, cx);
                final column = model.getLineMaxColumn(LINE);
                editor.setSelections([new Selection(LINE, column, LINE, column)], 'visual');
                step++;
                stepTime = haxe.Timer.stamp();
            case 1:
                if (elapsed() < 0.3) {
                    return false;
                }
                // the snippet, then Tab to its second tab stop
                final snippets = SnippetController2.get(widget);
                snippets.insert("clamp(${1:value}, ${2:0.0}, ${3:1.0})$0");
                snippets.next();
                // Cmd+Shift+Space (editor.action.triggerParameterHints)
                ParameterHintsController.get(widget).trigger({triggerKind: SignatureHelpTriggerKind.Invoke});
                step++;
                stepTime = haxe.Timer.stamp();
            case 2:
                if (elapsed() < 0.8) {
                    return false;
                }
                final hints = ParameterHintsController.get(widget).getWidget();
                final content = hints != null ? hints.getContent() : null;
                trace('snippet hints scene: in snippet ' + SnippetController2.get(widget).isInSnippet()
                    + ', hints visible ' + (hints != null && hints.isVisible)
                    + ', active parameter ' + (content != null ? content.active() : 'none')
                    + ', placement ' + (hints != null && hints.bounds != null ? Std.string(hints.positionPreference) : 'none'));
                step++;
                return true;
            case _:
                return true;
        }
        return false;
    }

}
