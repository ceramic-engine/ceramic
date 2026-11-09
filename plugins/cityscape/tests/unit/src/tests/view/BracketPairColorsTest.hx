// New code for Cityscape (not a port): the colors of the bracket pairs and
// of the guides, as the theming participants of Monaco's CSS give them
// (bracketPairColorization in the editor's theming, indentGuides.ts).
package tests.view;

import cityscape.Cityscape;
import cityscape.common.core.Range;
import cityscape.view.DecorationStyleResolver;
import cityscape.view.ViewTheme;
import cityscape.view.viewParts.indentGuides.IndentGuides;
import testing.TestCase;
import testing.TestCodeEditor;
import tests.TestTextModel;

class BracketPairColorsTest extends TestCase {

    static function hex(c:Null<glaze.Hsla>):String {
        if (c == null) {
            return 'null';
        }
        final rgba = c.toRgb();
        inline function h(v:Float):String {
            return StringTools.hex(Math.round(v * 255), 2);
        }
        return '#' + h(rgba.r) + h(rgba.g) + h(rgba.b) + (rgba.a < 1 ? h(rgba.a) : '');
    }

    static function contextWithBrackets():Cityscape {
        final context = new Cityscape();
        context.languageService.registerLanguage({id: 'brackets'});
        context.languageConfigurationService.register('brackets', {
            brackets: [['{', '}'], ['[', ']'], ['(', ')']]
        });
        return context;
    }

    function testBracketDecorationsInTheViewport() {
        final context = contextWithBrackets();
        final model = TestTextModel.instantiateTextModel(context, 'a(b[c{d}e]f)g)', 'brackets');
        final editor = new TestCodeEditor(context, model, {});
        final viewModel = editor.getViewModel();
        final names:Array<String> = [];
        for (d in viewModel.getDecorationsInViewport(new Range(1, 1, 1, 15))) {
            final name = d.options.inlineClassName;
            if (name != null && (StringTools.startsWith(name, 'bracket-highlighting-') || name == 'unexpected-closing-bracket')) {
                names.push(d.range.startColumn + ':' + name);
            }
        }
        names.sort((a, b) -> Std.parseInt(a.split(':')[0]) - Std.parseInt(b.split(':')[0]));
        assertEquals('2:bracket-highlighting-0,4:bracket-highlighting-1,6:bracket-highlighting-2,8:bracket-highlighting-2,10:bracket-highlighting-1,12:bracket-highlighting-0,14:unexpected-closing-bracket', names.join(','));
        editor.dispose();
        model.dispose();
    }

    /**
     * Regression: the TextMate grammars registered without
     * `balancedBracketSelectors` gave tokens without the balanced brackets
     * bit, so no bracket was found (VS Code's default is `['*']`).
     */
    function testBracketDecorationsWithTextMateTokens() {
        final context = new Cityscape();
        context.languageService.registerLanguage({id: 'haxe', extensions: ['.hx']});
        context.textMate.registerGrammar({languageId: 'haxe', grammar: testing.MonacoTruth.loadGlazeGrammar('haxe.json'), path: 'haxe.json'});
        context.languageConfigurationService.register('haxe', {
            brackets: [['{', '}'], ['[', ']'], ['(', ')']]
        });
        final model = new cityscape.common.model.TextModel('class A {\n    function f(x:Array<Int>) { return x[0]; }\n}', 'haxe', cityscape.common.model.TextModel.DEFAULT_CREATION_OPTIONS, null, context);
        final editor = new TestCodeEditor(context, model, {});
        model.tokenization.forceTokenization(model.getLineCount());
        final viewModel = editor.getViewModel();
        final names:Array<String> = [];
        for (d in viewModel.getDecorationsInViewport(new Range(1, 1, 3, 2))) {
            final name = d.options.inlineClassName;
            if (name != null && StringTools.startsWith(name, 'bracket-highlighting-')) {
                names.push(d.range.startLineNumber + ':' + d.range.startColumn + ':' + name.substr('bracket-highlighting-'.length));
            }
        }
        names.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        assertEquals('1:9:0,2:15:1,2:28:1,2:30:1,2:40:2,2:42:2,2:45:1,3:1:0', names.join(','));
        editor.dispose();
        model.dispose();
    }

    function testBracketColorsOfTheTheme() {
        final context = new Cityscape();
        context.themeService.setTheme('vs-dark');
        final theme = new ViewTheme(context.themeService, context.tokenizationRegistry);
        final resolver = new DecorationStyleResolver(theme, context.decorationStyles);
        // three non transparent colors in Monaco's dark defaults: the levels cycle through them
        assertEquals('#FFD700', hex(resolver.resolve('mtk1 bracket-highlighting-0').color));
        assertEquals('#DA70D6', hex(resolver.resolve('mtk1 bracket-highlighting-1').color));
        assertEquals('#179FFF', hex(resolver.resolve('mtk1 bracket-highlighting-2').color));
        assertEquals('#FFD700', hex(resolver.resolve('mtk1 bracket-highlighting-3').color));
        assertEquals('#FF1212CC', hex(resolver.resolve('mtk1 unexpected-closing-bracket').color));

        context.themeService.setTheme('vs');
        assertEquals('#0431FA', hex(resolver.resolve('mtk1 bracket-highlighting-0').color));
        theme.dispose();
    }

    function testGuideColorsOfTheTheme() {
        final context = new Cityscape();
        context.themeService.setTheme('vs-dark');
        final theme = new ViewTheme(context.themeService, context.tokenizationRegistry);
        final colors = new IndentGuideColors(theme);
        // bracket pair guides: the bracket colors, 30% opaque when inactive
        assertEquals('#FFD7004D', hex(colors.colorOf(colors.styleOf('bracket-indent-guide lvl-0'))));
        assertEquals('#FFD700', hex(colors.colorOf(colors.styleOf('bracket-indent-guide lvl-0 indent-active'))));
        assertEquals('#DA70D64D', hex(colors.colorOf(colors.styleOf('bracket-indent-guide lvl-4'))));
        // indentation guides: editorIndentGuide.background1 and activeBackground1
        assertEquals('#404040', hex(colors.colorOf(colors.styleOf('core-guide-indent lvl-0'))));
        assertEquals('#707070', hex(colors.colorOf(colors.styleOf('core-guide-indent lvl-0 indent-active'))));
        theme.dispose();
    }

}
