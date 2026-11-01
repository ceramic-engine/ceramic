// Original code (not a port), written for ceramic-gpui.
// MIT License, see Ceramic's LICENSE file.
package gpui.component.highlighter;

import gpui.App;
import textmate.IGrammar;
import textmate.OnigLib.IOnigLib;
import textmate.RawGrammar.IRawGrammar;
import textmate.Registry;
import textmate.Textmate;

/**
 * The TextMate grammars of the highlighter and the `textmate` registry that
 * compiles them.
 *
 * The bundled grammars (`GrammarCatalog`, files in `assets/gpui/grammars`)
 * are read through `gpui.App.defaultAssetSource()` when a language is first
 * highlighted: synchronously from the assets folder on targets with a file
 * system, from bytes preloaded with `preload` elsewhere (the web). A grammar
 * that cannot be read leaves its language unhighlighted.
 *
 * Applications can add grammars with `register`; a registered token takes
 * precedence over a bundled one.
 */
class TextMateGrammars {

    static var _onigLib:Null<IOnigLib> = null;

    static var _registry:Null<Registry> = null;

    static var infos:Null<Array<GrammarInfo>> = null;

    static var byToken:Null<Map<String, GrammarInfo>> = null;

    static var byScope:Null<Map<String, GrammarInfo>> = null;

    static final registeredRaw:Map<String, IRawGrammar> = new Map();

    /** Loaded grammars by root scope; a null value is a grammar that failed to load. */
    static final loaded:Map<String, Null<IGrammar>> = new Map();

    /** Bumped whenever a grammar is registered or the regex engine changes. */
    public static var generation(default, null):Int = 0;

    /** The regex engine (`PureOnigLib` unless replaced with `setOnigLib`). */
    public static function onigLib():IOnigLib {
        if (_onigLib == null)
            _onigLib = new PureOnigLib();
        return _onigLib;
    }

    /**
     * Replaces the regex engine (for instance onig.wasm on the web). The
     * grammars are compiled again with it the next time they are used.
     */
    public static function setOnigLib(lib:IOnigLib):Void {
        _onigLib = lib;
        resetRegistry();
    }

    /** Every known grammar, bundled ones first. */
    public static function all():Array<GrammarInfo> {
        ensureInfos();
        return infos.copy();
    }

    /** The grammar a token (a language name, alias or file extension) names, case insensitively. */
    public static function findByToken(token:String):Null<GrammarInfo> {
        ensureInfos();
        return byToken.get(token.toLowerCase());
    }

    public static function findByScope(scopeName:String):Null<GrammarInfo> {
        ensureInfos();
        return byScope.get(scopeName);
    }

    /**
     * Registers a grammar given as the content of a `.tmLanguage.json` (or
     * plist `.tmLanguage`) file. `tokens` are the names it is found by, in
     * addition to `name`.
     */
    public static function register(name:String, content:String, ?tokens:Array<String>, ?filePath:String):GrammarInfo {
        final raw = Textmate.parseRawGrammar(content, filePath != null ? filePath : name + '.json');
        ensureInfos();
        final allTokens = [name.toLowerCase()];
        if (tokens != null)
            for (token in tokens)
                if (!allTokens.contains(token.toLowerCase()))
                    allTokens.push(token.toLowerCase());
        final info = new GrammarInfo(name, name, raw.scopeName, null, allTokens, [], []);
        registeredRaw.set(raw.scopeName, raw);
        infos.push(info);
        for (token in allTokens)
            byToken.set(token, info);
        byScope.set(raw.scopeName, info);
        resetRegistry();
        return info;
    }

    /**
     * The compiled grammar of `info`, loading it and the grammars it
     * embeds when needed, or null when its file cannot be read.
     */
    public static function grammar(info:GrammarInfo):Null<IGrammar> {
        if (loaded.exists(info.scopeName))
            return loaded.get(info.scopeName);
        // The registry asks `loadRawGrammar` for the grammars this one
        // includes (embedded languages) while it loads it.
        final grammar = try registry().loadGrammar(info.scopeName) catch (e:Dynamic) {
            ceramic.Shortcuts.log.warning('Failed to load grammar ${info.scopeName}: $e');
            null;
        }
        loaded.set(info.scopeName, grammar);
        return grammar;
    }

    /**
     * Loads the files of the bundled grammars of `languages` (tokens, as
     * accepted by `findByToken`) and of the grammars they embed, so they can
     * be used on targets without a file system. All the bundled grammars
     * when `languages` is null.
     */
    public static function preload(languages:Null<Array<String>>, done:Bool->Void):Void {
        ensureInfos();
        final files:Array<String> = [];
        final seen:Map<String, Bool> = new Map();
        function add(info:Null<GrammarInfo>):Void {
            if (info == null || seen.exists(info.name))
                return;
            seen.set(info.name, true);
            if (info.file != null)
                files.push(GrammarCatalog.FOLDER + '/' + info.file);
            for (name in info.embedded)
                add(findByToken(name));
        }
        if (languages == null) {
            for (info in infos)
                add(info);
        }
        else {
            for (language in languages)
                add(findByToken(language));
        }
        App.defaultAssetSource().preload(files, success -> {
            // A grammar that failed (or loaded without an embedded language)
            // before its files were there loads again.
            resetRegistry();
            done(success);
        });
    }

    static function registry():Registry {
        if (_registry == null) {
            _registry = new Registry({
                onigLib: onigLib(),
                loadGrammar: loadRawGrammar,
                getInjections: injectionsFor
            });
        }
        return _registry;
    }

    static function resetRegistry():Void {
        _registry = null;
        loaded.clear();
        generation++;
    }

    static function loadRawGrammar(scopeName:String):Null<IRawGrammar> {
        final raw = registeredRaw.get(scopeName);
        if (raw != null)
            return raw;
        final info = findByScope(scopeName);
        if (info == null || info.file == null)
            return null;
        final path = GrammarCatalog.FOLDER + '/' + info.file;
        final bytes = App.defaultAssetSource().load(path);
        if (bytes == null)
            return null;
        return Textmate.parseRawGrammar(bytes.toString(), path);
    }

    static function injectionsFor(scopeName:String):Null<Array<String>> {
        ensureInfos();
        var result:Null<Array<String>> = null;
        for (info in infos) {
            if (info.injectTo.contains(scopeName)) {
                if (result == null)
                    result = [];
                result.push(info.scopeName);
            }
        }
        return result;
    }

    static function ensureInfos():Void {
        if (infos != null)
            return;
        infos = [];
        byToken = new Map();
        byScope = new Map();
        for (info in GrammarCatalog.ENTRIES) {
            infos.push(info);
            byScope.set(info.scopeName, info);
            for (token in info.tokens)
                if (!byToken.exists(token))
                    byToken.set(token, info);
        }
    }

}
