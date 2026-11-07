package tests;

import gpui.App;
import gpui.Background;
import gpui.Hsla;
import gpui.OperatingSystem;
import gpui.Prelude.*;
import gpui.TestDispatcher;
import gpui.ViewTracker;
import gpui.base.theme.ColorTokens;
import gpui.base.theme.ScrollbarMode;
import gpui.base.theme.ThemeAppearance;
import gpui.component.theme.Color.*;
import gpui.component.theme.DefaultThemeColors;
import gpui.component.theme.SemanticThemeConfig;
import gpui.component.theme.Theme;
import gpui.component.theme.ThemeColor;
import gpui.component.theme.ThemeConfig;
import gpui.component.theme.ThemeMode;
import gpui.component.theme.ThemeRegistry;
import gpui.component.theme.ThemeSet;
import gpui.component.theme.ThemeToken;
import gpui.component.theme.ThemeTokens;
import testing.TestCase;
import tests.ColorHelpersTest.ColorReport;

using gpui.component.theme.ActiveTheme;
using gpui.component.theme.Colorize;

/**
 * Tests of gpui-kit's theme system (crates/component/src/theme/,
 * crates/base/src/theme_tokens.rs): the Rust unit tests, and every theme
 * (defaults and `themes/*.json`) resolved and compared field by field with
 * the values dumped from the original by `reference/examples/theme_dump.rs`.
 */
class ThemeTest extends TestCase {

    static inline final EPSILON = ColorHelpersTest.EPSILON;

    var previousOs:OperatingSystem;

    var app:App;

    override function setup() {
        // The reference was dumped on macOS (default mono font: Menlo)
        previousOs = OperatingSystem.current;
        OperatingSystem.current = Mac;
        app = new App(new TestDispatcher());
    }

    override function teardown() {
        OperatingSystem.current = previousOs;
        ceramic.App.app.flushImmediate();
    }

    static function camel(name:String):String {
        if (name == 'switch') return 'switch_';
        final parts = name.split('_');
        var result = parts[0];
        for (i in 1...parts.length) {
            result += parts[i].charAt(0).toUpperCase() + parts[i].substr(1);
        }
        return result;
    }

    static function color(value:Hsla):String {
        return '[${value.h}, ${value.s}, ${value.l}, ${value.a}]';
    }

    function gradient(from:Hsla, to:Hsla):ThemeToken {
        return new ThemeToken(from, linearGradient(135., linearColorStop(from, 0.), linearColorStop(to, 1.)));
    }

    function hex(value:Int):Hsla {
        return Hsla.fromRgba(rgb(value));
    }

    // Comparison with gpui-kit

    var errors:Array<String>;

    var maxError:Float;

    function compareNumber(expected:Dynamic, actual:Float, label:String) {
        final error = Math.abs((expected:Float) - actual);
        if (error > maxError) maxError = error;
        if (!(error <= EPSILON)) errors.push('$label: expected $expected but got $actual');
    }

    function compareColor(expected:Array<Dynamic>, actual:Hsla, label:String) {
        final error = ColorHelpersTest.colorError(expected, actual);
        if (error > maxError) maxError = error;
        if (!(error <= EPSILON)) errors.push('$label: expected $expected but got ${color(actual)}');
    }

    function compareValue(expected:Dynamic, actual:Dynamic, label:String) {
        if (expected != actual) errors.push('$label: expected $expected but got $actual');
    }

    function compareTheme(expected:Dynamic, theme:Theme, fields:Array<String>) {
        final name:String = expected.name;
        compareValue(expected.name, theme.themeName(), '$name name');
        compareValue(expected.mode, theme.mode.name(), '$name mode');
        compareValue(expected.is_dark, theme.isDark(), '$name isDark');
        compareValue(expected.font_family, theme.fontFamily, '$name fontFamily');
        compareValue(expected.mono_font_family, theme.monoFontFamily, '$name monoFontFamily');
        compareNumber(expected.font_size, theme.fontSize, '$name fontSize');
        compareNumber(expected.mono_font_size, theme.monoFontSize, '$name monoFontSize');
        compareNumber(expected.radius, theme.radius, '$name radius');
        compareNumber(expected.radius_lg, theme.radiusLg, '$name radiusLg');
        compareNumber(expected.radius_full, theme.radiusFull(), '$name radiusFull');
        compareNumber(expected.radius_2xl, theme.radius2xl(), '$name radius2xl');
        compareNumber(expected.radius_3xl, theme.radius3xl(), '$name radius3xl');
        compareNumber(expected.radius_4xl, theme.radius4xl(), '$name radius4xl');
        compareValue(expected.shadow, theme.shadow, '$name shadow');
        compareValue(expected.focus_ring, theme.focusRing, '$name focusRing');
        compareColor(expected.transparent, theme.transparent, '$name transparent');
        compareValue(expected.scrollbar_mode, theme.scrollbarMode.toString(), '$name scrollbarMode');
        compareColor(expected.input_background, theme.inputBackground(), '$name inputBackground');

        final colors:Dynamic = expected.colors;
        final tokens:Dynamic = expected.tokens;
        for (field in fields) {
            final key = camel(field);
            compareColor(Reflect.field(colors, field), Reflect.field(theme, key), '$name colors.$field');
            final token:Dynamic = Reflect.field(tokens, field);
            final actual:ThemeToken = Reflect.field(theme.tokens, key);
            compareColor(token.color, actual.color, '$name tokens.$field.color');
            final error = ColorHelpersTest.backgroundError(token.background, actual.background);
            if (error > maxError) maxError = error;
            if (!(error <= EPSILON)) {
                errors.push('$name tokens.$field.background: expected ${haxe.Json.stringify(token.background)} but got ${actual.background}');
            }
        }

        final semantic:Dynamic = expected.semantic;
        final resolved = theme.semanticTokens();
        for (field in ColorTokens.FIELD_NAMES) {
            compareColor(Reflect.field(semantic.colors, field), Reflect.field(resolved.colors, camel(field)), '$name semantic.colors.$field');
        }
        for (field in ['none', 'sm', 'md', 'lg', 'xl', 'full']) {
            compareNumber(Reflect.field(semantic.radius, field), Reflect.field(resolved.radius, field), '$name semantic.radius.$field');
        }
        for (field in ['xxs', 'xs', 'sm', 'md', 'lg', 'xl', 'xxl']) {
            compareNumber(Reflect.field(semantic.spacing, field), Reflect.field(resolved.spacing, field), '$name semantic.spacing.$field');
        }
        compareValue(semantic.typography.sans, resolved.typography.sans, '$name semantic.typography.sans');
        compareValue(semantic.typography.mono, resolved.typography.mono, '$name semantic.typography.mono');
        for (field in ['xs', 'sm', 'md', 'lg', 'xl', 'mono_md']) {
            final e:Dynamic = Reflect.field(semantic.typography, field);
            final a:gpui.base.theme.TextStyleToken = Reflect.field(resolved.typography, camel(field));
            compareNumber(e.size, a.size, '$name semantic.typography.$field.size');
            compareNumber(e.line_height, a.lineHeight, '$name semantic.typography.$field.lineHeight');
            compareNumber(e.weight, a.weight, '$name semantic.typography.$field.weight');
        }
        for (field in ['sm', 'md', 'lg']) {
            final e:Array<Dynamic> = Reflect.field(semantic.shadow, field);
            final a:Array<gpui.BoxShadow> = Reflect.field(resolved.shadow, field);
            compareValue(e.length, a.length, '$name semantic.shadow.$field.length');
            for (i in 0...Std.int(Math.min(e.length, a.length))) {
                compareColor(e[i].color, a[i].color, '$name semantic.shadow.$field[$i].color');
                compareNumber(e[i].offset[0], a[i].offset.x, '$name semantic.shadow.$field[$i].offset.x');
                compareNumber(e[i].offset[1], a[i].offset.y, '$name semantic.shadow.$field[$i].offset.y');
                compareNumber(e[i].blur_radius, a[i].blurRadius, '$name semantic.shadow.$field[$i].blurRadius');
                compareNumber(e[i].spread_radius, a[i].spreadRadius, '$name semantic.shadow.$field[$i].spreadRadius');
                compareValue(e[i].inset, a[i].inset, '$name semantic.shadow.$field[$i].inset');
            }
        }
    }

    function resolve(config:ThemeConfig):Theme {
        final theme = new Theme();
        theme.applyConfig(config);
        return theme;
    }

    function testEveryThemeMatchesGpuiKit() {
        final data:Dynamic = ThemeReference.data();
        final fields:Array<String> = data.fields;
        assertEquals(fields.join(','), ThemeColor.FIELD_NAMES.join(','), 'ThemeColor fields');

        final configs = new Map<String, ThemeConfig>();
        for (config in DefaultThemeColors.themes()) configs.set(config.name, config);
        final files = ThemeReference.themeFiles();
        for (name in files.keys()) {
            for (config in ThemeSet.parse(files.get(name)).themes) configs.set(config.name, config);
        }

        final expectedThemes:Array<Dynamic> = data.themes;
        assertEquals(38, expectedThemes.length);
        final report = [];
        var overall = 0.0;
        for (expected in expectedThemes) {
            final name:String = expected.name;
            final config = configs.get(name);
            assertNotNull(config, 'theme $name');
            if (config == null) continue;
            errors = [];
            maxError = 0;
            compareTheme(expected, resolve(config), fields);
            assertTrue(errors.length == 0, '$name: ${errors.length} differences, first: ${errors.slice(0, 5).join('; ')}');
            report.push('  ${expected.file} / $name (${expected.mode}): max error $maxError');
            if (maxError > overall) overall = maxError;
        }

        // `Theme::default()` itself, and the default palettes
        errors = [];
        maxError = 0;
        compareTheme(data.theme_default, new Theme(), fields);
        for (field in fields) {
            compareColor(Reflect.field(data.theme_color_light, field), Reflect.field(ThemeColor.light(), camel(field)), 'ThemeColor.light().$field');
            compareColor(Reflect.field(data.theme_color_dark, field), Reflect.field(ThemeColor.dark(), camel(field)), 'ThemeColor.dark().$field');
        }
        assertTrue(errors.length == 0, 'defaults: ${errors.slice(0, 5).join('; ')}');
        report.push('  Theme default, ThemeColor.light(), ThemeColor.dark(): max error $maxError');

        trace('Theme comparison with gpui-kit (${expectedThemes.length} themes, overall max error $overall):\n' + report.join('\n')
            + '\nColor helpers comparison with gpui-kit:\n' + ColorReport.lines.join('\n'));
    }

    function testThemeFilesAreTheGpuiKitOnes() {
        final files = ThemeReference.themeFiles();
        assertEquals(21, [for (k in files.keys()) k].length);
        final aurora = ThemeSet.parse(files.get('aurora.json'));
        assertEquals('Aurora', aurora.name);
        assertEquals('Longbridge', aurora.author);
    }

    // Rust #[cfg(test)]: theme/mod.rs, semantic_token_tests

    function testSemanticColorsAreALiveProjectionOfLegacyFields() {
        final theme = new Theme();
        final primary = new Hsla().alpha(0.42);
        theme.primary = primary;

        assertTrue(theme.colorTokens().primary.equals(primary));
        assertTrue(theme.semanticTokens().colors.primary.equals(primary));
    }

    function testApplyingSemanticTokensOnlyUpdatesGenericLegacyColors() {
        final theme = new Theme();
        final componentColor = theme.buttonPrimary;
        final tokens = theme.semanticTokens();
        tokens.colors.primary = new Hsla().alpha(0.25);
        tokens.colors.destructive = new Hsla().alpha(0.75);
        tokens.radius.md = 10.;

        theme.applySemanticTokens(tokens);

        assertTrue(theme.primary.equals(tokens.colors.primary));
        assertTrue(theme.tokens.primary.color.equals(tokens.colors.primary));
        assertTrue(theme.danger.equals(tokens.colors.destructive));
        assertEquals(10., (theme.radius:Float));
        assertTrue(theme.buttonPrimary.equals(componentColor));
    }

    function testSquareThemesSquareOffPillsAndCircles() {
        final theme = new Theme();
        assertEquals(9999., (theme.radiusFull():Float));
        assertEquals(9999., (theme.radiusTokens().full:Float));

        theme.radius = 0.;
        assertEquals(0., (theme.radiusFull():Float));
        assertEquals(0., (theme.radiusTokens().full:Float));
    }

    function testLargerSurfaceRadiiFollowTheThemeRadius() {
        final theme = new Theme();
        assertTrue(theme.radiusTokens().xl < theme.radius2xl());
        assertTrue(theme.radius2xl() < theme.radius3xl());
        assertTrue(theme.radius3xl() < theme.radius4xl());

        theme.radius = 10.;
        assertEquals(25., (theme.radius2xl():Float));
        assertEquals(30., (theme.radius3xl():Float));
        assertEquals(35., (theme.radius4xl():Float));

        theme.radius = 0.;
        assertEquals(0., (theme.radius2xl():Float));
        assertEquals(0., (theme.radius3xl():Float));
        assertEquals(0., (theme.radius4xl():Float));
    }

    function testBaseProjectionCarriesASquareRadiusToTheScrollbar() {
        final theme = new Theme();
        assertTrue(@:privateAccess theme.baseTheme().tokens.radius.md != 0.);

        theme.radius = 0.;
        assertTrue(@:privateAccess theme.baseTheme().tokens.radius.md == 0.);
    }

    function testDisabledLegacyShadowsProjectToEmptyElevations() {
        final theme = new Theme();
        theme.shadow = false;

        final shadows = theme.shadowTokens();
        assertEquals(0, shadows.sm.length);
        assertEquals(0, shadows.md.length);
        assertEquals(0, shadows.lg.length);
    }

    // Rust #[cfg(test)]: theme/mod.rs, update_tests

    function testEditingColorsUpdatesTheTokensAndTheBaseProjection() {
        Theme.init(app);
        final sidebar = hex(0x123456);
        final primary = hex(0xabcdef);

        Theme.update(app, theme -> {
            theme.sidebar = sidebar;
            theme.colors.primary = primary;
            theme.radius = 0.;
            return null;
        });

        final theme = Theme.global(app);
        assertTrue(theme.tokens.sidebar.color.equals(sidebar));
        assertTrue(theme.tokens.sidebar.background.equals(Background.fromHsla(sidebar)));
        assertTrue(theme.tokens.primary.color.equals(primary));
        assertTrue(gpui.base.theme.Theme.global(app).tokens.colors.primary.equals(primary));
        assertTrue(gpui.base.theme.Theme.global(app).tokens.radius.md == 0.);
    }

    function testReplacingThePaletteRewritesEveryToken() {
        Theme.init(app);
        final palette = ThemeColor.dark().copyColors();

        Theme.update(app, theme -> {
            theme.colors = palette;
            return null;
        });

        assertTrue(Theme.global(app).tokens.equals(ThemeTokens.fromColors(palette)));
    }

    function testAGradientSurvivesUntilItsOwnColorIsEdited() {
        Theme.init(app);
        final from = hex(0x4f46e5);
        final to = hex(0x06b6d4);
        final token = gradient(from, to);
        Theme.update(app, theme -> {
            theme.tokens.primary = token;
            return null;
        });
        // The token's solid color is written back
        assertTrue(Theme.global(app).primary.equals(from));

        Theme.update(app, theme -> {
            theme.secondary = hex(0x222222);
            return null;
        });
        assertTrue(Theme.global(app).tokens.primary.equals(token));

        final solid = hex(0x999999);
        Theme.update(app, theme -> {
            theme.primary = solid;
            return null;
        });
        assertTrue(Theme.global(app).tokens.primary.equals(ThemeToken.fromHsla(solid)));
    }

    function testSettingTheModeLoadsThatModesTheme() {
        Theme.init(app);
        final lightBackground = Theme.global(app).background;

        Theme.update(app, theme -> {
            theme.mode = Dark;
            return null;
        });

        final theme = Theme.global(app);
        assertTrue(theme.isDark());
        assertFalse(theme.background.equals(lightBackground));
        assertTrue(theme.tokens.background.color.equals(theme.background));
        assertEquals(ThemeAppearance.Dark, gpui.base.theme.Theme.global(app).appearance);
        assertTrue(gpui.base.theme.Theme.global(app).tokens.colors.background.equals(theme.background));
    }

    function testApplyingAConfigKeepsItsGradients() {
        Theme.init(app);
        final config = ThemeConfig.fromJson({
            name: 'Gradient',
            mode: 'light',
            colors: {
                'primary': '#4F46E5',
                'primary.background': 'linear-gradient(135deg, #4F46E5, #06B6D4)'
            }
        });

        Theme.update(app, theme -> {
            theme.applyConfig(config);
            return null;
        });

        final theme = Theme.global(app);
        assertTrue(theme.tokens.primary.color.equals(theme.primary));
        assertFalse(theme.tokens.primary.background.equals(Background.fromHsla(theme.primary)), 'the gradient must survive the reconcile');
    }

    function testEditsAfterApplyingAConfigOfTheOtherModeSurvive() {
        Theme.init(app);
        final config = ThemeConfig.fromJson({
            name: 'Rounded Dark',
            mode: 'dark',
            radius: 12,
            colors: {'primary': '#4F46E5'}
        });
        assertFalse(Theme.global(app).isDark());

        final red = Hsla.red();
        Theme.update(app, theme -> {
            theme.applyConfig(config);
            theme.radius = 0.;
            theme.colors.primary = red;
            return null;
        });

        final theme = Theme.global(app);
        assertTrue(theme.isDark());
        assertTrue(theme.darkTheme == config);
        assertEquals(0., (theme.radius:Float), 'the file\'s radius must not reload');
        assertTrue(theme.primary.equals(red));
        assertTrue(theme.tokens.primary.equals(ThemeToken.fromHsla(red)));
        assertTrue(gpui.base.theme.Theme.global(app).tokens.colors.primary.equals(red));
    }

    function testUpdateReturnsTheClosureResult() {
        Theme.init(app);
        final radius = Theme.update(app, theme -> {
            theme.radius = 6.;
            return theme.radius;
        });
        assertEquals(6., (radius:Float));
    }

    // Rust #[cfg(test)]: theme/mod.rs, base_theme_projection_tests (the
    // scrollbar motion, cursor blink and motion token tests wait for those modules)

    function assertStyledProjection() {
        final theme = Theme.global(app);
        final base = gpui.base.theme.Theme.global(app);

        assertTrue(base.tokens.equals(theme.semanticTokens()));
        assertEquals(theme.scrollbarMode, base.scrollbar.mode());
        assertTrue(base.resizable.handle.equals(theme.border));
        assertTrue(base.resizable.activeHandle.equals(theme.dragBorder));
    }

    function testBaseThemeTracksInitializationAndModeChanges() {
        Theme.init(app);
        assertStyledProjection();

        Theme.change(Dark, null, app);
        assertStyledProjection();

        Theme.setScrollbarMode(Always, app);
        assertEquals(ScrollbarMode.Always, Theme.global(app).scrollbarMode);
        assertEquals(ScrollbarMode.Always, gpui.base.theme.Theme.global(app).scrollbar.mode());
        assertStyledProjection();
    }

    function assertCloseTokens(left:ColorTokens, right:ColorTokens) {
        for (field in ColorTokens.FIELD_NAMES) {
            final a:Hsla = Reflect.field(left, camel(field));
            final b:Hsla = Reflect.field(right, camel(field));
            assertTrue(Math.abs(a.h - b.h) < 1e-6 && Math.abs(a.s - b.s) < 1e-6 && Math.abs(a.l - b.l) < 1e-6 && Math.abs(a.a - b.a) < 1e-6,
                '$field differs: ${color(a)} != ${color(b)}');
        }
    }

    function testDefaultComponentPalettesMatchBaseLightAndDarkTokens() {
        Theme.init(app);
        assertCloseTokens(Theme.global(app).colorTokens(), ColorTokens.light());

        Theme.change(Dark, null, app);
        assertCloseTokens(Theme.global(app).colorTokens(), ColorTokens.dark());
    }

    // Rust #[cfg(test)]: theme/schema.rs

    function testSemanticThemeConfigParses() {
        // Rust also checks a serde round trip, which has no counterpart here.
        final content = haxe.Json.stringify({
            name: 'Semantic',
            mode: 'dark',
            tokens: {
                colors: {
                    surface: '#111827',
                    surface_foreground: '#f9fafb',
                    primary: '#2563eb',
                    destructive: '#dc2626'
                },
                radius: {sm: 2.0, md: 6.0, lg: 10.0},
                spacing: {xs: 4.0, md: 12.0, xl: 24.0},
                typography: {
                    sans: 'Inter',
                    md: {size: 15.0, line_height: 22.0}
                }
            }
        });
        final semantic = SemanticThemeConfigFile.parse(content).tokens;

        assertEquals('#111827', semantic.colors.surface);
        assertEquals('#dc2626', semantic.colors.destructive);
        assertEquals(10.0, semantic.radius.lg);
        assertEquals(24.0, semantic.spacing.xl);
        assertEquals('Inter', semantic.typography.sans);
        assertEquals(22.0, semantic.typography.md.lineHeight);

        final theme = new Theme();
        final resolved = theme.applySemanticConfigStr(content);
        assertTrue(theme.primary.equals(tryParseColor('#2563eb')));
        assertEquals(24., (resolved.spacing.xl:Float));
        assertEquals(22., (resolved.typography.md.lineHeight:Float));
    }

    function testSemanticTokensOverrideLegacyGenericFieldsOnly() {
        final config = SemanticThemeConfigFile.parse(haxe.Json.stringify({
            tokens: {
                colors: {primary: '#2563eb', destructive: '#b91c1c'},
                spacing: {md: 14.0},
                typography: {md: {size: 15.0}}
            }
        }));
        final theme = new Theme();
        final componentColor = theme.buttonPrimary;
        final resolved = theme.applySemanticConfig(config.tokens);

        assertTrue(theme.primary.equals(tryParseColor('#2563eb')));
        assertTrue(theme.danger.equals(tryParseColor('#b91c1c')));
        assertTrue(theme.buttonPrimary.equals(componentColor));
        assertEquals(14., (resolved.spacing.md:Float));
        assertEquals(15., (resolved.typography.md.size:Float));
    }

    function testLegacyConfigWithoutSemanticTokensIsUnchanged() {
        final config = ThemeConfig.fromJson({
            name: 'Legacy',
            mode: 'light',
            radius: 7,
            colors: {'primary.background': '#7c3aed'}
        });
        final theme = new Theme();
        theme.applyConfig(config);
        assertTrue(theme.primary.equals(tryParseColor('#7c3aed')));
        assertEquals(7., (theme.radius:Float));
        assertTrue(theme.semanticTokens().spacing.equals(new gpui.base.theme.SpacingTokens()));
    }

    function testApplyConfigReadsTheChartColors() {
        final config = ThemeConfig.fromJson({
            name: 'Palette',
            mode: 'light',
            colors: {
                'chart.1': '#111111',
                'chart.2': 'not a color',
                'chart.3': '#333333',
                'chart.bullish': '#00ff00',
                'chart.bearish': '#ff0000',
                'chart.grid': '#eeeeee'
            }
        });

        final theme = new Theme();
        theme.applyConfig(config);

        // The keys match the fields; an unparsable or missing one falls back
        // to the ramp of the base blue.
        assertTrue(theme.chart1.equals(tryParseColor('#111111')));
        assertTrue(theme.chart2.equals(theme.blue.lighten(0.2)));
        assertTrue(theme.chart3.equals(tryParseColor('#333333')));
        assertTrue(theme.chart4.equals(theme.blue.darken(0.2)));
        assertTrue(theme.chart5.equals(theme.blue.darken(0.4)));
        assertTrue(theme.tokens.chart3.color.equals(theme.chart3));
        assertTrue(theme.chartBullish.equals(tryParseColor('#00ff00')));
        assertTrue(theme.chartBearish.equals(tryParseColor('#ff0000')));
        assertTrue(theme.chartGrid.equals(tryParseColor('#eeeeee')));

        theme.applyConfig(new ThemeConfig());
        assertTrue(theme.chartGrid.equals(theme.border.opacity(0.6)));
    }

    function testApplyConfigPreservesGradientBackgroundAndSolidColorFallback() {
        final config = ThemeConfig.fromJson({
            name: 'Gradient',
            mode: 'light',
            colors: {
                'primary.background': 'linear-gradient(135deg, #4F46E5, #06B6D4)',
                'button.primary.hover.background': 'linear-gradient(to right, red-500 25%, blue-600 75%)'
            }
        });

        final theme = new Theme();
        theme.applyConfig(config);

        final primaryFrom = tryParseColor('#4F46E5');
        final primaryTo = tryParseColor('#06B6D4');
        assertTrue(theme.primary.equals(primaryFrom));
        assertTrue(theme.tokens.primary.color.equals(primaryFrom));
        assertTrue(theme.tokens.primary.background.equals(linearGradient(135., linearColorStop(primaryFrom, 0.), linearColorStop(primaryTo, 1.))));
        assertTrue(theme.tokens.buttonPrimary.background.equals(theme.tokens.primary.background));
        assertTrue(theme.tokens.buttonPrimaryHover.background.equals(linearGradient(90., linearColorStop(red500(), 0.25), linearColorStop(blue600(), 0.75))));
        assertEquals(ThemeMode.Light, theme.mode);
    }

    function testAuroraThemeParsesGradientBackgrounds() {
        final themeSet = ThemeSet.parse(ThemeReference.themeFiles().get('aurora.json'));
        assertEquals(1, themeSet.themes.length);
        assertTrue(Lambda.foreach(themeSet.themes, theme -> !theme.mode.isDark()));

        final light = Lambda.find(themeSet.themes, theme -> theme.name == 'Aurora Light');
        final theme = new Theme();
        theme.applyConfig(light);

        assertFalse(theme.tokens.buttonPrimary.background.equals(Background.fromHsla(theme.buttonPrimary)));
        assertTrue(theme.tokens.background.background.equals(Background.fromHsla(theme.background)));
        assertTrue(theme.buttonPrimary.equals(tryParseColor('#1E293B')));
        assertTrue(theme.background.equals(tryParseColor('#FFFFFF')));
        assertFalse(theme.tokens.progressBar.background.equals(Background.fromHsla(theme.progressBar)));
        assertFalse(theme.tokens.scrollbarThumb.background.equals(Background.fromHsla(theme.scrollbarThumb)));
        assertFalse(theme.tokens.switch_.background.equals(Background.fromHsla(theme.switch_)));
        assertFalse(theme.tokens.switchThumb.background.equals(Background.fromHsla(theme.switchThumb)));
        assertFalse(theme.tokens.titleBar.background.equals(Background.fromHsla(theme.titleBar)));
        assertFalse(theme.tokens.statusBar.background.equals(Background.fromHsla(theme.statusBar)));
    }

    function testApplyConfigClampsHighlightAlphaPerGradientStop() {
        final config = ThemeConfig.fromJson({
            name: 'Highlight',
            mode: 'light',
            colors: {
                // Solid above the cap: must be capped to 0.2, not attenuated twice.
                'list.active.background': '#3b82f6',
                // Gradient with a faint `from` stop and an opaque `to` stop.
                'table.active.background': 'linear-gradient(#bfdbfe33, #3b82f6)',
                // Gradient with a transparent `from` stop.
                'selection.background': 'linear-gradient(#3b82f600, #3b82f6)'
            }
        });

        final theme = new Theme();
        theme.applyConfig(config);

        final blue = tryParseColor('#3b82f6');
        assertTrue(theme.listActive.equals(blue.alpha(0.2)));
        assertTrue(theme.tokens.listActive.background.equals(Background.fromHsla(blue.alpha(0.2))));

        final faint = tryParseColor('#bfdbfe33');
        assertTrue(theme.tokens.tableActive.background.equals(linearGradient(180.,
            linearColorStop(faint.alpha(Math.min(faint.a, 0.2)), 0.), linearColorStop(blue.alpha(0.2), 1.))));

        final clear = tryParseColor('#3b82f600');
        assertTrue(theme.tokens.selection.background.equals(linearGradient(180.,
            linearColorStop(clear.alpha(Math.min(clear.a, 0.3)), 0.), linearColorStop(blue.alpha(0.3), 1.))));
    }

    // Rust #[cfg(test)]: base/src/theme_tokens.rs

    function testDefaultColorsAreTheLightPaletteAndBothPalettesAreReadable() {
        final light = ColorTokens.light();
        final dark = ColorTokens.dark();

        assertTrue(ColorTokens.defaultValue().equals(light));
        assertEquals(1., light.background.l);
        assertTrue(light.foreground.l < light.background.l);
        assertTrue(dark.background.l < dark.foreground.l);
        assertEquals(1., light.primary.a);
        assertEquals(1., dark.primary.a);
    }

    // Haxe port specifics: reactivity and the registry

    function testViewsReadingTheThemeReactToChanges() {
        Theme.init(app);
        ceramic.App.app.flushImmediate();
        var invalidations = 0;
        final view = new ViewTracker(() -> invalidations++);

        view.capture(() -> app.theme().primary);
        Theme.change(Dark, null, app);
        ceramic.App.app.flushImmediate();
        assertEquals(1, invalidations, 'change() installs a new theme');

        view.capture(() -> app.theme().primary);
        Theme.update(app, theme -> {
            theme.radius = 3.;
            return null;
        });
        ceramic.App.app.flushImmediate();
        assertEquals(2, invalidations, 'update() installs a new theme');

        // The installed theme is never mutated: a reference kept by a view stays valid
        final before = Theme.global(app);
        Theme.update(app, theme -> {
            theme.primary = Hsla.red();
            return null;
        });
        assertFalse(before.primary.equals(Hsla.red()));
        assertTrue(Theme.global(app).primary.equals(Hsla.red()));

        // Reading from a Context works the same
        final entity = app.newEntity(cx -> new ThemeTestModel());
        entity.update(app, (model, cx) -> {
            assertTrue(cx.theme() == Theme.global(app));
            return null;
        });
        view.destroy();
    }

    function testRegistryLoadsThemesAndReloadsTheActiveOne() {
        Theme.init(app);
        final registry = ThemeRegistry.global(app);
        assertFalse(registry.hasCustomThemes);
        assertEquals('Default Light', registry.defaultLightTheme().name);
        assertEquals('Default Dark', registry.defaultDarkTheme().name);

        ThemeRegistry.globalMut(app).loadThemesFromStr(ThemeReference.themeFiles().get('catppuccin.json'));
        assertTrue(registry.hasCustomThemes);
        final names = [for (theme in registry.sortedThemes()) theme.name];
        assertEquals('Default Light,Default Dark,Catppuccin Latte,Catppuccin Frappe,Catppuccin Macchiato,Catppuccin Mocha', names.join(','));

        // A theme already registered is not replaced
        ThemeRegistry.globalMut(app).loadThemesFromStr(haxe.Json.stringify({themes: [{name: 'Catppuccin Latte', colors: {background: '#ff0000'}}]}));
        assertEquals('light', registry.themes().get('Catppuccin Latte').mode.name());

        // Switching to a registered theme: assign it, then `change` loads it
        // (like Rust, an `update` that sets a new config and the mode in one
        // edit counts as installed by the edit and does not load it).
        final mocha = registry.themes().get('Catppuccin Mocha');
        Theme.update(app, theme -> {
            theme.darkTheme = mocha;
            return null;
        });
        Theme.change(Dark, null, app);
        assertEquals('Catppuccin Mocha', Theme.global(app).themeName());
        final expected = resolve(mocha);
        assertTrue(Theme.global(app).colorsEqual(expected));

        assertRaises(() -> ThemeRegistry.globalMut(app).loadThemesFromStr('{"themes": [{"mode": "sepia"}]}'));
        assertRaises(() -> ThemeRegistry.globalMut(app).loadThemesFromStr('{"themes": [{"radius": 6.5}]}'));
    }

}

class ThemeTestModel extends gpui.Model {}
