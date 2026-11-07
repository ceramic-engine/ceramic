// Ported from gpui-kit 0.8.1: crates/component/src/highlighter/language_name.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.highlighter;

class LanguageName {

    /**
     * Built-in aliases for editing defaults when no exact grammar name is registered.
     * Availability of a parser does not change what a language name means.
     */
    public static function languageName(name:String):String {
        final name = name.toLowerCase();
        return switch name {
            case "plain": "text";
            case "plaintext": "text";
            case "jsonc": "json";
            case "sh": "bash";
            case "c++": "cpp";
            case "cs": "csharp";
            case "scss": "css";
            case "ex": "elixir";
            case "js": "javascript";
            case "kt": "kotlin";
            case "kts": "kotlin";
            case "ktm": "kotlin";
            case "makefile": "make";
            case "md": "markdown";
            case "mdx": "markdown";
            case "markdown-inline": "markdown_inline";
            case "php3": "php";
            case "php4": "php";
            case "php5": "php";
            case "phtml": "php";
            case "protobuf": "proto";
            case "py": "python";
            case "rb": "ruby";
            case "rs": "rust";
            case "ts": "typescript";
            case "yml": "yaml";
            case "pyi": "python";
            case _: name;
        }
    }

}
