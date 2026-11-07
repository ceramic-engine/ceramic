// Original code (not a port), written for Glaze.
// MIT License, see Ceramic's LICENSE file.
package glaze.kit.highlighter;

/**
 * A TextMate grammar known to the highlighter: a bundled one
 * (`GrammarCatalog`) or one an application registered
 * (`TextMateGrammars.register`).
 */
class GrammarInfo {

    /** The tm-grammars name of the language (`rust`, `shellscript`...). */
    public final name:String;

    public final displayName:String;

    /** The root scope of the grammar (`source.rust`). */
    public final scopeName:String;

    /** The file in the grammar folder of the assets, or null for a registered grammar. */
    public final file:Null<String>;

    /**
     * The lowercase names a code fence or an editor may use for it: its name,
     * its aliases and its file extensions.
     */
    public final tokens:Array<String>;

    /** Names of the languages it embeds (loaded with it when known). */
    public final embedded:Array<String>;

    /** For an injection grammar, the scopes it injects into. */
    public final injectTo:Array<String>;

    public function new(name:String, displayName:String, scopeName:String, file:Null<String>, tokens:Array<String>, embedded:Array<String>,
            injectTo:Array<String>) {
        this.name = name;
        this.displayName = displayName;
        this.scopeName = scopeName;
        this.file = file;
        this.tokens = tokens;
        this.embedded = embedded;
        this.injectTo = injectTo;
    }

}
