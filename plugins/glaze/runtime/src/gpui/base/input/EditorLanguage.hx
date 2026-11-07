// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/language.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.App;
import gpui.base.input.LanguageProvider.LanguageProviderBase;
import ropey.Rope;

/**
 * The provider installed when the application installs none.
 */
private class DefaultLanguages extends LanguageProviderBase {

    final defaultConfig:LanguageConfig = new LanguageConfig();

    override function config(name:String):LanguageConfig {
        return defaultConfig;
    }

}

/**
 * A registered configuration (Rust tuple `(SharedString, Rc<LanguageConfig>)`).
 */
private class RegisteredConfig {

    public final name:String;

    public final config:LanguageConfig;

    public function new(name:String, config:LanguageConfig) {
        this.name = name;
        this.config = config;
    }

}

/**
 * The language service and registrations of an application (Rust
 * `LanguageSettings` behind the `Languages` global).
 */
class Languages {

    public var provider:LanguageProvider = new DefaultLanguages();

    /** Registration order preserves precedence when a replacement service resolves aliases. */
    @:allow(gpui.base.input) final configs:Array<RegisteredConfig> = [];

    public function new() {}

    public static function global(cx:App):Languages {
        if (!cx.hasGlobal(Languages))
            cx.setGlobal(new Languages(), Languages);
        return cx.global(Languages);
    }

    /**
     * Install the application's language service. Existing editors use the new
     * service on their next editing operation, without waiting for a render.
     * Registered configurations are retained and resolved through the new service.
     */
    public static function setLanguageProvider(provider:LanguageProvider, cx:App):Void {
        global(cx).provider = provider;
    }

    /**
     * Replace a language's editing configuration for this application.
     * Existing editors read the replacement on their next edit. Aliases follow the
     * installed language provider; Base alone treats names case-insensitively.
     * This does not change `autoClose` or `smartIndent` preferences.
     */
    public static function setLanguageConfig(language:String, config:LanguageConfig, cx:App):Void {
        final languages = global(cx);
        var i = languages.configs.length - 1;
        while (i >= 0) {
            if (languages.configs[i].name == language)
                languages.configs.splice(i, 1);
            i--;
        }
        languages.configs.push(new RegisteredConfig(language, config));
    }

}

private class LanguageSyntax {

    public final source:LanguageProvider;

    public final provider:Null<SyntaxContextProvider>;

    public function new(source:LanguageProvider, provider:Null<SyntaxContextProvider>) {
        this.source = source;
        this.provider = provider;
    }

}

/**
 * One editor's language selection. Configurations are read from shared settings;
 * only the syntax provider is retained, because it owns a document parse cache.
 *
 * Rust's `Clone` shares the cached syntax (`Rc`): `clone()` does the same.
 */
class EditorLanguage {

    var _name:String;

    final languages:Languages;

    /** Shared between clones (Rust `Rc<RefCell<Option<LanguageSyntax>>>`) */
    var syntax:Array<Null<LanguageSyntax>>;

    function new(name:String, languages:Languages, syntax:Array<Null<LanguageSyntax>>) {
        this._name = name;
        this.languages = languages;
        this.syntax = syntax;
    }

    public static function create(cx:App):EditorLanguage {
        return new EditorLanguage('', Languages.global(cx), [null]);
    }

    public function clone():EditorLanguage {
        return new EditorLanguage(_name, languages, syntax);
    }

    public function name():String {
        return _name;
    }

    public function setName(name:String):Void {
        _name = name;
        syntax = [null];
    }

    public function config():LanguageConfig {
        final source = languages.provider;
        final name = source.languageName(_name);
        var i = languages.configs.length - 1;
        while (i >= 0) {
            final registered = languages.configs[i];
            if (source.languageName(registered.name) == name)
                return registered.config;
            i--;
        }
        return source.config(name);
    }

    public function contextAt(text:Rope, offset:Int):SyntaxContext {
        final source = languages.provider;
        final cached = syntax[0];
        if (cached == null || cached.source != source) {
            final name = source.languageName(_name);
            syntax[0] = new LanguageSyntax(source, source.syntaxContextProvider(name));
        }
        final provider = syntax[0].provider;
        return provider == null ? SyntaxContext.Code : provider.contextAt(text, offset);
    }

}
