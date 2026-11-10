// New code for Cityscape (not a port): the codicon outlines and the colors
// of the symbol codicons. The expected glyphs and colors come from Monaco
// 0.52.2: codicon.ttf (via codiconsLibrary.ts, the ids and their glyphs),
// symbolIcons.ts and symbolIcons.css.
package tests.view;

import cityscape.Cityscape;
import cityscape.common.languages.CompletionItemKind;
import cityscape.contrib.symbolIcons.view.SymbolIcons.SymbolIconColors;
import cityscape.view.CodiconOutlines;
import cityscape.view.Codicons;
import testing.TestCase;

class CodiconsTest extends TestCase {

    /**
     * Every kind of the suggest widget has its own codicon outline; the
     * kinds Monaco shows with distinct glyphs are distinct.
     */
    function testCompletionKindsHaveOutlines() {
        for (k in 0...28) {
            final id = CompletionItemKinds.toIcon(k);
            assertNotNull(CodiconOutlines.pathOf(id), id);
            assertNotNull(Codicons.svg(id), id);
        }
        final method = CodiconOutlines.pathOf(CompletionItemKinds.toIcon(CompletionItemKind.Method));
        final field = CodiconOutlines.pathOf(CompletionItemKinds.toIcon(CompletionItemKind.Field));
        final variable = CodiconOutlines.pathOf(CompletionItemKinds.toIcon(CompletionItemKind.Variable));
        final property = CodiconOutlines.pathOf(CompletionItemKinds.toIcon(CompletionItemKind.Property));
        final keyword = CodiconOutlines.pathOf(CompletionItemKinds.toIcon(CompletionItemKind.Keyword));
        final snippet = CodiconOutlines.pathOf(CompletionItemKinds.toIcon(CompletionItemKind.Snippet));
        final all = [method, field, variable, property, keyword, snippet];
        for (i in 0...all.length) {
            for (j in i + 1...all.length) {
                assertTrue(all[i] != all[j], '$i $j');
            }
        }
        // methods, functions and constructors share symbol-method's glyph
        // (U+EA8C)
        assertEquals(method, CodiconOutlines.pathOf('symbol-function'));
        assertEquals(method, CodiconOutlines.pathOf('symbol-constructor'));
        // run is play
        assertEquals(CodiconOutlines.pathOf('play'), CodiconOutlines.pathOf('run'));
        for (id in ['play', 'debug-start', 'references', 'check', 'error', 'warning', 'info', 'lightbulb', 'gear', 'link']) {
            assertNotNull(CodiconOutlines.pathOf(id), id);
        }
        assertNull(CodiconOutlines.pathOf('no-such-codicon'));
        assertNull(Codicons.svg('no-such-codicon'));
        // add (U+EA60) as in codicon.ttf, like Codicons.DIFF_INSERT_PATH
        assertEquals(Codicons.DIFF_INSERT_PATH, CodiconOutlines.pathOf('add'));
    }

    /**
     * symbolIcons.ts: the registered defaults (dark and light), the
     * `foreground` ones following the theme's foreground.
     */
    function testSymbolIconColors() {
        final context = new Cityscape();
        final hex = (id:String) -> {
            final c = context.themeService.getColorTheme().getColor(id);
            return c == null ? null : c.toString();
        };
        context.themeService.setTheme('vs-dark');
        assertEquals('#b180d7', hex(SymbolIconColors.colorOf('symbol-method')));
        assertEquals('#b180d7', hex(SymbolIconColors.colorOf('symbol-function')));
        assertEquals('#75beff', hex(SymbolIconColors.colorOf('symbol-field')));
        assertEquals('#75beff', hex(SymbolIconColors.colorOf('symbol-variable')));
        assertEquals('#ee9d28', hex(SymbolIconColors.colorOf('symbol-class')));
        assertEquals('#ee9d28', hex(SymbolIconColors.colorOf('symbol-value')));
        assertEquals('#cccccc', hex(SymbolIconColors.colorOf('symbol-keyword')));
        assertEquals('#cccccc', hex(SymbolIconColors.colorOf('symbol-property')));
        context.themeService.setTheme('vs');
        assertEquals('#652d90', hex(SymbolIconColors.colorOf('symbol-method')));
        assertEquals('#007acc', hex(SymbolIconColors.colorOf('symbol-field')));
        assertEquals('#d67e00', hex(SymbolIconColors.colorOf('symbol-enum')));
        assertEquals('#616161', hex(SymbolIconColors.colorOf('symbol-snippet')));
        // a theme color wins
        context.themeService.defineTheme('mine', {base: 'vs-dark', inherit: true, rules: [], colors: {'symbolIcon.keywordForeground': '#ff0000'}});
        context.themeService.setTheme('mine');
        assertEquals('#ff0000', hex(SymbolIconColors.colorOf('symbol-keyword')));
        // not a symbol codicon
        assertNull(SymbolIconColors.colorOf('play'));
    }

}
