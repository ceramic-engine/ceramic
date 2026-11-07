// Ported from gpui-kit 0.8.1: crates/story/src/stories/toolbar_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.

package story.stories;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;
import glaze.Action;
import glaze.kit.base.IndexPath;
import glaze.kit.base.input.InputState;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Size;
import glaze.kit.button.Button;
import glaze.kit.button.Toggle;
import glaze.kit.combobox.Combobox;
import glaze.kit.combobox.ComboboxState;
import glaze.kit.dock.PanelControl;
import glaze.kit.input.Input;
import glaze.kit.searchablelist.SearchableVec;
import glaze.kit.searchablelist.SearchableVec.VecDelegate;
import glaze.kit.select.Select;
import glaze.kit.select.SelectState;
import glaze.kit.separator.Separator;
import glaze.kit.theme.Theme;
import glaze.kit.toolbar.Toolbar;
import glaze.kit.toolbar.Toolbar.ToolbarGroup;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

@:action(namespace = toolbar_story, noJson) private class ToggleDisabled implements Action {}

class ToolbarStory extends Model implements Story {

    /**
     * Rust `gpui_kit::assets::IconName::Save`, an icon of gpui-kit's full
     * catalog that the default icon set does not bundle: its SVG is in the
     * project assets (`icons/save.svg`, Lucide, ISC).
     */
    public static inline final SAVE_ICON_PATH = 'icons/save.svg';

    public static function title():String {
        return 'Toolbar';
    }

    public static function description():String {
        return 'Groups commands and controls into one keyboard-navigable row.';
    }

    public static function zoomable():Null<PanelControl> {
        return null;
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<ToolbarStory> {
        return cx.newEntity((c:Context<ToolbarStory>) -> new ToolbarStory(window, c));
    }

    final focusHandle_:FocusHandle;

    @observe var size:Size = glaze.kit.Size.Medium;

    @observe var disabled:Bool = false;

    @observe var formats:Array<Bool> = [true, false, false];

    final font:Entity<SelectState<String>>;

    final market:Entity<SelectState<String>>;

    final status:Entity<ComboboxState<String>>;

    final query:Entity<InputState>;

    function new(window:Window, cx:Context<ToolbarStory>) {
        super();
        font = cx.newEntity((cx:Context<SelectState<String>>) -> new SelectState<String>(new VecDelegate(['Inter', 'SF Pro', 'Helvetica', 'Georgia']),
            new IndexPath(), window, cx));
        market = cx.newEntity((cx:Context<SelectState<String>>) -> new SelectState<String>(new VecDelegate([
            'All markets',
            'US market',
            'Hong Kong',
            'Singapore',
        ]), new IndexPath(), window, cx));
        status = cx.newEntity((cx:Context<ComboboxState<String>>) -> new ComboboxState<String>(new SearchableVec([
            'Open',
            'In progress',
            'Filled',
            'Cancelled',
        ]), [], window, cx).searchable(true));
        query = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).withPlaceholder('Search'));
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    static function iconButton(id:String, icon:IconName, tooltip:String, disabled:Bool):Button {
        return new Button(id).icon(icon).tooltip(tooltip).disabled(disabled);
    }

    static function toolbarOptions(size:Size, disabled:Bool):IntoElement {
        final label = switch size {
            case XSmall: 'XSmall';
            case Small: 'Small';
            case _: 'Medium';
        }
        return storyToolbarGroup().dropdownChild(new Button('toolbar-options').label('Size: $label'), (menu, _, _) -> menu
            .menuWithCheck('XSmall', size.equals(XSmall), new ChangeStorySize(XSmall))
            .menuWithCheck('Small', size.equals(Small), new ChangeStorySize(Small))
            .menuWithCheck('Medium', size.equals(Medium), new ChangeStorySize(Medium))
            .separator()
            .menuWithCheck('Disabled', disabled, new ToggleDisabled()));
    }

    function setFormat(ix:Int, checked:Bool):Void {
        final next = formats.copy();
        next[ix] = checked;
        formats = next;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final disabled = this.disabled;
        return vFlex()
            .wFull()
            .itemsCenter()
            .gap6()
            .onAction(ChangeStorySize, (action, _, _) -> size = action.value)
            .onAction(ToggleDisabled, (_, _, _) -> this.disabled = !this.disabled)
            .child(toolbarOptions(size, disabled))
            .child(section('Default')
                .description('Keep document, history, and formatting commands in one compact editor toolbar.')
                .w(px(640.))
                .child(new Toolbar('default-toolbar')
                    .wFull()
                    .withSize(size)
                    .disabled(disabled)
                    .border1()
                    .borderColor(theme.border)
                    .rounded(theme.radius)
                    .child(new ToolbarGroup('document-group')
                        .label('Document')
                        .gap1()
                        .child(new Button('new-document').icon(IconName.Plus).label('New').disabled(disabled))
                        .child(new Button('save-document').icon(Icon.empty().path(SAVE_ICON_PATH)).label('Save').disabled(disabled)))
                    .content(Separator.vertical().h5())
                    .child(new ToolbarGroup('history-group')
                        .label('History')
                        .gap1()
                        .child(iconButton('undo', IconName.Undo2, 'Undo', disabled))
                        .child(iconButton('redo', IconName.Redo2, 'Redo', disabled)))
                    .content(Separator.vertical().h5())
                    .child(new ToolbarGroup('formatting-group')
                        .label('Formatting')
                        .gap1()
                        .child(new Toggle('bold').label('B').checked(formats[0]).disabled(disabled).onClick((checked, _, _) -> setFormat(0, checked)))
                        .child(new Toggle('italic').label('I').checked(formats[1]).disabled(disabled).onClick((checked, _, _) -> setFormat(1, checked)))
                        .child(new Toggle('underline').label('U').checked(formats[2]).disabled(disabled).onClick((checked, _, _) -> setFormat(2, checked))))
                    .content(Separator.vertical().h5())
                    .child(new Select(font).placeholder('Font').disabled(disabled).w40())))
            .child(section('Mixed controls')
                .description('Select and Combobox inherit the same density while preserving their own popup behavior.')
                .w(px(640.))
                .child(new Toolbar('mixed-toolbar')
                    .wFull()
                    .withSize(size)
                    .disabled(disabled)
                    .border1()
                    .borderColor(theme.border)
                    .rounded(theme.radius)
                    .child(new Input(query).prefix(new Icon(IconName.Search)).disabled(disabled).w40())
                    .child(new Select(market).placeholder('Market').disabled(disabled).w32())
                    .child(new Combobox(status).placeholder('Order status').disabled(disabled).w40())
                    .content(div().flex1())
                    .child(iconButton('refresh', IconName.RotateCw, 'Refresh', disabled))
                    .child(iconButton('settings', IconName.Settings2, 'Configure columns', disabled))));
    }

}
