// Ported from rust-i18n 4.2.1 (src/lib.rs: locale, set_locale, replace_patterns)
// and rust-i18n-macro 4.2.1 (src/lib.rs: _rust_i18n_try_translate, _rust_i18n_lookup_fallback; src/tr.rs: t!),
// as used by gpui-kit 0.8.1 (crates/component/src/lib.rs: `i18n!("locales", fallback = "en")`, locale, set_locale).
// Original code: rust-i18n Copyright (c) 2021 Longbridge, licensed under MIT; gpui-kit Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit;

/**
 * Translations of gpui-kit's components (`t!()` in Rust).
 *
 * The texts come from `locales/*.yml` (gpui-kit's `crates/component/locales`),
 * embedded at compile time. A lookup tries the locale, then its parents
 * (`zh-HK-x-private` -> `zh-HK` -> `zh`), then the fallback locale `en`; a
 * key found nowhere is returned as is.
 *
 * The current locale is observable: `t()` read during render subscribes the
 * view, which re-renders after `setLocale`.
 *
 * ```haxe
 * I18n.t('Input.Copy');
 * I18n.t('Carousel.slide', {current: 2, total: 5});
 * ```
 */
class I18n {

    /**
     * The fallback locales (Rust: `fallback = "en"`).
     */
    public static final FALLBACK_LOCALES:Array<String> = ['en'];

    static var translations:Null<Map<String, Map<String, String>>> = null;

    static var state:Null<I18nState> = null;

    static function backend():Map<String, Map<String, String>> {

        if (translations == null) {
            translations = new Map();
            final json:Dynamic = haxe.Json.parse(I18nMacro.translationsJson());
            for (locale in Reflect.fields(json)) {
                final table = new Map<String, String>();
                final texts:Dynamic = Reflect.field(json, locale);
                for (key in Reflect.fields(texts)) {
                    table.set(key, Reflect.field(texts, key));
                }
                translations.set(locale, table);
            }
        }
        return translations;

    }

    static function localeState():I18nState {

        if (state == null) {
            state = new I18nState();
        }
        return state;

    }

    /**
     * The current locale (`en` by default). Observable.
     */
    public static function locale():String {

        return localeState().locale;

    }

    /**
     * Set the current locale.
     */
    public static function setLocale(locale:String):Void {

        localeState().locale = locale;

    }

    /**
     * The locales that have translations, sorted.
     */
    public static function availableLocales():Array<String> {

        final locales = [for (locale in backend().keys()) locale];
        locales.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
        return locales;

    }

    /**
     * Every translation of the given locale (without fallback), or `null`
     * when the locale has none.
     */
    public static function messagesForLocale(locale:String):Null<Map<String, String>> {

        return backend().get(locale);

    }

    static function backendTranslate(locale:String, key:String):Null<String> {

        final table = backend().get(locale);
        return table != null ? table.get(key) : null;

    }

    /**
     * The parent of a locale tag: `zh-Hant-CN-x-private1` -> `zh-Hant-CN`
     * (https://datatracker.ietf.org/doc/html/rfc4647#section-3.4).
     */
    static function lookupFallback(locale:String):Null<String> {

        final n = locale.lastIndexOf('-');
        if (n < 0) return null;
        var parent = locale.substr(0, n);
        while (StringTools.endsWith(parent, '-x')) parent = parent.substr(0, parent.length - 2);
        return parent;

    }

    /**
     * The text of `key` in `locale`, its parents, then the fallback locales;
     * `null` when not found anywhere.
     */
    public static function tryTranslate(locale:String, key:String):Null<String> {

        final value = backendTranslate(locale, key);
        if (value != null) return value;

        var currentLocale = locale;
        var fallbackLocale = lookupFallback(currentLocale);
        while (fallbackLocale != null) {
            final value = backendTranslate(fallbackLocale, key);
            if (value != null) return value;
            currentLocale = fallbackLocale;
            fallbackLocale = lookupFallback(currentLocale);
        }

        for (fallback in FALLBACK_LOCALES) {
            final value = backendTranslate(fallback, key);
            if (value != null) return value;
        }
        return null;

    }

    /**
     * Get the text of `key` in the current locale (or `locale` when given),
     * with `%{name}` patterns replaced by the fields of `args`. A missing key
     * is returned as is (with its patterns replaced).
     */
    public static function t(key:String, ?args:Dynamic, ?locale:String):String {

        final translated = tryTranslate(locale != null ? locale : I18n.locale(), key);
        final text = translated != null ? translated : key;
        if (args == null) return text;
        final keys = Reflect.fields(args);
        return replacePatterns(text, keys, [for (k in keys) Std.string(Reflect.field(args, k))]);

    }

    /**
     * Replaces every `%{name}` of `input` by the value of `name`; a pattern
     * without a value is left as is.
     */
    public static function replacePatterns(input:String, patterns:Array<String>, values:Array<String>):String {

        // Work on UTF-8 bytes like Rust, so that positions match.
        final bytes = haxe.io.Bytes.ofString(input);
        final patternPos:Array<Int> = [];
        var stage = 0;
        for (i in 0...bytes.length) {
            final b = bytes.get(i);
            if (stage == 1 && b == '{'.code) {
                stage = 2;
                patternPos.push(i);
            }
            else if (stage == 2 && b == '}'.code) {
                stage = 0;
                patternPos.push(i);
            }
            else if (b == '%'.code) {
                stage = 1;
            }
        }

        final output = new haxe.io.BytesBuffer();
        var prevEnd = 0;
        var chunk = 0;
        while (chunk + 1 < patternPos.length) {
            final start = patternPos[chunk];
            final end = patternPos[chunk + 1];
            chunk += 2;
            final key = bytes.getString(start + 1, end - start - 1);
            if (prevEnd < start) {
                output.addBytes(bytes, prevEnd, start - 1 - prevEnd);
            }
            final index = patterns.indexOf(key);
            if (index >= 0 && index < values.length) {
                output.addString(values[index]);
            }
            else {
                output.addBytes(bytes, start - 1, end + 2 - start);
            }
            prevEnd = end + 1;
        }
        if (prevEnd < bytes.length) {
            output.addBytes(bytes, prevEnd, bytes.length - prevEnd);
        }
        return output.getBytes().toString();

    }

}

/**
 * The observable current locale.
 */
private class I18nState extends ceramic.Entity implements tracker.Observable {

    @observe public var locale:String = 'en';

    public function new() {
        super();
    }

}
