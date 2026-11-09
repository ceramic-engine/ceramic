// New code for Cityscape (not a port): the TextMate grammars of a Cityscape context.
// It does what loreline-monaco's provider.js (SimpleLanguageInfoProvider, TokensProviderCache)
// and VS Code's TextMateTokenizationFeature do: a vscode-textmate registry, one tokenizer per language.
package cityscape.textmate;

import cityscape.Cityscape;
import cityscape.base.common.Color;
import cityscape.base.common.Lifecycle;
import cityscape.common.EncodedTokenAttributes.StandardTokenType;
import cityscape.common.Languages;
import haxe.extern.EitherType;
import textmate.IGrammar;
import textmate.OnigLib.IOnigLib;
import textmate.OrderedMap;
import textmate.RawGrammar.IRawGrammar;
import textmate.Registry;
import textmate.Textmate;
import textmate.Theme;

/**
 * How a TextMate grammar is registered.
 */
typedef ITextMateGrammarDefinition = {
    /**
     * The language the grammar tokenizes (must be registered in the
     * context's language service). Null for a grammar that is only included
     * or embedded by other grammars.
     */
    @:optional var languageId:String;

    /**
     * The grammar: the text of a `.tmLanguage.json` file (preferred: key
     * order is kept on every target), a plist `.tmLanguage` text with
     * `path` ending in `.tmLanguage`/`.plist`, or an already parsed object
     * (`IRawGrammar`, or anonymous structures).
     */
    var grammar:EitherType<String, Dynamic>;

    /**
     * The file name, used to choose the parser of a text grammar (JSON by default).
     */
    @:optional var path:String;

    /**
     * Scope names of embedded languages, mapped to language ids (VS Code's
     * `embeddedLanguages` of a grammar contribution).
     */
    @:optional var embeddedLanguages:Map<String, String>;

    /**
     * Scope selectors mapped to token types (VS Code's `tokenTypes`).
     */
    @:optional var tokenTypes:Map<String, StandardTokenType>;

    /**
     * The scopes whose brackets are balanced (VS Code's
     * `balancedBracketScopes` of a grammar contribution). Null gives VS
     * Code's default, `['*']`: the brackets of every token count for the
     * bracket pairs (colorization, matching, guides) unless they are in a
     * string, a comment or a regular expression.
     */
    @:optional var balancedBracketSelectors:Array<String>;

    /**
     * The scopes whose brackets are not balanced (VS Code's
     * `unbalancedBracketScopes`, `[]` by default).
     */
    @:optional var unbalancedBracketSelectors:Array<String>;

    /**
     * Scope names of the grammars this one is injected into (VS Code's `injectTo`).
     */
    @:optional var injectTo:Array<String>;
}

private typedef GrammarEntry = {
    final scopeName:String;
    final definition:ITextMateGrammarDefinition;
    var raw:Null<IRawGrammar>;
}

/**
 * The TextMate grammars and the TextMate theme of a `Cityscape` context.
 *
 * - `registerGrammar` adds a grammar; when it names a language, a
 *   tokenization support is registered for that language in the context's
 *   tokenization registry (created on first use, like VS Code's lazy
 *   tokenization support factories; Monaco's `setTokensProvider` of
 *   loreline-monaco creates it eagerly, the tokens are the same).
 * - `setTheme` sets the token colors (a tmTheme `{name, settings}` or VS Code
 *   `{tokenColors, colors}` theme). The color map of the registry becomes
 *   the token color map of the context (`tokenizationRegistry.setColorMap`),
 *   which makes every model tokenize again: visible lines at once, the rest
 *   in the background. Theme changes are live, token colors included (what
 *   loreline-monaco could not do without reloading).
 *
 * The regex engine is onig.wasm on the web when Glaze loaded it, else the
 * pure Haxe Oniguruma (`OnigLibs`).
 */
class TextMateService extends Disposable {

    final _context:Cityscape;

    final _onigLib:IOnigLib;

    var _registry:Registry;

    final _grammars = new Map<String, GrammarEntry>();

    final _scopeByLanguage = new Map<String, String>();

    final _injections = new Map<String, Array<String>>();

    final _registrations = new Map<String, IDisposable>();

    var _rawTheme:Null<IRawTheme> = null;

    /**
     * Milliseconds a line may take before its tokenization stops (0: no
     * limit, like loreline-monaco). VS Code uses 500. Applies to the
     * tokenizers created afterwards.
     */
    public var timeLimitMs:Int = 0;

    /**
     * Lines longer than this are not tokenized (0: no limit, like Monaco's
     * standalone editor). VS Code's `editor.maxTokenizationLineLength` is 20000.
     */
    public var maxTokenizationLineLength:Int = 0;

    public function new(context:Cityscape, ?onigLib:IOnigLib) {
        super();
        _context = context;
        _onigLib = onigLib != null ? onigLib : OnigLibs.create();
        _registry = _createRegistry();
    }

    /**
     * The regex engine in use.
     */
    public var onigLib(get, never):IOnigLib;
    inline function get_onigLib():IOnigLib {
        return _onigLib;
    }

    function _createRegistry():Registry {
        return new Registry({
            onigLib: _onigLib,
            theme: _rawTheme,
            loadGrammar: scopeName -> _loadRawGrammar(scopeName),
            getInjections: scopeName -> _injections.get(scopeName)
        });
    }

    function _loadRawGrammar(scopeName:String):Null<IRawGrammar> {
        final entry = _grammars.get(scopeName);
        if (entry == null) {
            return null;
        }
        if (entry.raw == null) {
            final grammar:Dynamic = entry.definition.grammar;
            if (Std.isOfType(grammar, std.String)) {
                final path = entry.definition.path != null ? entry.definition.path : scopeName + '.tmLanguage.json';
                entry.raw = Textmate.parseRawGrammar(grammar, path);
            }
            else {
                entry.raw = IRawGrammar.fromDynamic(grammar);
            }
        }
        return entry.raw;
    }

    /**
     * Registers a grammar. Returns a disposable that unregisters it.
     */
    public function registerGrammar(definition:ITextMateGrammarDefinition):IDisposable {
        final scopeName = _readScopeName(definition);
        _grammars.set(scopeName, {scopeName: scopeName, definition: definition, raw: null});
        if (definition.injectTo != null) {
            for (target in definition.injectTo) {
                var list = _injections.get(target);
                if (list == null) {
                    list = [];
                    _injections.set(target, list);
                }
                if (list.indexOf(scopeName) == -1) {
                    list.push(scopeName);
                }
            }
        }
        // A new registry so that grammars already compiled see the change
        _resetRegistry();

        final languageId = definition.languageId;
        if (languageId != null) {
            _scopeByLanguage.set(languageId, scopeName);
            _registerTokenizationSupport(languageId);
        }

        return Lifecycle.toDisposable(() -> {
            if (_grammars.get(scopeName) == null || _grammars.get(scopeName).definition != definition) {
                return;
            }
            _grammars.remove(scopeName);
            if (languageId != null && _scopeByLanguage.get(languageId) == scopeName) {
                _scopeByLanguage.remove(languageId);
                final registration = _registrations.get(languageId);
                if (registration != null) {
                    _registrations.remove(languageId);
                    registration.dispose();
                }
            }
            _resetRegistry();
        });
    }

    function _readScopeName(definition:ITextMateGrammarDefinition):String {
        final grammar:Dynamic = definition.grammar;
        if (Std.isOfType(grammar, std.String)) {
            final path = definition.path != null ? definition.path : 'grammar.tmLanguage.json';
            final raw = Textmate.parseRawGrammar(grammar, path);
            return raw.scopeName;
        }
        return IRawGrammar.fromDynamic(grammar).scopeName;
    }

    function _registerTokenizationSupport(languageId:String):Void {
        final previous = _registrations.get(languageId);
        if (previous != null) {
            previous.dispose();
        }
        final factory = new LazyTokenizationSupport<TextMateTokenizationSupportDisposable>(() -> {
            final support = createTokenizationSupport(languageId);
            return support != null ? new TextMateTokenizationSupportDisposable(support) : null;
        });
        _registrations.set(languageId, _context.tokenizationRegistry.registerFactory(languageId, new LazyTokenizationSupportAdapter(factory)));
        if (_context.languageService.hasRequestedRichLanguageFeatures(languageId)) {
            // A model of this language exists: create the tokenizer now (Monaco
            // creates it when a model requests the language)
            _context.tokenizationRegistry.getOrCreate(languageId);
        }
    }

    /**
     * Creates the tokenizer of a language (null when it has no grammar or
     * the grammar cannot be loaded).
     */
    public function createTokenizationSupport(languageId:String):Null<TextMateTokenizationSupport> {
        final scopeName = _scopeByLanguage.get(languageId);
        if (scopeName == null) {
            return null;
        }
        final entry = _grammars.get(scopeName);
        final definition = entry.definition;
        final codec = _context.languageService.languageIdCodec;
        final encodedLanguageId:Int = codec.encodeLanguageId(languageId);

        var embeddedLanguages:Null<OrderedMap<Int>> = null;
        if (definition.embeddedLanguages != null) {
            embeddedLanguages = new OrderedMap<Int>();
            for (scope => embeddedLanguageId in definition.embeddedLanguages) {
                final id:Int = codec.encodeLanguageId(embeddedLanguageId);
                if (id != 0) {
                    embeddedLanguages.set(scope, id);
                }
            }
        }
        var tokenTypes:Null<OrderedMap<textmate.EncodedTokenAttributes.StandardTokenType>> = null;
        if (definition.tokenTypes != null) {
            tokenTypes = new OrderedMap();
            for (selector => type in definition.tokenTypes) {
                tokenTypes.set(selector, (type : Int));
            }
        }

        final grammar = _registry.loadGrammarWithConfiguration(scopeName, encodedLanguageId, {
            embeddedLanguages: embeddedLanguages,
            tokenTypes: tokenTypes,
            // VS Code's grammar contributions: `asStringArray(grammar.balancedBracketScopes, ['*'])`
            // and `asStringArray(grammar.unbalancedBracketScopes, [])`
            balancedBracketSelectors: definition.balancedBracketSelectors != null ? definition.balancedBracketSelectors : ['*'],
            unbalancedBracketSelectors: definition.unbalancedBracketSelectors != null ? definition.unbalancedBracketSelectors : []
        });
        if (grammar == null) {
            return null;
        }
        final containsEmbeddedLanguages = embeddedLanguages != null && embeddedLanguages.keys().length > 0;
        return new TextMateTokenizationSupport(grammar, Textmate.INITIAL, containsEmbeddedLanguages, encodedLanguageId, timeLimitMs, maxTokenizationLineLength);
    }

    /**
     * Sets the token colors.
     *
     * `theme` is a tmTheme style object `{name?, settings: [...]}` (what
     * loreline-monaco gives to vscode-textmate), or a VS Code color theme
     * `{tokenColors: [...], colors?}`, whose `tokenColors` become the
     * settings, after a default entry made of `colors['editor.foreground']`
     * and `colors['editor.background']` when the theme has no scope-less
     * entry (as VS Code does). Null clears the theme.
     *
     * The color map becomes the context's token color map, and every model
     * using a TextMate tokenizer of this context is tokenized again.
     *
     * This sets the TextMate theme directly. With the theme service of the
     * context (`Cityscape.themeService`, Monaco's `defineTheme`/`setTheme`),
     * the TextMate theme follows the current theme (its `tokenColors`, or
     * its Monaco rules) and this method is not needed.
     */
    public function setTheme(theme:Dynamic):Void {
        _rawTheme = toRawTheme(theme);
        _registry.setTheme(_rawTheme);
        _applyColorMap();
    }

    /**
     * Gives the TextMate registry the token rules of a theme of the theme
     * service (`IStandaloneTheme.getTextMateSettings`) and returns its color
     * map, for `StandaloneThemeService.tokenColorMapProvider`: the theme
     * service then makes it the context's token color map.
     */
    public function colorMapForTheme(theme:cityscape.standalone.common.StandaloneTheme.IStandaloneTheme):Array<Color> {
        _rawTheme = IRawTheme.fromDynamic({name: theme.themeName, settings: theme.getTextMateSettings()});
        _registry.setTheme(_rawTheme);
        return _colorsOf(_registry.getColorMap());
    }

    static function _colorsOf(colorMap:Array<String>):Array<Color> {
        final colors:Array<Color> = [];
        for (i in 0...colorMap.length) {
            final hex = colorMap[i];
            colors.push(hex != null ? Color.fromHex(hex) : null);
        }
        return colors;
    }

    /**
     * The token colors of the current theme (`#rrggbb` or `#rrggbbaa`
     * strings), indexed by `ColorId`; index 0 is unused.
     */
    public function getColorMap():Array<String> {
        return _registry.getColorMap();
    }

    function _applyColorMap():Void {
        // Fires onDidChange for every language: the models tokenize again
        _context.tokenizationRegistry.setColorMap(_colorsOf(_registry.getColorMap()));
    }

    function _resetRegistry():Void {
        _registry.dispose();
        _registry = _createRegistry();
        final languages = [for (languageId in _scopeByLanguage.keys()) languageId];
        // Tokenizers created from the old registry are replaced
        for (languageId in languages) {
            _registerTokenizationSupport(languageId);
        }
    }

    /**
     * Converts a theme object to vscode-textmate's raw theme (see `setTheme`).
     */
    public static function toRawTheme(theme:Dynamic):Null<IRawTheme> {
        if (theme == null) {
            return null;
        }
        if (Std.isOfType(theme, IRawTheme)) {
            return theme;
        }
        final settings:Dynamic = textmate.RawGrammar.RawValue.field(theme, 'settings');
        if (settings != null && Std.isOfType(settings, Array)) {
            return IRawTheme.fromDynamic(theme);
        }
        final name:Null<String> = textmate.RawGrammar.RawValue.string(textmate.RawGrammar.RawValue.field(theme, 'name'));
        final tokenColors:Array<Dynamic> = {
            final t:Dynamic = textmate.RawGrammar.RawValue.field(theme, 'tokenColors');
            (t != null && Std.isOfType(t, Array)) ? t : [];
        };
        final result:Array<Dynamic> = [];
        var hasDefault = false;
        for (rule in tokenColors) {
            if (textmate.RawGrammar.RawValue.field(rule, 'scope') == null) {
                hasDefault = true;
                break;
            }
        }
        if (!hasDefault) {
            final colors:Dynamic = textmate.RawGrammar.RawValue.field(theme, 'colors');
            final foreground:Null<String> = colors != null ? textmate.RawGrammar.RawValue.string(textmate.RawGrammar.RawValue.field(colors, 'editor.foreground')) : null;
            final background:Null<String> = colors != null ? textmate.RawGrammar.RawValue.string(textmate.RawGrammar.RawValue.field(colors, 'editor.background')) : null;
            if (foreground != null || background != null) {
                result.push({settings: {foreground: foreground, background: background}});
            }
        }
        for (rule in tokenColors) {
            result.push(rule);
        }
        return IRawTheme.fromDynamic({name: name, settings: result});
    }

    override public function dispose():Void {
        for (registration in _registrations) {
            registration.dispose();
        }
        _registrations.clear();
        _registry.dispose();
        super.dispose();
    }

}

/**
 * A `TextMateTokenizationSupport` that can be disposed (for `LazyTokenizationSupport`).
 */
private class TextMateTokenizationSupportDisposable implements IDisposable {

    public final support:TextMateTokenizationSupport;

    public function new(support:TextMateTokenizationSupport) {
        this.support = support;
    }

    public function dispose():Void {}

}

/**
 * Exposes the lazily created `TextMateTokenizationSupport` as an
 * `ILazyTokenizationSupport<ITokenizationSupport>`.
 */
private class LazyTokenizationSupportAdapter implements ILazyTokenizationSupport<ITokenizationSupport> {

    final _lazy:LazyTokenizationSupport<TextMateTokenizationSupportDisposable>;

    public function new(lazy:LazyTokenizationSupport<TextMateTokenizationSupportDisposable>) {
        _lazy = lazy;
    }

    public function getTokenizationSupport():Null<ITokenizationSupport> {
        final d = _lazy.getTokenizationSupport();
        return d != null ? d.support : null;
    }

}
