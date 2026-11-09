// New code for Cityscape (not a port): tests of the color registry
// (vscode has no test of colorUtils.ts / colorRegistry.ts).
package tests.theme;

import cityscape.base.common.Color;
import cityscape.common.core.EditorColorRegistry;
import cityscape.platform.theme.common.ColorUtils;
import cityscape.platform.theme.common.Theme.ColorScheme;
import cityscape.platform.theme.common.ThemeService.IColorTheme;
import cityscape.platform.theme.common.ThemeService.ITokenStyle;
import cityscape.platform.theme.common.colors.BaseColors;
import cityscape.platform.theme.common.colors.EditorColors;
import cityscape.platform.theme.common.colors.MinimapColors;
import testing.TestCase;

/**
 * Expected values come from the registrations of vscode's colors/*.ts and
 * editorColorRegistry.ts (ids and defaults) and from the definitions of the
 * transforms in colorUtils.ts.
 */
class ColorRegistryTest extends TestCase {

    function testAllColorsAreRegistered() {
        final colors = ColorUtils.getColorRegistry().getColors();
        // 297 registerColor calls in baseColors, editorColors, inputColors,
        // listColors, menuColors, minimapColors, miscColors, quickpickColors,
        // searchColors and editorColorRegistry, all with distinct ids, and
        // the 3 of the folding contribution (foldingDecorations.ts) and the
        // 3 of the diff editor (registrations.contribution.ts)
        assertEquals(297 + 3 + 3, colors.length);
        final ids = new Map<String, Bool>();
        for (c in colors) {
            ids.set(c.id, true);
        }
        assertTrue(ids.exists('foreground'));
        assertTrue(ids.exists('editor.background'));
        assertTrue(ids.exists('editorCursor.foreground'));
        assertTrue(ids.exists('minimap.background'));
        assertTrue(ids.exists('editorIndentGuide.background1'));
        assertTrue(ids.exists('editor.foldBackground'));
        assertTrue(ids.exists('editor.foldPlaceholderForeground'));
        assertTrue(ids.exists('editorGutter.foldingControlForeground'));
        assertTrue(ids.exists('diffEditor.move.border'));
        assertTrue(ids.exists('diffEditor.moveActive.border'));
        assertTrue(ids.exists('diffEditor.unchangedRegionShadow'));
        assertEquals('editor.background', EditorColors.editorBackground);
        assertEquals('minimap.background', MinimapColors.minimapBackground);
        assertEquals('editorIndentGuide.activeBackground1', EditorColorRegistry.editorActiveIndentGuide1);
        assertEquals('contrastActiveBorder', BaseColors.activeContrastBorder);
    }

    function testDeprecatedAndTransparency() {
        var deprecated:Null<String> = null;
        var needsTransparency = false;
        for (c in ColorUtils.getColorRegistry().getColors()) {
            if (c.id == 'editorIndentGuide.background') {
                deprecated = c.deprecationMessage;
            }
            if (c.id == 'editorOverviewRuler.rangeHighlightForeground') {
                needsTransparency = c.needsTransparency;
            }
        }
        assertEquals('\'editorIndentGuide.background\' is deprecated. Use \'editorIndentGuide.background1\' instead.', deprecated);
        assertTrue(needsTransparency);
    }

    function testResolveDefaultColorPerScheme() {
        final registry = ColorUtils.getColorRegistry();
        // editor.background: { light: '#ffffff', dark: '#1E1E1E', hcDark: Color.black, hcLight: Color.white }
        assertEquals('#ffffff', registry.resolveDefaultColor('editor.background', new FakeTheme(ColorScheme.LIGHT)).toString());
        assertEquals('#1e1e1e', registry.resolveDefaultColor('editor.background', new FakeTheme(ColorScheme.DARK)).toString());
        assertEquals('#000000', registry.resolveDefaultColor('editor.background', new FakeTheme(ColorScheme.HIGH_CONTRAST_DARK)).toString());
        assertEquals('#ffffff', registry.resolveDefaultColor('editor.background', new FakeTheme(ColorScheme.HIGH_CONTRAST_LIGHT)).toString());
        // a ColorValue default (editorGutter.background: editorBackground) asks the theme
        final theme = new FakeTheme(ColorScheme.DARK, ['editor.background' => Color.fromHex('#123456')]);
        assertEquals('#123456', registry.resolveDefaultColor('editorGutter.background', theme).toString());
        // null defaults
        assertNull(registry.resolveDefaultColor('editor.lineHighlightBackground', theme));
        assertNull(registry.resolveDefaultColor('not.registered', theme));
    }

    function testTransforms() {
        final theme = new FakeTheme(ColorScheme.DARK, ['a' => Color.fromHex('#102030'), 'b' => Color.fromHex('#405060')]);

        assertNull(ColorUtils.resolveColorValue(null, theme));
        assertEquals('#abcdef', ColorUtils.resolveColorValue('#abcdef', theme).toString());
        assertEquals('#102030', ColorUtils.resolveColorValue('a', theme).toString());
        assertNull(ColorUtils.resolveColorValue('c', theme));
        assertTrue(ColorUtils.resolveColorValue(Color.white, theme) == Color.white);

        // transparent multiplies the alpha
        assertEquals('rgba(16, 32, 48, 0.5)', ColorUtils.resolveColorValue(ColorUtils.transparent('a', 0.5), theme).toString());
        assertNull(ColorUtils.resolveColorValue(ColorUtils.transparent('c', 0.5), theme));

        // oneOf: the first color that resolves
        assertEquals('#405060', ColorUtils.resolveColorValue(ColorUtils.oneOf('c', 'b', 'a'), theme).toString());
        assertNull(ColorUtils.resolveColorValue(ColorUtils.oneOf('c', 'd'), theme));

        // ifDefinedThenElse: by `theme.defines`
        assertEquals('#102030', ColorUtils.resolveColorValue(ColorUtils.ifDefinedThenElse('b', 'a', '#ffffff'), theme).toString());
        assertEquals('#ffffff', ColorUtils.resolveColorValue(ColorUtils.ifDefinedThenElse('c', 'a', '#ffffff'), theme).toString());

        // opaque: without background, the color itself
        assertEquals('#102030', ColorUtils.resolveColorValue(ColorUtils.opaque('a', 'c'), theme).toString());
        // opaque on an opaque background: alpha becomes 1
        assertTrue(ColorUtils.resolveColorValue(ColorUtils.opaque(ColorUtils.transparent('a', 0.5), 'b'), theme).isOpaque());

        // lessProminent without background: transparent(factor * transparency)
        assertEquals('rgba(16, 32, 48, 0.25)', ColorUtils.resolveColorValue(ColorUtils.lessProminent('a', 'c', 0.5, 0.5), theme).toString());

        // darken / lighten keep hue and alpha
        final darker = ColorUtils.resolveColorValue(ColorUtils.darken('b', 0.5), theme);
        assertTrue(darker.isDarkerThan(Color.fromHex('#405060')));
        final lighter = ColorUtils.resolveColorValue(ColorUtils.lighten('b', 0.5), theme);
        assertTrue(lighter.isLighterThan(Color.fromHex('#405060')));
    }

    function testAsCssVariableName() {
        assertEquals('--vscode-editorSuggestWidget-background', ColorUtils.asCssVariableName('editorSuggestWidget.background'));
        assertEquals('var(--vscode-editor-background)', ColorUtils.asCssVariable('editor.background'));
    }

}

private class FakeTheme implements IColorTheme {

    final colors:Map<String, Color>;
    final scheme:ColorScheme;

    public function new(scheme:ColorScheme, ?colors:Map<String, Color>) {
        this.scheme = scheme;
        this.colors = colors != null ? colors : new Map();
    }

    public var type(get, never):ColorScheme;

    function get_type():ColorScheme {
        return scheme;
    }

    public var label(get, never):String;

    function get_label():String {
        return 'fake';
    }

    public function getColor(color:String, ?useDefault:Bool):Null<Color> {
        return colors.get(color);
    }

    public function defines(color:String):Bool {
        return colors.exists(color);
    }

    public function getTokenStyleMetadata(type:String, modifiers:Array<String>, modelLanguage:String):Null<ITokenStyle> {
        return null;
    }

    public var tokenColorMap(get, never):Array<String>;

    function get_tokenColorMap():Array<String> {
        return [];
    }

    public var semanticHighlighting(get, never):Bool;

    function get_semanticHighlighting():Bool {
        return false;
    }

}
