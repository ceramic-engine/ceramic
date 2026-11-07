// Ported from gpui-kit 0.8.1: crates/component/src/input/language_config.rs,
// crates/component/src/input/syntax_context.rs, crates/component/src/input/mod.rs (init)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.input;

import glaze.App;
import glaze.kit.base.input.AutoClosingPair;
import glaze.kit.base.input.BracketPair;
import glaze.kit.base.input.EditorLanguage.Languages;
import glaze.kit.base.input.IndentationRules;
import glaze.kit.base.input.LanguageConfig;
import glaze.kit.base.input.LanguageProvider;
import glaze.kit.base.input.SyntaxContext;
import glaze.kit.base.input.SyntaxContextProvider;

/**
 * Language editing configuration of the styled components (Rust module
 * `input::language_config`). Grammar resources live in `highlighter`.
 */
class ComponentLanguages implements LanguageProvider {

    final defaults:Map<String, LanguageConfig>;

    final fallback:LanguageConfig;

    function new(defaults:Map<String, LanguageConfig>, fallback:LanguageConfig) {
        this.defaults = defaults;
        this.fallback = fallback;
    }

    public function languageName(name:String):String {
        return @:privateAccess glaze.kit.highlighter.LanguageRegistry.singleton().editingLanguageName(name);
    }

    public function config(name:String):LanguageConfig {
        final config = defaults.get(name);
        return config != null ? config : fallback;
    }

    public function syntaxContextProvider(name:String):Null<SyntaxContextProvider> {
        return ComponentLanguages.syntaxContextProviderFor(name);
    }

    /** Rust `input::init`: installs the language service of the components. */
    @:allow(glaze.kit)
    static function init(cx:glaze.AppContext):Void {
        final defaults = new Map<String, LanguageConfig>();
        for (name in ["text", "json", "python"]) {
            defaults.set(name, defaultLanguageConfig(name));
        }
        Languages.setLanguageProvider(new ComponentLanguages(defaults, new LanguageConfig()), cx);
    }

    /**
     * A syntax-context provider for `language`, or `null` when no grammar
     * gives one (Rust `syntax_context::syntax_context_provider`).
     *
     * gpui-kit classifies an offset with tree-sitter (its `tree-sitter`
     * feature); the port does not use tree-sitter, like gpui-kit built without
     * that feature: no provider, the engine falls back to its heuristics.
     */
    @:allow(glaze.kit.input, tests)
    static function syntaxContextProviderFor(_language:String):Null<SyntaxContextProvider> {
        return null;
    }

    static var pythonIndent:Null<IndentationRules> = null;

    /**
     * Language editing defaults. Editor preferences are stored separately on EditorState.
     * Unknown languages use structural bracket indentation; only Python treats a colon
     * as a block opener. Plain text has no structural or automatic pairs.
     */
    @:allow(glaze.kit.input, tests)
    static function defaultLanguageConfig(language:String):LanguageConfig {
        if (pythonIndent == null) {
            pythonIndent = new IndentationRules(new EReg("[\\{\\(\\[:]\\s*$", ""), new EReg("^\\s*[\\}\\)\\]]", ""));
        }
        return switch language.toLowerCase() {
            case "text":
                new LanguageConfig()
                    .withBrackets([])
                    .withAutoClosingPairs([]);
            case "json":
                new LanguageConfig()
                    .withBrackets([new BracketPair("{", "}"), new BracketPair("[", "]")])
                    .withAutoClosingPairs([
                        for (p in [
                            new AutoClosingPair("{", "}"),
                            new AutoClosingPair("[", "]"),
                            new AutoClosingPair("\"", "\""),
                        ]) p.withNotIn([SyntaxContext.String, SyntaxContext.Comment])
                    ]);
            case "python":
                new LanguageConfig().withIndentationRules(pythonIndent);
            case _:
                new LanguageConfig();
        }
    }

}
