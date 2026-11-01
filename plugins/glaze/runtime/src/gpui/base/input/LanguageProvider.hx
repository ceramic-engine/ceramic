// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/language.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

/**
 * Supplies language identities, editing defaults, and syntax providers to Base.
 *
 * Implementations normalize aliases consistently with their highlighter. Syntax
 * providers belong to individual editors; configuration values can be shared.
 * Base does not require a parser. Component installs its implementation at init.
 *
 * Extend `LanguageProviderBase` for the trait's default methods.
 */
interface LanguageProvider {

    /**
     * Resolve a name or alias to its canonical identifier. Resolving an
     * already canonical identifier must return the same identifier.
     */
    function languageName(name:String):String;

    /**
     * Editing defaults for a canonical identifier; application registrations
     * take precedence over these defaults.
     */
    function config(name:String):LanguageConfig;

    /**
     * Creates an editor-owned provider, cached until the language or service
     * changes. After changing grammar registrations, reselect the editor's
     * language with `setHighlighter` to replace its cached provider.
     */
    function syntaxContextProvider(name:String):Null<SyntaxContextProvider>;

}

/**
 * The default methods of the `LanguageProvider` trait.
 */
class LanguageProviderBase implements LanguageProvider {

    public function new() {}

    /** Rust `str::to_lowercase` */
    public function languageName(name:String):String {
        return name.toLowerCase();
    }

    public function config(name:String):LanguageConfig {
        return new LanguageConfig();
    }

    public function syntaxContextProvider(name:String):Null<SyntaxContextProvider> {
        return null;
    }

}
