// Ported from vscode src/vs/editor/contrib/colorPicker/browser/standaloneColorPickerActions.ts
// (with StandaloneColorPickerController of standaloneColorPickerWidget.ts and
// StandaloneColorPickerParticipant.createColorHover of colorHoverParticipant.ts)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.colorPicker.view;

import cityscape.Cityscape;
import cityscape.base.common.Cancellation;
import cityscape.base.common.KeyCodes;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Promise;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.EditorContextKeys;
import cityscape.common.Languages.IColorInformation;
import cityscape.common.core.Range;
import cityscape.contrib.colorPicker.view.Color.ColorUtils;
import cityscape.contrib.colorPicker.view.ColorDetector.ColorDecorationInjectedTextMarker;
import cityscape.contrib.colorPicker.view.ColorHoverParticipant.ColorHover;
import cityscape.contrib.colorPicker.view.ColorHoverParticipant.ColorPickerSession;
import cityscape.platform.contextkey.common.ContextKey.IContextKey;
import cityscape.platform.keybinding.common.KeybindingsRegistry.KeybindingWeight;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorExtensions;

/**
 * The standalone color picker (Monaco's `StandaloneColorPickerController`
 * and `StandaloneColorPickerWidget`): the picker of the color at the
 * selection (black when there is none), shown at the selection; Enter
 * writes the picked color with the presentation shown (`Replace` the color,
 * or `Insert` at the selection), Escape or the close button hides it. The
 * picker does not take the keyboard focus (the Glaze kit has the editor's):
 * it counts as focused while it shows, so Enter and Escape reach its
 * actions. Moving the cursor or the mouse over a swatch hides it.
 */
class StandaloneColorPickerController extends Disposable implements IEditorContribution {

    public static inline final ID = 'editor.contrib.standaloneColorPickerController';

    final _editor:ICodeEditor;
    final _standaloneColorPickerVisible:IContextKey<Bool>;
    final _standaloneColorPickerFocused:IContextKey<Bool>;
    final _widget:ColorPickerWidget;
    final _widgetListeners = new DisposableStore();
    var _session:Null<ColorPickerSession> = null;
    var _request = 0;

    public function new(editor:ICodeEditor) {
        super();
        this._editor = editor;
        this._standaloneColorPickerVisible = EditorContextKeys.standaloneColorPickerVisible.bindTo(editor.contextKeyService);
        this._standaloneColorPickerFocused = EditorContextKeys.standaloneColorPickerFocused.bindTo(editor.contextKeyService);
        this._widget = new ColorPickerWidget(editor, 'editor.contrib.standaloneColorPickerWidget');
        this._widget.onClose = () -> this.hide();
        this._register(_widgetListeners);
    }

    public static function get(editor:ICodeEditor):Null<StandaloneColorPickerController> {
        return editor.getContribution(StandaloneColorPickerController.ID);
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    /**
     * The picker shown (tests).
     */
    public function getSession():Null<ColorPickerSession> {
        return _session;
    }

    public function showOrFocus():Void {
        if (!this._editor.hasModel()) {
            return;
        }
        if (!this._standaloneColorPickerVisible.get()) {
            this._start();
        }
        else if (!this._standaloneColorPickerFocused.get()) {
            this._standaloneColorPickerFocused.set(true);
        }
    }

    public function hide():Void {
        this._standaloneColorPickerFocused.set(false);
        this._standaloneColorPickerVisible.set(false);
        _request++;
        _widgetListeners.clear();
        final session = _session;
        _session = null;
        if (session != null) {
            session.dispose();
        }
        _widget.hide();
        this._editor.focus();
    }

    public function insertColor():Void {
        if (_session != null) {
            _session.updateEditorModel();
        }
        this.hide();
    }

    function _start():Void {
        final selection = this._editor.getSelection();
        if (selection == null) {
            return;
        }
        final range:Range = selection;
        final request = ++_request;
        this._standaloneColorPickerVisible.set(true);
        final colorInfo:IColorInformation = {
            range: range,
            color: {red: 0, green: 0, blue: 0, alpha: 1}
        };
        createColorHover(colorInfo, new DefaultDocumentColorProvider()).done(colorHover -> {
            if (request != _request || colorHover == null || !_editor.hasModel()) {
                return;
            }
            final session = new ColorPickerSession(_editor, colorHover, () -> this.hide(), true);
            _session = session;
            // When the cursor position changes, hide the color picker
            _widgetListeners.add(_editor.onDidChangeCursorPosition(_ -> this.hide()));
            _widgetListeners.add(_editor.onMouseMove(e -> {
                final injected = e.target.injectedText;
                if (injected != null && injected.options.attachedData == ColorDecorationInjectedTextMarker.INSTANCE) {
                    this.hide();
                }
            }));
            this._standaloneColorPickerFocused.set(true);
            _widget.show(session, true);
        });
    }

    /**
     * Monaco's `StandaloneColorPickerParticipant.createColorHover`: the
     * color of the editor containing the range when there is one, else the
     * default color with the default provider.
     */
    function createColorHover(defaultColorInfo:IColorInformation, defaultColorProvider:DefaultDocumentColorProvider):Promise<ColorHover> {
        final model = _editor.getModel();
        return ColorUtils.getColors(_editor.context.languageFeaturesService.colorProvider, model, CancellationTokens.None).thenPromise(colors -> {
            var foundColorInfo:Null<IColorInformation> = null;
            var foundColorProvider:Null<cityscape.common.Languages.DocumentColorProvider> = null;
            for (colorData in (colors != null ? colors : [])) {
                final colorInfo = colorData.colorInfo;
                if (Range.containsRangeStatic(colorInfo.range, defaultColorInfo.range)) {
                    foundColorInfo = colorInfo;
                    foundColorProvider = colorData.provider;
                }
            }
            final colorInfo = foundColorInfo != null ? foundColorInfo : defaultColorInfo;
            final colorProvider:cityscape.common.Languages.DocumentColorProvider = foundColorProvider != null ? foundColorProvider : defaultColorProvider;
            return ColorHoverParticipant._createColorHover(model, colorInfo, colorProvider);
        });
    }

    override public function dispose():Void {
        _request++;
        if (_session != null) {
            _session.dispose();
            _session = null;
        }
        _widget.dispose();
        super.dispose();
    }
}

/**
 * Shows the standalone color picker (Monaco's `EditorAction2` of the
 * command palette, an `EditorAction` here).
 */
class ShowOrFocusStandaloneColorPicker extends EditorAction {

    public static inline final ID = 'editor.action.showOrFocusStandaloneColorPicker';

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: ID,
            label: r.localize('showOrFocusStandaloneColorPicker', "Show or Focus Standalone Color Picker"),
            alias: 'Show or Focus Standalone Color Picker',
            precondition: null
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = StandaloneColorPickerController.get(editor);
        if (controller != null) {
            controller.showOrFocus();
        }
    }
}

class HideStandaloneColorPicker extends EditorAction {

    public static inline final ID = 'editor.action.hideColorPicker';

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: ID,
            label: r.localize('hideColorPicker', "Hide the Color Picker"),
            alias: 'Hide the Color Picker',
            precondition: EditorContextKeys.standaloneColorPickerVisible.isEqualTo(true),
            kbOpts: {
                primary: KeyCode.Escape,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = StandaloneColorPickerController.get(editor);
        if (controller != null) {
            controller.hide();
        }
    }
}

class InsertColorWithStandaloneColorPicker extends EditorAction {

    public static inline final ID = 'editor.action.insertColorWithStandaloneColorPicker';

    public function new(r:EditorExtensionsRegistry) {
        super({
            id: ID,
            label: r.localize('insertColorWithStandaloneColorPicker', "Insert Color with Standalone Color Picker"),
            alias: 'Insert Color with Standalone Color Picker',
            precondition: EditorContextKeys.standaloneColorPickerFocused.isEqualTo(true),
            kbOpts: {
                primary: KeyCode.Enter,
                weight: KeybindingWeight.EditorContrib
            }
        });
    }

    public function run(accessor:Null<Cityscape>, editor:ICodeEditor, args:Any):Void {
        final controller = StandaloneColorPickerController.get(editor);
        if (controller != null) {
            controller.insertColor();
        }
    }
}

class StandaloneColorPickerRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        r.registerEditorAction(new HideStandaloneColorPicker(r));
        r.registerEditorAction(new InsertColorWithStandaloneColorPicker(r));
        r.registerEditorAction(new ShowOrFocusStandaloneColorPicker(r));
        r.registerEditorContribution(StandaloneColorPickerController.ID, editor -> new StandaloneColorPickerController(editor), EditorContributionInstantiation.AfterFirstRender);
    }

}
