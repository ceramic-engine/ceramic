// New code for Cityscape (not a port): the TextMate grammars bundled with
// Glaze (the kit highlighter's catalog) registered in a Cityscape context.
package cityscape.kit;

import cityscape.Cityscape;
import glaze.kit.highlighter.GrammarCatalog;
import glaze.kit.highlighter.TextMateGrammars;

/**
 * Registers the grammars Glaze bundles (`assets/glaze/grammars`, the catalog
 * of the kit's highlighter) for Cityscape languages.
 *
 * The grammar files are read like the kit's highlighter reads them, through
 * `glaze.App.defaultAssetSource()`: synchronously where there is a file
 * system, from the bytes `glaze.kit.highlighter.Highlighter.preload` loaded
 * elsewhere (the web). A grammar that cannot be read is not registered and
 * its language stays uncolored, like the kit.
 */
class KitGrammars {

    /**
     * Registers the language `languageId` (when the context does not know
     * it) with the bundled grammar named `grammarName` (a name, alias or
     * extension of the catalog, `languageId` when null), and the grammars
     * it embeds. Returns whether the grammar was found and read.
     */
    public static function register(context:Cityscape, languageId:String, ?grammarName:String):Bool {
        final info = TextMateGrammars.findByToken(grammarName != null ? grammarName : languageId);
        if (info == null || info.file == null) {
            return false;
        }
        final text = read(info.file);
        if (text == null) {
            return false;
        }
        if (!context.languageService.isRegisteredLanguageId(languageId)) {
            context.languageService.registerLanguage({id: languageId});
        }
        context.textMate.registerGrammar({languageId: languageId, grammar: text, path: info.file});
        for (embedded in info.embedded) {
            final embeddedInfo = TextMateGrammars.findByToken(embedded);
            if (embeddedInfo == null || embeddedInfo.file == null) {
                continue;
            }
            final embeddedText = read(embeddedInfo.file);
            if (embeddedText != null) {
                context.textMate.registerGrammar({grammar: embeddedText, path: embeddedInfo.file});
            }
        }
        return true;
    }

    static function read(file:String):Null<String> {
        final bytes = glaze.App.defaultAssetSource().load(GrammarCatalog.FOLDER + '/' + file);
        return bytes != null ? bytes.toString() : null;
    }

}
