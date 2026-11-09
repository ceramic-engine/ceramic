// New code for Cityscape (not a port): tests of StandaloneThemeService
// (vscode has no test of standaloneThemeService.ts).
package tests.standalone;

import cityscape.base.common.Color;
import cityscape.common.Languages.ITokenizationSupport;
import cityscape.common.TokenizationRegistry;
import cityscape.common.EncodedTokenAttributes.TokenMetadata;
import cityscape.platform.theme.common.Theme.ColorScheme;
import cityscape.standalone.StandaloneThemeService;
import cityscape.standalone.common.StandaloneTheme.IStandaloneTheme;
import cityscape.standalone.common.Themes;
import testing.TestCase;

/**
 * Expected colors are the values of vscode's themes.ts (built-in theme data)
 * and of the color registrations (editorColors.ts, editorColorRegistry.ts,
 * baseColors.ts).
 */
class StandaloneThemeServiceTest extends TestCase {

    static function hex(color:Null<Color>):String {
        return color == null ? 'undefined' : ColorFormatCSS.formatHexA(color, true);
    }

    static function colorMapToString(colorMap:Null<Array<Color>>):String {
        if (colorMap == null) {
            return 'null';
        }
        return [for (c in colorMap) c == null ? 'undefined' : ColorFormatCSS.formatHexA(c)].join(',');
    }

    function testDefaultThemeIsVs() {
        final registry = new TokenizationRegistry<ITokenizationSupport>();
        final service = new StandaloneThemeService(registry);
        final theme = service.getColorTheme();
        assertEquals('vs', theme.themeName);
        assertEquals('vs', theme.label);
        assertEquals(ColorScheme.LIGHT, theme.type);
        assertNotNull(registry.getColorMap());
        assertEquals(colorMapToString(theme.tokenTheme.getColorMap()), colorMapToString(registry.getColorMap()));
        // themes.ts: vs defines token defaults 000000 on fffffe
        assertEquals('#000000', hex(registry.getColorMap()[1]));
        assertEquals('#fffffe', hex(registry.getColorMap()[2]));
        service.dispose();
    }

    function testGetColorResolvesThemeColorsAndDefaults() {
        final registry = new TokenizationRegistry<ITokenizationSupport>();
        final service = new StandaloneThemeService(registry);

        // vs: theme colors (themes.ts)
        var theme = service.getColorTheme();
        assertEquals('#fffffe', hex(theme.getColor('editor.background')));
        assertEquals('#000000', hex(theme.getColor('editor.foreground')));
        assertTrue(theme.defines('editor.background'));
        // vs: registry defaults (editorColorRegistry.ts: light Color.black, '#237893')
        assertFalse(theme.defines('editorCursor.foreground'));
        assertEquals('#000000', hex(theme.getColor('editorCursor.foreground')));
        assertEquals('#237893', hex(theme.getColor('editorLineNumber.foreground')));
        assertNull(theme.getColor('editorCursor.foreground', false));
        // editorGutter.background defaults to editor.background
        assertEquals('#fffffe', hex(theme.getColor('editorGutter.background')));
        // no default: editor.lineHighlightBackground is registered with null
        assertNull(theme.getColor('editor.lineHighlightBackground'));
        // unknown color
        assertNull(theme.getColor('unknown.color'));

        service.setTheme('vs-dark');
        theme = service.getColorTheme();
        assertEquals(ColorScheme.DARK, theme.type);
        assertEquals('#1e1e1e', hex(theme.getColor('editor.background')));
        assertEquals('#d4d4d4', hex(theme.getColor('editor.foreground')));
        assertEquals('#aeafad', hex(theme.getColor('editorCursor.foreground')));
        assertEquals('#858585', hex(theme.getColor('editorLineNumber.foreground')));
        assertEquals('#1e1e1e', hex(theme.getColor('editorGutter.background')));
        // editorWidget.foreground defaults to foreground (baseColors.ts dark '#CCCCCC')
        assertEquals('#cccccc', hex(theme.getColor('editorWidget.foreground')));
        // descriptionForeground: transparent(foreground, 0.7)
        assertEquals('rgba(204, 204, 204, 0.7)', Std.string(theme.getColor('descriptionForeground')));

        service.setTheme('hc-black');
        theme = service.getColorTheme();
        assertEquals(ColorScheme.HIGH_CONTRAST_DARK, theme.type);
        assertEquals('#000000', hex(theme.getColor('editor.background')));
        assertEquals('#ffffff', hex(theme.getColor('editorCursor.foreground')));

        service.setTheme('hc-light');
        theme = service.getColorTheme();
        assertEquals(ColorScheme.HIGH_CONTRAST_LIGHT, theme.type);
        assertEquals('#ffffff', hex(theme.getColor('editor.background')));
        assertEquals('#0f4a85', hex(theme.getColor('editorCursor.foreground')));

        service.dispose();
    }

    function testDefineAndSetThemeFiresAndSetsColorMap() {
        final registry = new TokenizationRegistry<ITokenizationSupport>();
        final service = new StandaloneThemeService(registry);
        final fired:Array<IStandaloneTheme> = [];
        service.onDidColorThemeChange(theme -> fired.push(theme));
        var registryChanges = 0;
        registry.onDidChange(e -> {
            if (e.changedColorMap) {
                registryChanges++;
            }
        });

        service.defineTheme('my-Theme1', {
            base: 'vs-dark',
            inherit: true,
            rules: [{token: 'comment', foreground: 'ff0000', fontStyle: 'italic'}],
            colors: {'editor.background': '#123456'}
        });
        // defining a theme that is not the current one does not fire
        assertEquals(0, fired.length);

        service.setTheme('my-Theme1');
        assertEquals(1, fired.length);
        final theme = fired[0];
        assertTrue(theme == service.getColorTheme());
        assertEquals('my-Theme1', theme.themeName);
        assertEquals(ColorScheme.DARK, theme.type);
        assertTrue(registryChanges > 0);
        assertEquals(colorMapToString(theme.tokenTheme.getColorMap()), colorMapToString(registry.getColorMap()));

        // own color, inherited color, default
        assertEquals('#123456', hex(theme.getColor('editor.background')));
        assertEquals('#d4d4d4', hex(theme.getColor('editor.foreground')));
        assertEquals('#aeafad', hex(theme.getColor('editorCursor.foreground')));

        // token theme: the editor background becomes the default token background
        final colorMap = registry.getColorMap();
        final metadata = theme.tokenTheme.match(0, 'comment.line');
        assertEquals('#ff0000', hex(colorMap[TokenMetadata.getForeground(metadata)]));
        assertEquals('#123456', hex(colorMap[TokenMetadata.getBackground(metadata)]));
        assertEquals(1, (TokenMetadata.getFontStyle(metadata) : Int));
        final keyword = theme.tokenTheme.match(0, 'keyword');
        assertEquals('#569cd6', hex(colorMap[TokenMetadata.getForeground(keyword)]));

        // setting the same theme again does nothing
        service.setTheme('my-Theme1');
        assertEquals(1, fired.length);

        // redefining the current theme refreshes it
        service.defineTheme('my-Theme1', {
            base: 'vs',
            inherit: false,
            rules: [],
            colors: {}
        });
        assertEquals(2, fired.length);
        assertEquals(ColorScheme.LIGHT, service.getColorTheme().type);

        // unknown theme falls back to vs
        service.setTheme('not-defined');
        assertEquals(3, fired.length);
        assertEquals('vs', service.getColorTheme().themeName);

        service.dispose();
    }

    function testDefineThemeValidation() {
        final registry = new TokenizationRegistry<ITokenizationSupport>();
        final service = new StandaloneThemeService(registry);
        assertRaises(() -> service.defineTheme('my theme', {base: 'vs', inherit: true, rules: [], colors: {}}));
        assertRaises(() -> service.defineTheme('my.theme', {base: 'vs', inherit: true, rules: [], colors: {}}));
        assertRaises(() -> service.defineTheme('mytheme', {base: 'monokai', inherit: true, rules: [], colors: {}}));
        // a built-in name can be redefined with any base
        service.defineTheme('vs', {base: 'monokai', inherit: false, rules: [], colors: {}});
        service.dispose();
    }

    function testInheritedThemesDoNotChangeBuiltinData() {
        final rulesCount = Themes.vs_dark.rules.length;
        final registry = new TokenizationRegistry<ITokenizationSupport>();
        final service = new StandaloneThemeService(registry);
        service.defineTheme('a', {base: 'vs-dark', inherit: true, rules: [], colors: {'editor.foreground': '#111111', 'editor.background': '#222222'}});
        service.defineTheme('b', {base: 'vs-dark', inherit: true, rules: [], colors: {'editor.foreground': '#333333'}});
        service.setTheme('a');
        service.setTheme('b');
        assertEquals(rulesCount, Themes.vs_dark.rules.length);
        // b's token background is vs-dark's, not a's
        final theme = service.getColorTheme();
        final metadata = theme.tokenTheme.match(0, 'source');
        assertEquals('#1e1e1e', hex(theme.tokenTheme.getColorMap()[TokenMetadata.getBackground(metadata)]));
        assertEquals('#333333', hex(theme.tokenTheme.getColorMap()[TokenMetadata.getForeground(metadata)]));
        service.dispose();
    }

    function testSetColorMapOverride() {
        final registry = new TokenizationRegistry<ITokenizationSupport>();
        final service = new StandaloneThemeService(registry);
        var fired = 0;
        service.onDidColorThemeChange(_ -> fired++);
        final colorMapOverride = [null, Color.fromHex('#010203'), Color.fromHex('#040506')];
        service.setColorMapOverride(colorMapOverride);
        assertEquals(1, fired);
        assertTrue(registry.getColorMap() == colorMapOverride);
        service.setTheme('vs-dark');
        assertTrue(registry.getColorMap() == colorMapOverride);
        service.setColorMapOverride(null);
        assertEquals(colorMapToString(service.getColorTheme().tokenTheme.getColorMap()), colorMapToString(registry.getColorMap()));
        service.dispose();
    }

    function testTwoServicesAreIndependent() {
        final registry1 = new TokenizationRegistry<ITokenizationSupport>();
        final registry2 = new TokenizationRegistry<ITokenizationSupport>();
        final service1 = new StandaloneThemeService(registry1);
        final service2 = new StandaloneThemeService(registry2);

        var fired2 = 0;
        service2.onDidColorThemeChange(_ -> fired2++);

        service1.defineTheme('custom', {base: 'vs-dark', inherit: true, rules: [], colors: {'editor.background': '#101010'}});
        service1.setTheme('custom');

        assertEquals('custom', service1.getColorTheme().themeName);
        assertEquals('vs', service2.getColorTheme().themeName);
        assertEquals(0, fired2);
        assertEquals('#fffffe', hex(registry2.getColorMap()[2]));
        assertEquals(colorMapToString(service1.getColorTheme().tokenTheme.getColorMap()), colorMapToString(registry1.getColorMap()));

        // the theme name is unknown to the second service
        service2.setTheme('custom');
        assertEquals('vs', service2.getColorTheme().themeName);
        assertEquals('#fffffe', hex(service2.getColorTheme().getColor('editor.background')));

        service1.dispose();
        service2.dispose();
    }

}
