package cityscape;

import cityscape.common.Languages.ITokenizationSupport;
import cityscape.common.TokenizationRegistry;
import cityscape.common.languages.LanguageConfigurationRegistry.LanguageConfigurationService;
import cityscape.common.languages.ModesRegistry.EditorModesRegistry;
import cityscape.common.services.BackgroundScheduler;
import cityscape.common.services.LanguageService;
import cityscape.standalone.StandaloneThemeService;
import cityscape.textmate.TextMateService;

#if (!plugin_glaze && !display)
#error "Cityscape needs Glaze: list both glaze and cityscape in the plugins of the project's ceramic.yml"
#end

/**
 * The context shared by a set of Cityscape editors: what Monaco keeps in
 * services and registries (languages and grammars, themes, providers,
 * models, LSP clients). Cityscape has no dependency injection and no editor
 * state in statics: services are fields of a context, and several contexts
 * can live side by side to keep two uses apart.
 *
 * TODO(step 3): the other services are added here as they are ported
 * (model service, undo/redo, commands and keybindings).
 */
class Cityscape {

    /**
     * The undo/redo stacks of the models of this context (Monaco's
     * `IUndoRedoService`).
     */
    public final undoRedoService:cityscape.platform.undoRedo.common.UndoRedoService;

    static var _defaultContext:Null<Cityscape> = null;

    /**
     * The context used when an editor or a model is created without one.
     */
    public static var defaultContext(get, never):Cityscape;
    static function get_defaultContext():Cityscape {
        if (_defaultContext == null) {
            _defaultContext = new Cityscape();
        }
        return _defaultContext;
    }

    /**
     * The registered languages (Monaco's global `ModesRegistry`).
     */
    public final modesRegistry:EditorModesRegistry;

    /**
     * The tokenizers of the languages and the token color map (Monaco's
     * global `TokenizationRegistry`).
     */
    public final tokenizationRegistry:TokenizationRegistry<ITokenizationSupport>;

    /**
     * The language service (Monaco's `ILanguageService`).
     */
    public final languageService:LanguageService;

    /**
     * The language configurations: brackets, comments, auto closing pairs,
     * indentation and on enter rules (Monaco's
     * `ILanguageConfigurationService`).
     */
    public final languageConfigurationService:LanguageConfigurationService;

    /**
     * Runs the background work of the models (background tokenization) with
     * one time budget per frame shared by all of them (Monaco uses idle
     * callbacks).
     */
    public final backgroundScheduler:BackgroundScheduler;

    /**
     * The registries of the language feature providers (Monaco's
     * `ILanguageFeaturesService`): folding ranges...
     */
    public final languageFeaturesService:cityscape.common.services.LanguageFeaturesService = new cityscape.common.services.LanguageFeaturesService();

    var _textMate:Null<TextMateService> = null;

    /**
     * The TextMate grammars and token theme of the context, created on first use.
     */
    public var textMate(get, never):TextMateService;
    function get_textMate():TextMateService {
        if (_textMate == null) {
            final textMate = new TextMateService(this);
            _textMate = textMate;
            // The token colors follow the theme of the theme service
            themeService.tokenColorMapProvider = theme -> textMate.colorMapForTheme(theme);
            themeService.refreshColorMap();
        }
        return _textMate;
    }

    /**
     * The themes (Monaco's standalone theme service: `defineTheme`,
     * `setTheme`, theme colors, token color map).
     */
    public final themeService:StandaloneThemeService;

    /**
     * Decoration styles registered by class name
     * (`registerDecorationStyle`): Monaco's class names keep working with
     * Cityscape's typed decoration style.
     */
    public final decorationStyles:cityscape.common.DecorationStyle.DecorationStyles = new cityscape.common.DecorationStyle.DecorationStyles();

    public function new() {
        this.undoRedoService = new cityscape.platform.undoRedo.common.UndoRedoService();
        backgroundScheduler = new BackgroundScheduler();
        modesRegistry = new EditorModesRegistry();
        tokenizationRegistry = new TokenizationRegistry<ITokenizationSupport>();
        languageService = new LanguageService(modesRegistry, tokenizationRegistry);
        languageConfigurationService = new LanguageConfigurationService(languageService);
        themeService = new StandaloneThemeService(tokenizationRegistry);
    }

    /**
     * Gives a typed style to a decoration class name (`className`,
     * `inlineClassName`, `glyphMarginClassName`, `linesDecorationsClassName`,
     * `lineNumberClassName`, `marginClassName`, the class names of injected
     * text), for every editor of this context.
     */
    public function registerDecorationStyle(className:String, style:cityscape.common.DecorationStyle.IDecorationStyle):Void {
        decorationStyles.registerDecorationStyle(className, style);
    }

}
