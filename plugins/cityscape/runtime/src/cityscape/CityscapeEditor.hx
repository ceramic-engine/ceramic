// New code for Cityscape (not a port): the editor as a persistent Glaze
// component (AUDIT B.13 recipe).
package cityscape;

import cityscape.Cityscape;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions.IEditorOptions;
import cityscape.common.model.TextModel;
import cityscape.view.CityscapeView;
import cityscape.view.CityscapeViewElement;
import glaze.App;
import glaze.Component;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.MouseButton;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.Scrollbar;

import glaze.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * A Cityscape code editor, placed anywhere in a Glaze UI and sized by the
 * flex layout of its parent:
 *
 * ```haxe
 * div().flex().sizeFull().child(
 *     CityscapeEditor.component().model(model).options({wordWrap: 'on'}).flex1()
 * )
 * ```
 *
 * Each editor has its own view state (selections, scroll, wrapping, hidden
 * ranges revealed on its cursor lines) over a model that other editors may
 * show too; edits in one show in the others. When the model changes, the
 * editor keeps the view state of the previous one and restores it when that
 * model comes back.
 *
 * TODO(step 3): the full surface of `monaco.editor` (commands, actions,
 * keybindings, `deltaDecorations` on the editor, events) comes with the
 * cursor controller; `view` gives the view model meanwhile.
 */
class CityscapeEditor extends Component implements Styled {

    static var _nextEditorId = 1;

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
     * The context (languages, themes, registered decoration styles). When
     * null: the context of the initial model when it is a `TextModel`, else
     * the default one.
     */
    @prop(unobserved) var context:Null<Cityscape> = null;

    /**
     * loreline-monaco's `[loreline]` wrapping patch: the extra indent of
     * wrapped lines in columns per level (`wrappingIndent` `indent` or
     * `deepIndent`), -1 for Monaco's tab stops.
     */
    @prop var wrappingIndentColumns:Int = -1;

    /**
     * Called once with the view of the editor (tests, hosts), after the
     * initial model is set.
     */
    @prop(unobserved) var onCreate:Null<(view:Entity<CityscapeView>) -> Void> = null;

    /**
     * The style of the editor's root element (`Styled`).
     */
    @prop(unobserved) var surfaceStyle:Null<StyleRefinement> = null;

    var viewEntity:Null<Entity<CityscapeView>> = null;
    var appliedOptions:Null<IEditorOptions> = null;

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

    override public function init(window:Window, cx:App):Void {
        final initialModel = model;
        final ctx = context != null ? context : (Std.isOfType(initialModel, TextModel) ? (cast initialModel : TextModel).context : Cityscape.defaultContext);
        final editorId = _nextEditorId++;
        final initialOptions:IEditorOptions = options != null ? options : {};
        viewEntity = cx.newEntity((vcx:Context<CityscapeView>) -> new CityscapeView(vcx, ctx, editorId, initialOptions));
        appliedOptions = options;
        // The model is set before `onCreate`, which can then use the view model
        final view:CityscapeView = viewEntity;
        view.setWrappingIndentColumns(wrappingIndentColumns);
        view.setModel(model);
        final callback = onCreate;
        if (callback != null) {
            callback(viewEntity);
        }
    }

    override public function destroy():Void {
        final v = viewEntity;
        if (v != null) {
            (v : CityscapeView).disposeView();
        }
        viewEntity = null;
    }

    public function render(window:Window, cx:App):IntoElement {
        final entity = viewEntity;
        final view:CityscapeView = entity;
        if (options != appliedOptions && options != null) {
            appliedOptions = options;
            view.updateOptions(options);
        }
        view.setWrappingIndentColumns(wrappingIndentColumns);
        view.setModel(model);

        final root = div()
            .id('cityscape-editor')
            .keyContext('CityscapeEditor')
            .trackFocus(view.focusHandle)
            .relative()
            .flex()
            .flexCol()
            .minW0()
            .minH0()
            .overflowHidden()
            .onMouseDown(MouseButton.Left, (event, window, cx) -> view.onMouseDown(event, window, cx))
            .onMouseMove((event, window, cx) -> view.onMouseMove(event, window, cx))
            .onMouseUp(MouseButton.Left, (event, window, cx) -> view.onMouseUp(event, window, cx))
            .onScroll((event, window, cx) -> view.onScroll(event, window, cx))
            .onKeyDown((event, window, cx) -> view.onKeyDown(event, window, cx))
            .child(new CityscapeViewElement(entity))
            .child(
                div().absolute().top0().right0().bottom0().w(px(Scrollbar.width()))
                    .child(Scrollbar.vertical(view.scrollHandle))
            );
        final s = surfaceStyle;
        if (s != null) {
            root.refineStyle(s);
        }
        return root;
    }

}
