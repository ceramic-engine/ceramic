package cityscape;

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
 * TODO(steps 1 and 3): the services are added here as they are ported
 * (model service, language registry, theme service, undo/redo, commands and
 * keybindings).
 */
class Cityscape {

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

    public function new() {}

}
