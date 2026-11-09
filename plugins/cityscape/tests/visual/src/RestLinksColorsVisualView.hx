// New code for Cityscape (not a port): the visual check of the links and
// the color decorators (contrib/links, contrib/colorPicker).
package;

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.contrib.colorPicker.view.ColorContributions.ColorContribution;
import cityscape.contrib.links.view.Links.LinkDetector;
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
 * Links and colors (`CITYSCAPE_VISUAL_SCENE=linkscolors`), one editor on a
 * Haxe model, VS Code's Dark+ theme (Light+ with
 * `CITYSCAPE_VISUAL_THEME=light`), the default link computer and the
 * default colors computer (`defaultColorDecorators: true`):
 * - the three links of the comments underlined (`detected-link`), the one
 *   of line 2 active as under Cmd (`detected-link-active`: underlined in
 *   `editorLink.activeForeground`, the pointer cursor);
 * - a swatch before each color of the theme table (`#ff0000`, `#3c8`,
 *   `rgb(...)`, `rgba(...)` with alpha, `hsl(...)`), in the color with a
 *   light border in the dark theme;
 * - the color picker open on `rgb(64, 128, 255)` (line 16), above it: the
 *   header (the picked color with its presentation `rgb(64, 128, 255)`, the
 *   original color on the right) and the kit's HSLA sliders.
 */
class RestLinksColorsVisualView extends Model implements Render {

    static final SAMPLE = [
        '// Theme of the demo: see https://code.visualstudio.com/api/references/theme-color',
        '// Colors are explained at https://developer.mozilla.org/docs/Web/CSS/color_value',
        '// (issues: http://example.com/issues?id=42)',
        'package demo;',
        '',
        'class DemoTheme {',
        '',
        '    // the table of the theme',
        '    public static final colors = [',
        '        "error" => "#ff0000",',
        '        "ok" => "#3c8",',
        '        "warning" => "hsl(40, 90%, 55%)",',
        '        "shadow" => "rgba(0, 0, 0, 0.35)",',
        '        "muted" => "#8a8a8a",',
        '        "accent" => "#c586c0",',
        '        "link" => "rgb(64, 128, 255)",',
        '    ];',
        '',
        '}',
    ].join('\n');

    final context:Cityscape;

    final model:TextModel;

    final dark:Bool;

    var editor:Null<CityscapeEditor> = null;

    var step:Int = 0;

    var stepTime:Float = 0;

    inline function elapsed():Float {
        return haxe.Timer.stamp() - stepTime;
    }

    public function new(cx:Context<RestLinksColorsVisualView>, dark:Bool) {
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
        // links open nowhere in the scene
        context.openLink = (uri, fromUserGesture) -> true;
        model = new TextModel(SAMPLE, 'haxe', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final options:cityscape.common.config.EditorOptions.IEditorOptions = {
            lineNumbers: 'on',
            fontSize: 14,
            lineHeight: 22,
            cursorBlinking: 'solid',
            padding: {top: 8},
            defaultColorDecorators: true,
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
                editor.setSelections([new Selection(5, 1, 5, 1)], 'visual');
                step++;
                stepTime = haxe.Timer.stamp();
            case 1:
                if (elapsed() < 0.5) {
                    return false;
                }
                final links = LinkDetector.get(widget);
                if (links != null) {
                    links._flushComputeLinks();
                }
                // Cmd (and Ctrl) held over the link of line 2: the active link
                final position = new Position(2, 40);
                final target = new MouseTarget(MouseTargetType.CONTENT_TEXT, position, 40, Range.fromPositions(position, position));
                final data = new EditorMouseEventData(false, false, false, true, false, false, true, 0);
                @:privateAccess widget._fireMouseMove(new EditorMouseEvent(data, target));
                // the color picker of `rgb(64, 128, 255)` (as a click on its swatch)
                final line = model.getLineContent(16);
                final column = line.indexOf('rgb(') + 1;
                ColorContribution.get(widget).showColorPicker(new Range(16, column + 1, 16, column + 1), true);
                step++;
                stepTime = haxe.Timer.stamp();
            case 2:
                if (elapsed() < 0.8) {
                    return false;
                }
                final colors = ColorContribution.get(widget);
                trace('links and colors scene: links ' + LinkDetector.get(widget).getLinkDecorations().length + ', color picker visible ' + colors.isColorPickerVisible);
                step++;
                return true;
            case _:
                return true;
        }
        return false;
    }

}
