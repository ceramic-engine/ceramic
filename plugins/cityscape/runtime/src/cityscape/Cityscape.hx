package cityscape;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.base.common.Uri;
import cityscape.common.Languages.ITokenizationSupport;
import cityscape.common.Model.ITextModel;
import cityscape.common.services.MarkerDecorationsService;
import cityscape.common.services.ModelService;
import cityscape.platform.commands.common.Commands;
import cityscape.platform.contextkey.view.ContextKeyService;
import cityscape.platform.keybinding.common.KeybindingsRegistry;
import cityscape.platform.markers.common.MarkerService;
import cityscape.platform.markers.common.Markers;
import cityscape.standalone.StandaloneServices;
import cityscape.view.EditorExtensions.EditorExtensionsRegistry;
import cityscape.common.TokenizationRegistry;
import cityscape.common.languages.LanguageConfigurationRegistry.LanguageConfigurationService;
import cityscape.common.languages.ModesRegistry.EditorModesRegistry;
import cityscape.common.services.BackgroundScheduler;
import cityscape.common.services.LanguageService;
import cityscape.standalone.StandaloneThemeService;
import cityscape.standalone.common.StandaloneTheme.IStandaloneThemeData;
import cityscape.textmate.TextMateService;

#if (!plugin_glaze && !display)
#error "Cityscape needs Glaze: list both glaze and cityscape in the plugins of the project's ceramic.yml"
#end

/**
 * A keybinding rule of `Cityscape.addKeybindingRule(s)` (Monaco's public
 * `IKeybindingRule`): `when` is a `when` clause (a string).
 */
typedef IKeybindingRuleDescriptor = {
    /** `KeyMod.CtrlCmd | KeyCode.KeyS`, or `KeyCodes.KeyChord(a, b)` */
    var keybinding:Int;
    /** The command id, `'-id'` to remove a keybinding of `id`, null to unbind */
    @:optional var command:Null<String>;
    @:optional var commandArgs:Any;
    @:optional var when:Null<String>;
}

/**
 * The context shared by a set of Cityscape editors: what Monaco keeps in
 * services and registries (languages and grammars, themes, providers,
 * models, LSP clients). Cityscape has no dependency injection and no editor
 * state in statics: services are fields of a context, and several contexts
 * can live side by side to keep two uses apart.
 *
 * The static functions are Monaco's `monaco.editor` functions on the
 * default context (or on the context given as the last argument):
 * `Cityscape.createModel`, `getModel`, `getModels`, `setModelMarkers`,
 * `getModelMarkers`, `defineTheme`, `setTheme`, `addKeybindingRule(s)`,
 * `registerCommand`.
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
     * The registries of the language feature providers (Monaco's
     * `ILanguageFeaturesService`): folding ranges...
     */
    public final languageFeaturesService:cityscape.common.services.LanguageFeaturesService = new cityscape.common.services.LanguageFeaturesService();

    /**
     * Decoration styles registered by class name
     * (`registerDecorationStyle`): Monaco's class names keep working with
     * Cityscape's typed decoration style.
     */
    public final decorationStyles:cityscape.common.DecorationStyle.DecorationStyles = new cityscape.common.DecorationStyle.DecorationStyles();

    /**
     * The translations of the editor's texts (Monaco's `nls`). Load a table
     * before creating the first editor of the context.
     */
    public final nls:Nls = new Nls();

    /**
     * The commands of the context (Monaco's `CommandsRegistry`).
     */
    public final commandsRegistry:CommandsRegistry;

    /**
     * The default keybindings of the context (Monaco's `KeybindingsRegistry`).
     */
    public final keybindingsRegistry:KeybindingsRegistry;

    /**
     * The root context key service; each editor has a scoped one.
     */
    public final contextKeyService:ContextKeyService;

    /**
     * Runs the commands of the context (Monaco's `ICommandService`).
     */
    public final commandService:StandaloneCommandService;

    /**
     * The keybindings of the context: the default ones and the ones added
     * with `addCommand`, `addAction`, `addKeybindingRule(s)`.
     */
    public final keybindingService:StandaloneKeybindingService;

    /**
     * The editors of the context and the focused one.
     */
    public final codeEditorService:CodeEditorService;

    /**
     * The models created by `Cityscape.createModel` (Monaco's model service).
     */
    public final modelService:ModelService;

    /**
     * The markers of the models (Monaco's `IMarkerService`).
     */
    public final markerService:MarkerService;

    /**
     * Renders the markers as decorations.
     */
    public final markerDecorationsService:MarkerDecorationsService;

    var _editorExtensions:Null<EditorExtensionsRegistry> = null;

    /**
     * The editor commands, actions and contributions of the context,
     * registered (`EditorAll.registerAll`) the first time this is read.
     */
    public var editorExtensions(get, never):EditorExtensionsRegistry;
    function get_editorExtensions():EditorExtensionsRegistry {
        if (_editorExtensions == null) {
            final registry = new EditorExtensionsRegistry(this);
            _editorExtensions = registry;
            EditorAll.registerAll(registry);
        }
        return _editorExtensions;
    }

    public function new() {
        this.undoRedoService = new cityscape.platform.undoRedo.common.UndoRedoService();
        commandsRegistry = new CommandsRegistry();
        keybindingsRegistry = new KeybindingsRegistry(commandsRegistry);
        contextKeyService = new ContextKeyService();
        commandService = new StandaloneCommandService(this);
        keybindingService = new StandaloneKeybindingService(contextKeyService, commandService, keybindingsRegistry);
        codeEditorService = new CodeEditorService();
        modelService = new ModelService(this);
        markerService = new MarkerService();
        markerDecorationsService = new MarkerDecorationsService(modelService, markerService);
        registerDefaultDecorationStyles();
        backgroundScheduler = new BackgroundScheduler();
        modesRegistry = new EditorModesRegistry();
        tokenizationRegistry = new TokenizationRegistry<ITokenizationSupport>();
        languageService = new LanguageService(modesRegistry, tokenizationRegistry);
        languageConfigurationService = new LanguageConfigurationService(languageService);
        themeService = new StandaloneThemeService(tokenizationRegistry);
    }

    /**
     * The styles of Monaco's built-in decoration class names (its CSS):
     * the squiggles of the markers, in the theme colors.
     */
    function registerDefaultDecorationStyles():Void {
        decorationStyles.registerDecorationStyle('squiggly-error', {underline: {color: {id: 'editorError.foreground'}, wavy: true}});
        decorationStyles.registerDecorationStyle('squiggly-warning', {underline: {color: {id: 'editorWarning.foreground'}, wavy: true}});
        decorationStyles.registerDecorationStyle('squiggly-info', {underline: {color: {id: 'editorInfo.foreground'}, wavy: true}});
        decorationStyles.registerDecorationStyle('squiggly-hint', {underline: {color: {id: 'editorHint.foreground'}, thickness: 1}});
        decorationStyles.registerDecorationStyle('squiggly-inline-unnecessary', {opacity: 0.667});
        decorationStyles.registerDecorationStyle('squiggly-inline-deprecated', {strikethrough: {}});
    }

    static inline function ctx(context:Null<Cityscape>):Cityscape {
        return context != null ? context : defaultContext;
    }

    //#region monaco.editor

    /**
     * Creates a model (`monaco.editor.createModel`): `language` is a
     * language id (guessed from `uri` when null, plain text otherwise),
     * `uri` its uri (`inmemory://model/N` when null).
     */
    public static function createModel(value:String, ?language:String, ?uri:Uri, ?context:Cityscape):ITextModel {
        final c = ctx(context);
        var languageId = language;
        if (languageId == null && uri != null) {
            final firstLine = value.split('\n')[0];
            languageId = c.languageService.guessLanguageIdByFilepathOrFirstLine(uri, firstLine);
        }
        return c.modelService.createModel(value, languageId != null ? languageId : 'plaintext', uri);
    }

    /**
     * The model with this uri (`monaco.editor.getModel`).
     */
    public static function getModel(uri:Uri, ?context:Cityscape):Null<ITextModel> {
        return ctx(context).modelService.getModel(uri);
    }

    /**
     * The models created with `createModel` and not disposed
     * (`monaco.editor.getModels`).
     */
    public static function getModels(?context:Cityscape):Array<ITextModel> {
        return ctx(context).modelService.getModels();
    }

    /**
     * Sets the markers of `owner` for a model (`monaco.editor.setModelMarkers`),
     * in the context of the model.
     */
    public static function setModelMarkers(model:ITextModel, owner:String, markers:Array<IMarkerData>):Void {
        if (model != null) {
            contextOfModel(model).markerService.changeOne(owner, model.uri, markers);
        }
    }

    /**
     * Removes the markers of `owner` on every model (`monaco.editor.removeAllMarkers`).
     */
    public static function removeAllMarkers(owner:String, ?context:Cityscape):Void {
        ctx(context).markerService.changeAll(owner, []);
    }

    /**
     * The markers (`monaco.editor.getModelMarkers`), filtered by owner,
     * resource, severities, count.
     */
    public static function getModelMarkers(filter:IMarkerReadFilter, ?context:Cityscape):Array<IMarker> {
        return ctx(context).markerService.read(filter);
    }

    /**
     * Fired when markers change (`monaco.editor.onDidChangeMarkers`).
     */
    public static function onDidChangeMarkers(listener:(resources:Array<Uri>) -> Void, ?context:Cityscape):IDisposable {
        return ctx(context).markerService.onMarkerChanged(listener);
    }

    /**
     * Defines a theme (`monaco.editor.defineTheme`).
     */
    public static function defineTheme(themeName:String, themeData:IStandaloneThemeData, ?context:Cityscape):Void {
        ctx(context).themeService.defineTheme(themeName, themeData);
    }

    /**
     * Switches to a theme (`monaco.editor.setTheme`).
     */
    public static function setTheme(themeName:String, ?context:Cityscape):Void {
        ctx(context).themeService.setTheme(themeName);
    }

    /**
     * Adds a keybinding rule (`monaco.editor.addKeybindingRule`): a
     * `command` of `'-id'` removes the default keybinding of `id` (on this
     * keybinding, or every keybinding of `id` when `keybinding` is 0), null
     * unbinds the keybinding.
     */
    public static function addKeybindingRule(rule:IKeybindingRuleDescriptor, ?context:Cityscape):IDisposable {
        return addKeybindingRules([rule], context);
    }

    /**
     * Adds keybinding rules (`monaco.editor.addKeybindingRules`).
     */
    public static function addKeybindingRules(rules:Array<IKeybindingRuleDescriptor>, ?context:Cityscape):IDisposable {
        final c = ctx(context);
        // the default keybindings must exist before their removals are resolved
        c.editorExtensions;
        return c.keybindingService.addDynamicKeybindings([for (rule in rules) ({
            keybinding: rule.keybinding,
            command: rule.command,
            commandArgs: rule.commandArgs,
            when: cityscape.platform.contextkey.common.ContextKey.ContextKeyExpr.deserialize(rule.when)
        } : IStandaloneKeybindingRule)]);
    }

    /**
     * Registers a command (`monaco.editor.registerCommand`).
     */
    public static function registerCommand(id:String, handler:ICommandHandler, ?context:Cityscape):IDisposable {
        return ctx(context).commandsRegistry.registerCommandHandler(id, handler);
    }

    static function contextOfModel(model:ITextModel):Cityscape {
        final textModel = Std.downcast(model, cityscape.common.model.TextModel);
        return textModel != null && textModel.context != null ? textModel.context : defaultContext;
    }

    //#endregion

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
