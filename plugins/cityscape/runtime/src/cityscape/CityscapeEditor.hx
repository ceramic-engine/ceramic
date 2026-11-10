// New code for Cityscape (not a port): the editor as a persistent Glaze
// component (AUDIT B.13 recipe), with the API of Monaco's standalone code
// editor (standaloneCodeEditor.ts: addCommand, addAction, createContextKey).
package cityscape;

import cityscape.Cityscape;
import cityscape.base.common.Event;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle;
import cityscape.common.CursorEvents;
import cityscape.common.EditorCommon.ICommand;
import cityscape.common.EditorCommon.IContentSizeChangedEvent;
import cityscape.common.EditorCommon.IEditorAction;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorCommon.IEditorDecorationsCollection;
import cityscape.common.EditorCommon.IEditorViewState;
import cityscape.common.EditorCommon.IModelChangedEvent;
import cityscape.common.EditorCommon.INewScrollPosition;
import cityscape.common.EditorCommon.IScrollEvent;
import cityscape.common.EditorCommon.ScrollType;
import cityscape.common.Model;
import cityscape.common.TextModelEvents;
import cityscape.common.config.EditorOptions;
import cityscape.common.config.EditorViewOptions.EditorLayoutInfo;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.Selection;
import cityscape.common.model.TextModel;
import cityscape.platform.commands.common.Commands.ICommandHandler;
import cityscape.platform.contextkey.common.ContextKey;
import cityscape.platform.contextkey.view.ContextKeyService.AbstractContextKeyService;
import cityscape.platform.keybinding.common.Keybinding.IKeyboardEvent;
import cityscape.view.CityscapeView;
import cityscape.view.CityscapeViewElement;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorFontMeasurements;
import cityscape.view.KeyboardEvents;
import cityscape.view.config.EditorConfiguration;
import cityscape.view.widget.codeEditor.CodeEditorWidget;
import glaze.App;
import glaze.Component;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.KeyContext;
import glaze.MouseButton;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.Scrollbar;
import haxe.extern.EitherType;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * An action added to an editor (Monaco's `IActionDescriptor`).
 */
typedef IActionDescriptor = {
    /**
     * An unique identifier of the contributed action.
     */
    var id:String;
    /**
     * A label of the action that will be presented to the user.
     */
    var label:String;
    /**
     * Precondition rule: a `when` clause.
     */
    @:optional var precondition:String;
    /**
     * An array of keybindings for the action (`KeyMod.CtrlCmd | KeyCode.KeyS`).
     */
    @:optional var keybindings:Array<Int>;
    /**
     * The keybinding rule (condition on top of precondition).
     */
    @:optional var keybindingContext:String;
    /**
     * Control if the action should show up in the context menu and where.
     * The context menu of the editor has these default:
     *   navigation - The navigation group comes first in all cases.
     *   1_modification - This group comes next and contains commands that modify your code.
     *   9_cutcopypaste - The last default group with the basic editing commands.
     * You can also create your own group.
     * Defaults to null (don't show in context menu).
     */
    @:optional var contextMenuGroupId:String;
    /**
     * Control the order in the context menu group.
     */
    @:optional var contextMenuOrder:Float;
    /**
     * Method that will be executed when the action is triggered.
     * @param editor The editor instance is passed in as a convenience
     */
    var run:(editor:ICodeEditor, args:Array<Any>) -> Void;
}

/**
 * A Cityscape code editor, placed anywhere in a Glaze UI and sized by the
 * flex layout of its parent:
 *
 * ```haxe
 * div().flex().sizeFull().child(
 *     CityscapeEditor.component(model).options({wordWrap: 'on'}).flex1()
 * )
 * ```
 *
 * Each editor has its own view state (selections, scroll, wrapping, hidden
 * ranges revealed on its cursor lines) over a model that other editors may
 * show too; edits in one show in the others. When the model changes, the
 * editor keeps the view state of the previous one and restores it when that
 * model comes back.
 *
 * The props are applied when they change, without recreating the editor
 * (`model`, `options`, `wrappingIndentColumns` and the shortcuts
 * `fontSize`, `fontFamily`, `wordWrap`, `readOnly`, `lineNumbers`, `tabSize`).
 * The methods are Monaco's (`monaco.editor.IStandaloneCodeEditor`); the
 * whole `ICodeEditor` is `getEditor()`.
 *
 * Keys go to the editor that has the focus: its keybindings are resolved
 * like Monaco's (context keys, `when` clauses, chords); a key it does not
 * handle goes on to the bindings of the ancestors (app shortcuts).
 */
class CityscapeEditor extends Component implements Styled {

    static var LAST_GENERATED_COMMAND_ID = 0;

    /**
     * The text model shown.
     */
    @prop var model:Null<ITextModel> = null;

    /**
     * Monaco's editor options (`IEditorOptions`), applied with
     * `updateOptions` when they change.
     */
    @prop(unobserved) var options:Null<IEditorOptions> = null;

    /**
     * `fontSize` option (applied over `options`).
     */
    @prop var fontSize:Null<Float> = null;

    /**
     * `fontFamily` option (applied over `options`).
     */
    @prop var fontFamily:Null<String> = null;

    /**
     * `wordWrap` option: `'off'`, `'on'`, `'wordWrapColumn'`, `'bounded'`
     * (applied over `options`).
     */
    @prop var wordWrap:Null<String> = null;

    /**
     * `readOnly` option (applied over `options`).
     */
    @prop var readOnly:Null<Bool> = null;

    /**
     * `lineNumbers` option: `'on'`, `'off'`, `'relative'`, `'interval'`
     * (applied over `options`).
     */
    @prop var lineNumbers:Null<String> = null;

    /**
     * `tabSize` option (applied over `options`).
     */
    @prop var tabSize:Null<Int> = null;

    /**
     * The context (languages, themes, keybindings). When null: the context
     * of the initial model when it is a `TextModel`, else the default one.
     */
    @prop(unobserved) var context:Null<Cityscape> = null;

    /**
     * loreline-monaco's `[loreline]` wrapping patch: the extra indent of
     * wrapped lines in columns per level (`wrappingIndent` `indent` or
     * `deepIndent`), -1 for Monaco's tab stops.
     */
    @prop var wrappingIndentColumns:Int = -1;

    /**
     * Called once with the editor (tests, hosts), after the initial model is
     * set.
     */
    @prop(unobserved) var onCreate:Null<(editor:CityscapeEditor) -> Void> = null;

    /**
     * The style of the editor's root element (`Styled`).
     */
    @prop(unobserved) var surfaceStyle:Null<StyleRefinement> = null;

    var widget:Null<CodeEditorWidget> = null;
    var viewEntity:Null<Entity<CityscapeView>> = null;
    var appliedOptions:Null<IEditorOptions> = null;
    var appliedShortcuts:String = '';
    var lastPropModel:Null<ITextModel> = null;
    final ownDisposables = new DisposableStore();

    public function style():StyleRefinement {
        var style = surfaceStyle;
        if (style == null) {
            style = new StyleRefinement();
            (this : CityscapeEditor).surfaceStyle(style);
        }
        return style;
    }

    /**
     * The view of this editor (null before the first render).
     */
    public function getView():Null<Entity<CityscapeView>> {
        return viewEntity;
    }

    /**
     * The editor (Monaco's `ICodeEditor`): the methods, events and
     * contributions not repeated here.
     */
    public function getEditor():ICodeEditor {
        return widget;
    }

    override public function init(window:Window, cx:App):Void {
        final initialModel = model;
        final ctx = context != null ? context : (Std.isOfType(initialModel, TextModel) ? (cast initialModel : TextModel).context : Cityscape.defaultContext);
        if (ctx == null) {
            throw 'CityscapeEditor: no context';
        }
        final measurements = EditorFontMeasurements.forApp(cx);
        // Monaco's standalone editor writes its options to the configuration
        // of its services first: models created afterwards take their model
        // options (tabSize, insertSpaces, detectIndentation...) from there
        cityscape.standalone.StandaloneConfiguration.updateConfigurationService(ctx.configurationService, mergedOptions(), false);
        final configuration = new EditorConfiguration(false, mergedOptions(), {width: 600, height: 400}, (bare) -> measurements.readFontInfo(bare));
        final widget = new CodeEditorWidget(ctx, configuration);
        this.widget = widget;
        viewEntity = cityscape.base.common.DebugCounters.trackEntity(cx.newEntity((vcx:Context<CityscapeView>) -> new CityscapeView(vcx, widget, measurements)), cx);
        appliedOptions = options;
        appliedShortcuts = shortcutsKey();
        widget.setWrappingIndentColumns(wrappingIndentColumns);
        // The key context of the root lists the context keys: a key set after
        // the render (the contributions are created one app turn after the
        // editor, and set their keys then) renders the root again, otherwise
        // the dispatch tree keeps the keys of the last render
        final keyService = Std.downcast(widget.contextKeyService, AbstractContextKeyService);
        if (keyService != null) {
            final app = cx;
            final viewForHost = viewEntity;
            ownDisposables.add(keyService.onDidChangeContext(_ -> {
                final host = (viewForHost : CityscapeView).hostViewId;
                if (host != -1 && keyContextValue != null) {
                    app.notify(host);
                }
            }));
        }
        // The model is set before `onCreate`, which can then use the view model
        lastPropModel = model;
        widget.setModel(model);
        final callback = onCreate;
        if (callback != null) {
            callback(this);
        }
    }

    override public function destroy():Void {
        ownDisposables.dispose();
        final v = viewEntity;
        if (v != null) {
            (v : CityscapeView).disposeView();
        }
        cityscape.view.ViewEntities.release(v);
        viewEntity = null;
        final w = widget;
        if (w != null) {
            w.dispose();
        }
        widget = null;
    }

    /**
     * The font family of an editor whose host gives none (`fontFamily`
     * option or prop): JetBrains Mono, the monospace font bundled with
     * Glaze, the same on every target (the web cannot read system font
     * files). Monaco's default list (`EditorOptions.EDITOR_FONT_DEFAULTS`,
     * `Menlo, Monaco, 'Courier New', monospace` on macOS) is used only when
     * a host gives it.
     */
    public static inline final DEFAULT_FONT_FAMILY = 'JetBrains Mono';

    function shortcutsKey():String {
        return '' + fontSize + '|' + fontFamily + '|' + wordWrap + '|' + readOnly + '|' + lineNumbers + '|' + tabSize;
    }

    /**
     * `options` with the shortcut props over it.
     */
    function mergedOptions():IEditorOptions {
        final result:Dynamic = {};
        // The defaults of Monaco's standalone editor (editor.api.ts), under
        // the options given
        result.wrappingIndent = 'none';
        result.glyphMargin = false;
        result.autoIndent = 'advanced';
        result.overviewRulerLanes = 2;
        // Cityscape's own default (owner decision 2026-11-10, DEVIATIONS.md):
        // Glaze's bundled monospace font instead of Monaco's list of system
        // fonts, so that every target renders the same
        result.fontFamily = DEFAULT_FONT_FAMILY;
        final o = options;
        if (o != null) {
            for (field in Reflect.fields(o)) {
                Reflect.setField(result, field, Reflect.field(o, field));
            }
        }
        if (fontSize != null) {
            result.fontSize = fontSize;
        }
        if (fontFamily != null) {
            result.fontFamily = fontFamily;
        }
        if (wordWrap != null) {
            result.wordWrap = wordWrap;
        }
        if (readOnly != null) {
            result.readOnly = readOnly;
        }
        if (lineNumbers != null) {
            result.lineNumbers = lineNumbers;
        }
        if (tabSize != null) {
            result.tabSize = tabSize;
        }
        return result;
    }

    /**
     * The key context of the root: `CityscapeEditor`, and the context keys
     * of the editor Glaze can express (booleans set when true, string
     * values without dots), for the bindings of the host
     * (`CityscapeEditor && editorTextFocus`).
     */
    /**
     * The listeners of the editor's element, made once (the element is built
     * again at each render).
     */
    var listeners:Null<EditorListeners> = null;

    var keyContextValue:Null<KeyContext> = null;
    final keyContextChain:Array<cityscape.platform.contextkey.view.ContextKeyService.Context> = [];
    final keyContextVersions:Array<Int> = [];

    /**
     * `keyContextOf(widget)`, built again only when a value of the widget's
     * context or of its parents changed (their `version`) or the chain of
     * contexts changed.
     */
    function cachedKeyContext(widget:CodeEditorWidget):KeyContext {
        final service = Std.downcast(widget.contextKeyService, AbstractContextKeyService);
        if (service == null) {
            return keyContextOf(widget);
        }
        final existing = keyContextValue;
        if (existing != null) {
            var context = service.getContextValuesContainer(service.contextId);
            var i = 0;
            var same = true;
            while (context != null) {
                if (i >= keyContextChain.length || keyContextChain[i] != context || keyContextVersions[i] != context.version) {
                    same = false;
                    break;
                }
                context = context.parentContext();
                i++;
            }
            if (same && i == keyContextChain.length) {
                return existing;
            }
        }
        keyContextChain.resize(0);
        keyContextVersions.resize(0);
        var context = service.getContextValuesContainer(service.contextId);
        while (context != null) {
            keyContextChain.push(context);
            keyContextVersions.push(context.version);
            context = context.parentContext();
        }
        final created = keyContextOf(widget);
        keyContextValue = created;
        return created;
    }

    /**
     * The width of the vertical scrollbar band of the layout (Monaco's
     * `verticalScrollbarWidth`, the `scrollbar.verticalScrollbarSize`
     * option): the text area ends where it starts.
     */
    static function verticalScrollbarWidth(widget:CodeEditorWidget):Float {
        final layoutInfo = widget.getLayoutInfo();
        return layoutInfo != null ? layoutInfo.verticalScrollbarWidth : Scrollbar.width();
    }

    /**
     * The kit scrollbar sized to the layout's band: the kit look (a 6 pixel
     * thumb 4 pixels from the edge, 8 pixels when hovered or dragged) in its
     * own 16 pixel band, else thumbs no wider than `verticalSliderSize`,
     * centered when the band is too narrow for the kit's inset. The
     * Cityscape options `scrollbar.thumbColor` and `scrollbar.thumbRadius`
     * give the thumb's color and corner radius in every state.
     */
    static function styledScrollbar(scrollbar:Scrollbar, widget:CodeEditorWidget, view:cityscape.view.CityscapeView):Scrollbar {
        final options = widget.getOption(EditorOption.scrollbar);
        final thumbColor:Null<glaze.Hsla> = options.thumbColor != null ? view.paintState.parsedColor(options.thumbColor) : null;
        final thumbRadius:Null<Float> = options.thumbRadius;
        if (thumbColor != null || thumbRadius != null) {
            scrollbar.styles(s -> s
                .thumb(t -> thumbLook(t, thumbColor, thumbRadius))
                .thumbHover(t -> thumbLook(t, thumbColor, thumbRadius))
                .thumbActive(t -> thumbLook(t, thumbColor, thumbRadius))
            );
        }
        final width = verticalScrollbarWidth(widget);
        if (width == Scrollbar.width()) {
            return scrollbar;
        }
        final slider:Float = options.verticalSliderSize;
        inline function thumbWidth(kitWidth:Float):Float {
            return Math.max(0, Math.min(kitWidth, slider));
        }
        inline function inset(kitInset:Float, thumb:Float):Float {
            return Math.max(0, Math.min(kitInset, Math.floor((width - thumb) / 2)));
        }
        final normal = thumbWidth(KIT_THUMB_WIDTH);
        final active = thumbWidth(KIT_THUMB_ACTIVE_WIDTH);
        return scrollbar.styles(s -> s
            .track(t -> t.width(width))
            .thumb(t -> t.width(normal).inset(inset(KIT_THUMB_INSET, normal)))
            .thumbHover(t -> t.width(active).inset(inset(KIT_THUMB_INSET, active)))
            .thumbActive(t -> t.width(active).inset(inset(KIT_THUMB_INSET, active)))
        );
    }

    static function thumbLook(thumb:glaze.kit.base.Scrollbar.ScrollbarThumbStyle, color:Null<glaze.Hsla>, radius:Null<Float>):glaze.kit.base.Scrollbar.ScrollbarThumbStyle {
        if (color != null) {
            thumb.bg(color);
        }
        if (radius != null) {
            thumb.radius(radius);
        }
        return thumb;
    }

    /** The kit scrollbar's thumb sizes (`glaze.kit.base.Scrollbar`) */
    static inline final KIT_THUMB_WIDTH:Float = 6.;

    static inline final KIT_THUMB_ACTIVE_WIDTH:Float = 8.;

    static inline final KIT_THUMB_INSET:Float = 4.;

    var appliedFontSize:Null<Float> = null;
    var appliedFontFamily:Null<String> = null;
    var appliedWordWrap:Null<String> = null;
    var appliedReadOnly:Null<Bool> = null;
    var appliedLineNumbers:Null<String> = null;
    var appliedTabSize:Null<Int> = null;
    var appliedShortcutValues:Bool = false;

    /**
     * Whether the shortcut props differ from the ones applied
     * (`shortcutsKey() != appliedShortcuts`, the key built only when a
     * prop changed).
     */
    function shortcutsChanged():Bool {
        if (appliedShortcutValues && appliedFontSize == fontSize && appliedFontFamily == fontFamily && appliedWordWrap == wordWrap
            && appliedReadOnly == readOnly && appliedLineNumbers == lineNumbers && appliedTabSize == tabSize) {
            return false;
        }
        appliedShortcutValues = true;
        appliedFontSize = fontSize;
        appliedFontFamily = fontFamily;
        appliedWordWrap = wordWrap;
        appliedReadOnly = readOnly;
        appliedLineNumbers = lineNumbers;
        appliedTabSize = tabSize;
        return shortcutsKey() != appliedShortcuts;
    }

    function keyContextOf(widget:CodeEditorWidget):KeyContext {
        final keyContext = new KeyContext();
        keyContext.add(CityscapeKeyBindings.KEY_CONTEXT);
        final service = Std.downcast(widget.contextKeyService, AbstractContextKeyService);
        if (service == null) {
            return keyContext;
        }
        final values = service.getContextValuesContainer(service.contextId).collectAllValues();
        for (key => value in values) {
            if (!isKeyContextIdentifier(key)) {
                continue;
            }
            if (JsValues.isBoolean(value)) {
                if ((value : Bool)) {
                    keyContext.add(key);
                }
            }
            else if (JsValues.isString(value) && isKeyContextIdentifier(value)) {
                keyContext.set(key, value);
            }
        }
        return keyContext;
    }

    static function isKeyContextIdentifier(s:String):Bool {
        if (s.length == 0) {
            return false;
        }
        for (i in 0...s.length) {
            final c = StringTools.fastCodeAt(s, i);
            final ok = (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code) || (c >= '0'.code && c <= '9'.code) || c == '_'.code || c == '-'.code || c >= 128;
            if (!ok) {
                return false;
            }
        }
        return true;
    }

    public function render(window:Window, cx:App):IntoElement {
        final entity = viewEntity;
        final view:CityscapeView = entity;
        final widget = this.widget;
        if (options != appliedOptions || shortcutsChanged()) {
            appliedOptions = options;
            appliedShortcuts = shortcutsKey();
            final merged = mergedOptions();
            // Monaco's `updateOptions` of the standalone editor
            cityscape.standalone.StandaloneConfiguration.updateConfigurationService(widget.context.configurationService, merged, false);
            view.updateOptions(merged);
        }
        view.setWrappingIndentColumns(wrappingIndentColumns);
        var listeners = this.listeners;
        if (listeners == null) {
            listeners = new EditorListeners(view);
            this.listeners = listeners;
        }
        // The view rendering this component lists the overlay widgets: the
        // editor view is not a view of the dispatch tree, so a widget added
        // later (a hover, a menu) notifies this one to be listed
        view.hostViewId = window.currentView();
        if (model != lastPropModel) {
            // the model prop changed (an imperative `setModel` is kept until then)
            lastPropModel = model;
            widget.setModel(model);
        }
        CityscapeKeyBindings.ensure(widget.context, cx);

        final root = div()
            .id('cityscape-editor')
            .keyContext(cachedKeyContext(widget))
            .trackFocus(view.focusHandle)
            .relative()
            .flex()
            .flexCol()
            .minW0()
            .minH0()
            .overflowHidden()
            .onAction(RunKeybinding, listeners.runKeybinding)
            .onMouseDown(MouseButton.Left, listeners.mouseDown)
            .onMouseDown(MouseButton.Middle, listeners.mouseDown)
            .onMouseDown(MouseButton.Right, listeners.mouseDown)
            .onMouseMove(listeners.mouseMove)
            .onMouseUp(MouseButton.Left, listeners.mouseUp)
            .onMouseUp(MouseButton.Middle, listeners.mouseUp)
            .onMouseUp(MouseButton.Right, listeners.mouseUp)
            .onHover(listeners.hover)
            .onScroll(listeners.scroll)
            .onKeyDown(listeners.keyDown)
            .onModifiersChanged((event, window, cx) -> view.handleModifiersChanged(event.modifiers))
            .child(view.ensurePaintView(entity, cx));
        // The vertical scrollbar in the band the layout leaves it
        // (`verticalScrollbarSize`, Monaco's `verticalScrollbarWidth`)
        final scrollbarWidth = verticalScrollbarWidth(widget);
        if (scrollbarWidth > 0) {
            root.child(
                div().absolute().top0().right0().bottom0().w(px(scrollbarWidth))
                    .child(styledScrollbar(Scrollbar.vertical(view.scrollHandle), widget, view))
            );
        }
        for (overlay in widget.getOverlayWidgets()) {
            final element = overlay.render(window, cx);
            if (element == null) {
                continue;
            }
            final position = overlay.getPosition();
            final preference:Any = position != null ? position.preference : null;
            if (preference == null) {
                root.child(element);
            }
            else if (JsValues.isNumber(preference)) {
                switch ((preference : OverlayWidgetPositionPreference)) {
                    case OverlayWidgetPositionPreference.BOTTOM_RIGHT_CORNER:
                        root.child(div().absolute().bottom0().right(px(scrollbarWidth)).child(element));
                    case OverlayWidgetPositionPreference.TOP_CENTER:
                        root.child(div().absolute().top0().left0().right0().flex().flexRow().justifyCenter().child(element));
                    case _:
                        root.child(div().absolute().top0().right(px(scrollbarWidth)).child(element));
                }
            }
            else {
                final coordinates:IOverlayWidgetPositionCoordinates = cast preference;
                root.child(div().absolute().top(px(coordinates.top)).left(px(coordinates.left)).child(element));
            }
        }
        final s = surfaceStyle;
        if (s != null) {
            root.refineStyle(s);
        }
        return root;
    }

    //#region IStandaloneCodeEditor

    /**
     * Adds a command with a keybinding (Monaco's `addCommand`), active when
     * this editor has the focus and `context` (a `when` clause) holds.
     * Returns the command id.
     *
     * Monaco's `addCommand` applies to every editor of the page (its
     * keybinding has no editor condition); Cityscape scopes it to this
     * editor, like `addAction`, and removes it when the editor goes away.
     */
    public function addCommand(keybinding:Int, handler:ICommandHandler, ?context:String):Null<String> {
        final widget = this.widget;
        if (widget == null) {
            return null;
        }
        final ctx = widget.context;
        ctx.editorExtensions;
        final commandId = 'DYNAMIC_' + (++LAST_GENERATED_COMMAND_ID);
        final whenExpression = ContextKeyExpr.and(ContextKeyExpr.equals('editorId', widget.getId()), ContextKeyExpr.deserialize(context));
        ownDisposables.add(ctx.keybindingService.addDynamicKeybinding(commandId, keybinding, handler, ctx.commandsRegistry, whenExpression));
        return commandId;
    }

    /**
     * Creates a context key of this editor (Monaco's `createContextKey`).
     */
    public function createContextKey<T>(key:String, defaultValue:T):IContextKey<T> {
        return widget.contextKeyService.createKey(key, defaultValue);
    }

    /**
     * Adds an action of this editor (Monaco's `addAction`): its command, its
     * keybindings, its context menu item.
     */
    public function addAction(descriptor:IActionDescriptor):IDisposable {
        if (descriptor == null || !JsValues.isString(descriptor.id) || !JsValues.isString(descriptor.label) || descriptor.run == null) {
            throw 'Invalid action descriptor, `id`, `label` and `run` are required properties!';
        }
        final widget = this.widget;
        final ctx = widget.context;
        final registry = ctx.editorExtensions;

        // Read descriptor options
        final id = descriptor.id;
        final label = descriptor.label;
        final precondition = ContextKeyExpr.and(
            ContextKeyExpr.equals('editorId', widget.getId()),
            ContextKeyExpr.deserialize(descriptor.precondition)
        );
        final keybindings = descriptor.keybindings;
        final keybindingsWhen = ContextKeyExpr.and(
            precondition,
            ContextKeyExpr.deserialize(descriptor.keybindingContext)
        );
        final contextMenuGroupId = descriptor.contextMenuGroupId;
        final contextMenuOrder:Float = descriptor.contextMenuOrder != null ? descriptor.contextMenuOrder : 0;
        final run:ICommandHandler = (_accessor, args) -> {
            descriptor.run(widget, args != null ? args : []);
        };

        final toDispose = new DisposableStore();

        // Generate a unique id to allow the same descriptor.id across multiple editor instances
        final uniqueId = widget.getId() + ':' + id;

        // Register the command
        toDispose.add(ctx.commandsRegistry.registerCommandHandler(uniqueId, run));

        // Register the context menu item
        if (contextMenuGroupId != null && contextMenuGroupId.length > 0) {
            toDispose.add(registry.appendMenuItem('EditorContext', {
                command: {
                    id: uniqueId,
                    title: label
                },
                when: precondition,
                group: contextMenuGroupId,
                order: contextMenuOrder
            }));
        }

        // Register the keybindings
        if (keybindings != null) {
            for (kb in keybindings) {
                toDispose.add(ctx.keybindingService.addDynamicKeybinding(uniqueId, kb, run, ctx.commandsRegistry, keybindingsWhen));
            }
        }

        // Finally, register an internal editor action
        final internalAction = new InternalEditorAction(
            uniqueId,
            label,
            label,
            null,
            precondition,
            (args:Any) -> descriptor.run(widget, args == null ? [] : (JsValues.isArray(args) ? cast args : [args])),
            widget.contextKeyService
        );

        // Store it under the original id, such that trigger with the original id will work
        @:privateAccess widget._addAction(internalAction, id);
        toDispose.add(Lifecycle.toDisposable(() -> {
            @:privateAccess widget._removeAction(id);
        }));

        ownDisposables.add(toDispose);
        return toDispose;
    }

    //#endregion

    //#region IEditor and ICodeEditor (forwarded to the editor)

    public function getId():String {
        return widget.getId();
    }

    public function getModel():Null<ITextModel> {
        return widget != null ? widget.getModel() : null;
    }

    /**
     * Shows `model` (the `model` prop shows it too). The view state of the
     * previous model is kept and restored when it comes back.
     */
    public function setModel(model:Null<ITextModel>):Void {
        widget.setModel(model);
    }

    public function getValue(?options:{preserveBOM:Bool, lineEnding:String}):String {
        return widget.getValue(options);
    }

    public function setValue(newValue:String):Void {
        widget.setValue(newValue);
    }

    public function updateOptions(newOptions:IEditorOptions):Void {
        cityscape.standalone.StandaloneConfiguration.updateConfigurationService(widget.context.configurationService, newOptions, false);
        widget.updateOptions(newOptions);
        final v = viewEntity;
        if (v != null) {
            (v : CityscapeView).render(true);
        }
    }

    public function getOption<V>(id:EditorOption<V>):V {
        return widget.getOption(id);
    }

    public function getOptions():IComputedEditorOptions {
        return widget.getOptions();
    }

    public function getRawOptions():IEditorOptions {
        return widget.getRawOptions();
    }

    public function getPosition():Null<Position> {
        return widget.getPosition();
    }

    public function setPosition(position:IPosition, ?source:String):Void {
        widget.setPosition(position, source);
    }

    public function getSelection():Null<Selection> {
        return widget.getSelection();
    }

    public function getSelections():Null<Array<Selection>> {
        return widget.getSelections();
    }

    public function setSelection(selection:EitherType<IRange, ISelection>, ?source:String):Void {
        widget.setSelection(selection, source);
    }

    public function setSelections(selections:Array<ISelection>, ?source:String):Void {
        widget.setSelections(selections, source);
    }

    public function revealLine(lineNumber:Int, ?scrollType:ScrollType):Void {
        widget.revealLine(lineNumber, scrollType);
    }

    public function revealLineInCenter(lineNumber:Int, ?scrollType:ScrollType):Void {
        widget.revealLineInCenter(lineNumber, scrollType);
    }

    public function revealLineInCenterIfOutsideViewport(lineNumber:Int, ?scrollType:ScrollType):Void {
        widget.revealLineInCenterIfOutsideViewport(lineNumber, scrollType);
    }

    public function revealLineNearTop(lineNumber:Int, ?scrollType:ScrollType):Void {
        widget.revealLineNearTop(lineNumber, scrollType);
    }

    public function revealLines(startLineNumber:Int, endLineNumber:Int, ?scrollType:ScrollType):Void {
        widget.revealLines(startLineNumber, endLineNumber, scrollType);
    }

    public function revealLinesInCenter(startLineNumber:Int, endLineNumber:Int, ?scrollType:ScrollType):Void {
        widget.revealLinesInCenter(startLineNumber, endLineNumber, scrollType);
    }

    public function revealLinesInCenterIfOutsideViewport(startLineNumber:Int, endLineNumber:Int, ?scrollType:ScrollType):Void {
        widget.revealLinesInCenterIfOutsideViewport(startLineNumber, endLineNumber, scrollType);
    }

    public function revealLinesNearTop(startLineNumber:Int, endLineNumber:Int, ?scrollType:ScrollType):Void {
        widget.revealLinesNearTop(startLineNumber, endLineNumber, scrollType);
    }

    public function revealPosition(position:IPosition, ?scrollType:ScrollType):Void {
        widget.revealPosition(position, scrollType);
    }

    public function revealPositionInCenter(position:IPosition, ?scrollType:ScrollType):Void {
        widget.revealPositionInCenter(position, scrollType);
    }

    public function revealPositionInCenterIfOutsideViewport(position:IPosition, ?scrollType:ScrollType):Void {
        widget.revealPositionInCenterIfOutsideViewport(position, scrollType);
    }

    public function revealPositionNearTop(position:IPosition, ?scrollType:ScrollType):Void {
        widget.revealPositionNearTop(position, scrollType);
    }

    public function revealRange(range:IRange, ?scrollType:ScrollType):Void {
        widget.revealRange(range, scrollType);
    }

    public function revealRangeInCenter(range:IRange, ?scrollType:ScrollType):Void {
        widget.revealRangeInCenter(range, scrollType);
    }

    public function revealRangeAtTop(range:IRange, ?scrollType:ScrollType):Void {
        widget.revealRangeAtTop(range, scrollType);
    }

    public function revealRangeInCenterIfOutsideViewport(range:IRange, ?scrollType:ScrollType):Void {
        widget.revealRangeInCenterIfOutsideViewport(range, scrollType);
    }

    public function revealRangeNearTop(range:IRange, ?scrollType:ScrollType):Void {
        widget.revealRangeNearTop(range, scrollType);
    }

    public function revealRangeNearTopIfOutsideViewport(range:IRange, ?scrollType:ScrollType):Void {
        widget.revealRangeNearTopIfOutsideViewport(range, scrollType);
    }

    public function getScrollTop():Float {
        return widget.getScrollTop();
    }

    public function setScrollTop(newScrollTop:Float, ?scrollType:ScrollType):Void {
        widget.setScrollTop(newScrollTop, scrollType);
    }

    public function getScrollLeft():Float {
        return widget.getScrollLeft();
    }

    public function setScrollLeft(newScrollLeft:Float, ?scrollType:ScrollType):Void {
        widget.setScrollLeft(newScrollLeft, scrollType);
    }

    public function setScrollPosition(position:INewScrollPosition, ?scrollType:ScrollType):Void {
        widget.setScrollPosition(position, scrollType);
    }

    public function getScrollHeight():Float {
        return widget.getScrollHeight();
    }

    public function getScrollWidth():Float {
        return widget.getScrollWidth();
    }

    public function getContentHeight():Float {
        return widget.getContentHeight();
    }

    public function getContentWidth():Float {
        return widget.getContentWidth();
    }

    public function getVisibleRanges():Array<Range> {
        return widget.getVisibleRanges();
    }

    public function getLayoutInfo():EditorLayoutInfo {
        return widget.getLayoutInfo();
    }

    public function focus():Void {
        widget.focus();
    }

    public function hasTextFocus():Bool {
        return widget.hasTextFocus();
    }

    public function hasWidgetFocus():Bool {
        return widget.hasWidgetFocus();
    }

    public function trigger(source:Null<String>, handlerId:String, payload:Any):Void {
        widget.trigger(source, handlerId, payload);
    }

    public function getAction(id:String):Null<IEditorAction> {
        return widget.getAction(id);
    }

    public function getSupportedActions():Array<IEditorAction> {
        return widget.getSupportedActions();
    }

    public function executeEdits(source:Null<String>, edits:Array<IIdentifiedSingleEditOperation>, ?endCursorState:EitherType<Array<Selection>, ICursorStateComputer>):Bool {
        return widget.executeEdits(source, edits, endCursorState);
    }

    public function executeCommand(source:Null<String>, command:ICommand):Void {
        widget.executeCommand(source, command);
    }

    public function pushUndoStop():Bool {
        return widget.pushUndoStop();
    }

    public function popUndoStop():Bool {
        return widget.popUndoStop();
    }

    public function deltaDecorations(oldDecorations:Array<String>, newDecorations:Array<IModelDeltaDecoration>):Array<String> {
        return widget.deltaDecorations(oldDecorations, newDecorations);
    }

    public function createDecorationsCollection(?decorations:Array<IModelDeltaDecoration>):IEditorDecorationsCollection {
        return widget.createDecorationsCollection(decorations);
    }

    public function removeDecorations(decorationIds:Array<String>):Void {
        widget.removeDecorations(decorationIds);
    }

    public function getLineDecorations(lineNumber:Int):Null<Array<IModelDecoration>> {
        return widget.getLineDecorations(lineNumber);
    }

    public function saveViewState():Null<IEditorViewState> {
        return widget.saveViewState();
    }

    public function restoreViewState(state:Null<IEditorViewState>):Void {
        widget.restoreViewState(state);
    }

    public function getContribution<T:IEditorContribution>(id:String):Null<T> {
        return widget.getContribution(id);
    }

    public function getTargetAtClientPoint(clientX:Float, clientY:Float):Null<IMouseTarget> {
        return widget.getTargetAtClientPoint(clientX, clientY);
    }

    public function getScrolledVisiblePosition(position:IPosition):Null<{top:Float, left:Float, height:Float}> {
        return widget.getScrolledVisiblePosition(position);
    }

    public function addOverlayWidget(overlay:IOverlayWidget):Void {
        widget.addOverlayWidget(overlay);
    }

    public function removeOverlayWidget(overlay:IOverlayWidget):Void {
        widget.removeOverlayWidget(overlay);
    }

    //#endregion

    //#region events

    public var onDidChangeModelContent(get, never):Event<IModelContentChangedEvent>;
    inline function get_onDidChangeModelContent() return widget.onDidChangeModelContent;

    public var onDidChangeCursorPosition(get, never):Event<ICursorPositionChangedEvent>;
    inline function get_onDidChangeCursorPosition() return widget.onDidChangeCursorPosition;

    public var onDidChangeCursorSelection(get, never):Event<ICursorSelectionChangedEvent>;
    inline function get_onDidChangeCursorSelection() return widget.onDidChangeCursorSelection;

    public var onDidScrollChange(get, never):Event<IScrollEvent>;
    inline function get_onDidScrollChange() return widget.onDidScrollChange;

    public var onDidChangeModel(get, never):Event<IModelChangedEvent>;
    inline function get_onDidChangeModel() return widget.onDidChangeModel;

    public var onDidChangeModelDecorations(get, never):Event<IModelDecorationsChangedEvent>;
    inline function get_onDidChangeModelDecorations() return widget.onDidChangeModelDecorations;

    public var onDidChangeConfiguration(get, never):Event<ConfigurationChangedEvent>;
    inline function get_onDidChangeConfiguration() return widget.onDidChangeConfiguration;

    public var onDidFocusEditorText(get, never):VoidEvent;
    inline function get_onDidFocusEditorText() return widget.onDidFocusEditorText;

    public var onDidBlurEditorText(get, never):VoidEvent;
    inline function get_onDidBlurEditorText() return widget.onDidBlurEditorText;

    public var onDidFocusEditorWidget(get, never):VoidEvent;
    inline function get_onDidFocusEditorWidget() return widget.onDidFocusEditorWidget;

    public var onDidBlurEditorWidget(get, never):VoidEvent;
    inline function get_onDidBlurEditorWidget() return widget.onDidBlurEditorWidget;

    public var onKeyDown(get, never):Event<IKeyboardEvent>;
    inline function get_onKeyDown() return widget.onKeyDown;

    public var onMouseDown(get, never):Event<IEditorMouseEvent>;
    inline function get_onMouseDown() return widget.onMouseDown;

    public var onMouseUp(get, never):Event<IEditorMouseEvent>;
    inline function get_onMouseUp() return widget.onMouseUp;

    public var onContextMenu(get, never):Event<IEditorMouseEvent>;
    inline function get_onContextMenu() return widget.onContextMenu;

    //#endregion

}

/**
 * The listeners of a `CityscapeEditor`'s element, forwarding to its view.
 */
private class EditorListeners {

    public final runKeybinding:(action:RunKeybinding, window:Window, cx:App) -> Void;
    public final mouseDown:(event:glaze.MouseDownEvent, window:Window, cx:App) -> Void;
    public final mouseMove:(event:glaze.MouseMoveEvent, window:Window, cx:App) -> Void;
    public final mouseUp:(event:glaze.MouseUpEvent, window:Window, cx:App) -> Void;
    public final hover:(hovered:Bool) -> Void;
    public final scroll:(event:glaze.ScrollEvent, window:Window, cx:App) -> Void;
    public final keyDown:(event:glaze.KeyDownEvent, window:Window, cx:App) -> Void;

    public function new(view:CityscapeView) {
        runKeybinding = (action, window, cx) -> {
            if (!view.onRunKeybinding(action.keypress, window, cx)) {
                cx.propagate();
            }
        };
        mouseDown = (event, window, cx) -> view.handleMouseDown(event, window, cx);
        mouseMove = (event, window, cx) -> view.handleMouseMove(event, window, cx);
        mouseUp = (event, window, cx) -> view.handleMouseUp(event, window, cx);
        hover = (hovered:Bool) -> view.handleHover(hovered);
        scroll = (event, window, cx) -> view.onScroll(event, window, cx);
        keyDown = (event, window, cx) -> view.onKeyDown(event, window, cx);
    }

}
