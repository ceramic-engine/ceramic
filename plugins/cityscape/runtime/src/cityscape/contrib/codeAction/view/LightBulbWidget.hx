// Ported from vscode src/vs/editor/contrib/codeAction/browser/lightBulbWidget.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.codeAction.view;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.contrib.codeAction.common.CodeActionTypes;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorWidgets;
import cityscape.view.Codicons;
import glaze.App;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.MouseButton;
import glaze.Window;
import glaze.kit.Icon;

import glaze.Prelude.*;

typedef LightBulbClickEvent = {
    final x:Float;
    final y:Float;
    final actions:CodeActionSet;
    final trigger:CodeActionTrigger;
}

/**
 * The lightbulb of the code actions (Monaco's `LightBulbWidget`): Monaco's
 * codicon (16 pixels, lightBulbWidget.css) in the gutter of the line of the
 * cursor when code actions are available there: `light-bulb`,
 * `lightbulb-autofix` when a preferred quick fix exists, `lightbulb-sparkle`
 * and `lightbulb-sparkle-autofix` with an AI fix, `sparkle-filled` when all
 * the fixes are AI fixes (`_updateLightBulbTitleAndIcon`), in their colors.
 * A click shows the code actions.
 *
 * Monaco places the lightbulb at the start of the line, or above, below or
 * in the gutter when the text leaves no room; Cityscape always places it in
 * the gutter (the glyph margin when shown, else the line decorations).
 */
class LightBulbWidget implements IEditorContribution implements IOverlayWidget {

    public static inline final ID = 'editor.contrib.lightbulbWidget';

    public static function get(editor:ICodeEditor):Null<LightBulbWidget> {
        return editor.getContribution(LightBulbWidget.ID);
    }

    final _editor:ICodeEditor;
    final _disposables = new DisposableStore();

    final _onClick = new Emitter<LightBulbClickEvent>();
    public final onClick:Event<LightBulbClickEvent>;

    var _actions:Null<CodeActionSet> = null;
    var _trigger:Null<CodeActionTrigger> = null;
    var _lineNumber:Int = -1;

    public function new(editor:ICodeEditor) {
        this._editor = editor;
        this.onClick = _onClick.event;
        editor.addOverlayWidget(this);
        _disposables.add(editor.onDidChangeModelContent(_ -> {
            // cancel when the line in question has been removed
            final model = editor.getModel();
            if (_actions != null && (model == null || _lineNumber >= model.getLineCount())) {
                hide();
            }
        }));
        _disposables.add(editor.onDidScrollChange(_ -> {
            if (_actions != null) {
                editor.layoutOverlayWidget(this);
            }
        }));
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    public function dispose():Void {
        _disposables.dispose();
        _onClick.dispose();
        _editor.removeOverlayWidget(this);
    }

    /**
     * Whether the lightbulb shows (tests).
     */
    public function isVisible():Bool {
        return _actions != null;
    }

    /**
     * The line of the lightbulb (-1 when hidden).
     */
    public function getLineNumber():Int {
        return _actions != null ? _lineNumber : -1;
    }

    public function update(actions:CodeActionSet, trigger:CodeActionTrigger, atPosition:IPosition):Void {
        if (actions.validActions.length <= 0) {
            return this.hide();
        }

        final hasTextFocus = this._editor.hasTextFocus();
        if (!hasTextFocus) {
            return this.hide();
        }

        if (this._editor.getOption(EditorOption.lightbulb).enabled == 'off') {
            return this.hide();
        }

        final model = this._editor.getModel();
        if (model == null) {
            return this.hide();
        }

        final position = model.validatePosition(atPosition);
        _actions = actions;
        _trigger = trigger;
        _lineNumber = position.lineNumber;
        _editor.layoutOverlayWidget(this);
    }

    public function hide():Void {
        if (_actions == null) {
            return;
        }
        _actions = null;
        _trigger = null;
        _lineNumber = -1;
        _editor.layoutOverlayWidget(this);
    }

    /**
     * Monaco's `gutterHide` (the gutter lightbulb is this widget here).
     */
    public function gutterHide():Void {
        hide();
    }

    /**
     * Clicks the lightbulb (tests, and the mouse).
     */
    public function click(x:Float, y:Float):Void {
        final actions = _actions;
        final trigger = _trigger;
        if (actions == null || trigger == null) {
            return;
        }
        _onClick.fire({x: x, y: y, actions: actions, trigger: trigger});
    }

    public function getId():String {
        return ID;
    }

    public function getPosition():Null<IOverlayWidgetPosition> {
        return null;
    }

    public function render(window:Window, cx:App):Null<IntoElement> {
        final actions = _actions;
        if (actions == null || !_editor.hasModel()) {
            return null;
        }
        final layoutInfo = _editor.getLayoutInfo();
        final lineHeight = _editor.getOption(EditorOption.lineHeight);
        final top = _editor.getTopForLineNumber(_lineNumber) - _editor.getScrollTop();
        if (top + lineHeight <= 0 || top >= layoutInfo.height) {
            return null;
        }
        final glyphMargin = _editor.getOption(EditorOption.glyphMargin);
        final left = glyphMargin ? layoutInfo.glyphMarginLeft : layoutInfo.decorationsLeft;
        final width = glyphMargin ? layoutInfo.glyphMarginWidth : layoutInfo.decorationsWidth;
        final size = ICON_SIZE;
        final icon = iconOf(actions);
        final color = colorOf(_editor, icon);
        final lineNumber = _lineNumber;
        return div()
            .id('cityscape-lightbulb')
            .absolute()
            .top(px(top))
            .left(px(left))
            .w(px(Math.max(width, size)))
            .h(px(lineHeight))
            .flex()
            .itemsCenter()
            .justifyCenter()
            .cursorPointer()
            .occlude()
            .onMouseDown(MouseButton.Left, (event, window, cx) -> {
                cx.stopPropagation();
                final bounds = EditorWidgets.positionBounds(_editor, new Position(lineNumber, 1));
                final editorBounds = EditorWidgets.editorBounds(_editor);
                final x = editorBounds != null ? editorBounds.origin.x + left : event.position.x;
                final y = bounds != null ? bounds.origin.y + bounds.size.height : event.position.y;
                click(x, y);
            })
            .child(Icon.empty().data(Codicons.svg(icon)).withSize(size).textColor(color));
    }

    /**
     * The font size of the `.codicon` of the widget (codicon.css: 16px).
     */
    public static inline final ICON_SIZE:Float = 16.;

    /**
     * Monaco's `_updateLightBulbTitleAndIcon`: the codicon of the lightbulb
     * for its actions.
     */
    public static function iconOf(actions:CodeActionSet):String {
        if (actions.allAIFixes) {
            return 'sparkle-filled';
        }
        if (actions.hasAutoFix) {
            return actions.hasAIFix ? 'lightbulb-sparkle-autofix' : 'lightbulb-autofix';
        }
        return actions.hasAIFix ? 'lightbulb-sparkle' : 'light-bulb';
    }

    /**
     * The color of a lightbulb codicon (lightBulbWidget.css):
     * `editorLightBulb.foreground` for `light-bulb` and `lightbulb-sparkle`,
     * `editorLightBulbAutoFix.foreground` (or the lightbulb's) for the auto
     * fix ones, `editorLightBulbAi.foreground` (or `icon.foreground`) for
     * `sparkle-filled`.
     */
    public static function colorOf(editor:ICodeEditor, icon:String):Hsla {
        final dark = EditorWidgets.isDark(editor);
        final lightBulb = EditorWidgets.color(editor, 'editorLightBulb.foreground', dark ? rgb(0xFFCC00).toHsla() : rgb(0xDDB100).toHsla());
        return switch icon {
            case 'lightbulb-autofix' | 'lightbulb-sparkle-autofix':
                EditorWidgets.color(editor, 'editorLightBulbAutoFix.foreground', lightBulb);
            case 'sparkle-filled':
                EditorWidgets.color(editor, 'editorLightBulbAi.foreground', EditorWidgets.color(editor, 'icon.foreground', dark ? rgb(0xC5C5C5).toHsla() : rgb(0x424242).toHsla()));
            case _:
                lightBulb;
        };
    }

}
