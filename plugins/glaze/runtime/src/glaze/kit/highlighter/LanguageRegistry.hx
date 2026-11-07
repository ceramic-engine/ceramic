// Ported from gpui-kit 0.8.1: crates/component/src/highlighter/wasm_stub.rs (Language,
// LanguageConfig, GrammarConfig, LanguageRegistry)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.highlighter;

/**
 * The language configuration of gpui-kit's builds without tree-sitter: a
 * name and no grammar. The TextMate grammars of the port's highlighter are
 * registered with `TextMateGrammars` instead.
 */
class LanguageConfig {

    public var name:String;

    public function new(name:String) {
        this.name = name;
    }

    public function hasGrammar():Bool {
        return false;
    }

    public function equals(other:Null<LanguageConfig>):Bool {
        return other != null && other.name == name;
    }

}

/**
 * Explicit name for grammar resources; editing rules use
 * `glaze.kit.input.LanguageConfig`.
 */
typedef GrammarConfig = LanguageConfig;

/**
 * Language enum stub (Rust `wasm_stub::Language`).
 */
enum abstract Language(Int) {

    var Unknown = 0;

    public static function fromStr(_name:String):Language {
        return Unknown;
    }

    public function name():String {
        return "unknown";
    }

    public function config():GrammarConfig {
        return new LanguageConfig("unknown");
    }

    public static function all():Array<Language> {
        return [Unknown];
    }

}

/**
 * Registry of language configurations (the stub of gpui-kit's builds
 * without tree-sitter: exact names only, no alias fallback, empty at start).
 */
class LanguageRegistry {

    static var instance:Null<LanguageRegistry> = null;

    final languagesByName:Map<String, GrammarConfig> = new Map();

    /** Insertion order of the names (Rust's `HashMap` order is unspecified). */
    final names:Array<String> = [];

    @:allow(glaze.kit.highlighter, tests)
    function new() {}

    public static function singleton():LanguageRegistry {
        if (instance == null)
            instance = new LanguageRegistry();
        return instance;
    }

    public function register(lang:String, config:GrammarConfig):Void {
        if (!languagesByName.exists(lang))
            names.push(lang);
        languagesByName.set(lang, config);
    }

    @:allow(glaze.kit)
    function editingLanguageName(name:String):String {
        return languagesByName.exists(name) ? name : LanguageName.languageName(name);
    }

    public function languages():Array<String> {
        return names.copy();
    }

    public function language(name:String):Null<GrammarConfig> {
        return languagesByName.get(name);
    }

}
