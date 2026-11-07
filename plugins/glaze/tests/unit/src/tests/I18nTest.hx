package tests;

import glaze.ViewTracker;
import glaze.kit.I18n;
import testing.TestCase;

/**
 * Tests of the translations of gpui-kit's components (rust-i18n `t!()` with
 * `crates/component/locales/ui.yml`): the tables read from the YAML at
 * compile time, the locale fallback and the `%{name}` patterns, compared with
 * gpui-component's own rust-i18n backend dumped by `reference/examples/theme_dump.rs`.
 */
class I18nTest extends TestCase {

    override function teardown() {
        I18n.setLocale('en');
        ceramic.App.app.flushImmediate();
    }

    function testTablesMatchGpuiKit() {
        final i18n:Dynamic = ThemeReference.data().i18n;
        final locales:Array<String> = i18n.locales;
        assertEquals(locales.join(','), I18n.availableLocales().join(','));
        for (locale in locales) {
            final expected:Dynamic = Reflect.field(i18n.tables, locale);
            final actual = I18n.messagesForLocale(locale);
            final expectedKeys = Reflect.fields(expected);
            expectedKeys.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
            final actualKeys = [for (k in actual.keys()) k];
            actualKeys.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
            assertEquals(expectedKeys.join('|'), actualKeys.join('|'), '$locale keys');
            for (key in expectedKeys) {
                assertEquals(Reflect.field(expected, key), actual.get(key), '$locale $key');
            }
        }
    }

    function testLookupsAndFallbackMatchGpuiKit() {
        final i18n:Dynamic = ThemeReference.data().i18n;
        final keys:Array<String> = i18n.keys;
        final lookups:Dynamic = i18n.lookups;
        for (locale in Reflect.fields(lookups)) {
            final row:Array<Null<String>> = Reflect.field(lookups, locale);
            for (i in 0...keys.length) {
                assertEquals(row[i], I18n.tryTranslate(locale, keys[i]), '"$locale" ${keys[i]}');
            }
        }
        assertEquals(i18n.default_locale, I18n.locale());
    }

    function testReplacePatternsMatchesGpuiKit() {
        final cases:Array<Dynamic> = ThemeReference.data().i18n.replace_patterns;
        for (entry in cases) {
            final args:Array<Array<String>> = entry.args;
            assertEquals(entry.output, I18n.replacePatterns(entry.input, [for (a in args) a[0]], [for (a in args) a[1]]), entry.input);
        }
    }

    function testT() {
        assertEquals('Copy', I18n.t('Input.Copy'));
        assertEquals('Su', I18n.t('Calendar.week.0'));
        assertEquals('Slide 2 of 5', I18n.t('Carousel.slide', {current: 2, total: 5}));
        assertEquals('Missing.key', I18n.t('Missing.key'));
        assertEquals('复制', I18n.t('Input.Copy', null, 'zh-CN'));

        I18n.setLocale('zh-HK');
        assertEquals('zh-HK', I18n.locale());
        assertEquals('複製', I18n.t('Input.Copy'));
        // `it` has no text for this key: falls back to `en`
        I18n.setLocale('it');
        assertFalse(I18n.messagesForLocale('it').exists('Input.Copy'));
        assertEquals('Copy', I18n.t('Input.Copy'));
        assertEquals('Do', I18n.t('Calendar.week.0'));
    }

    function testLocaleIsObservable() {
        var invalidations = 0;
        final view = new ViewTracker(() -> invalidations++);
        view.capture(() -> I18n.t('Input.Copy'));
        I18n.setLocale('zh-CN');
        ceramic.App.app.flushImmediate();
        assertEquals(1, invalidations);
        view.destroy();
    }

}
