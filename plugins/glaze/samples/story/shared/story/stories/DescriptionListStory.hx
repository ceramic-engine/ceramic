// Ported from gpui-kit 0.8.1: crates/story/src/stories/description_list_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import glaze.Action;
import glaze.AnyView;
import glaze.App;
import glaze.AppContext;
import glaze.Axis;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Window;
import glaze.kit.Size;
import glaze.kit.button.Button;
import glaze.kit.descriptionlist.DescriptionList;
import glaze.kit.dock.PanelControl;
import glaze.kit.text.TextView;
import story.Story;
import story.StoryActions.ChangeStorySize;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

enum DescriptionListToggle {
    Vertical;
    Bordered;
}

/** Rust `enum ToggleOption` (an action). */
@:action(namespace = description_list_story, noJson)
class DescriptionListToggleOption implements Action {
    public final value:DescriptionListToggle;
}

class DescriptionListStory extends Model implements Story {

    final focusHandle:FocusHandle;

    var layout:Axis;

    var bordered:Bool;

    var size:Size;

    final items:Array<{label:String, value:String, span:Int}>;

    function new(_:Window, cx:AppContext) {
        super();
        items = [
            {label: 'Name', value: 'GPUI Component', span: 1},
            {
                label: 'Description',
                value: 'UI components for building fantastic desktop application by using GPUI.'
                    + '\n\n '
                    + 'Contains a lot of useful UI components, such as **Button**, **Input**, **Table**, **List**, **Select**, **DatePicker** ... '
                    + '\n\n '
                    + 'You can easily create your native desktop application by using GPUI Component.\n                ',
                span: 3
            },
            {label: 'Version', value: '0.1.0', span: 1},
            {label: 'License', value: 'Apache-2.0', span: 1},
            {label: 'Author', value: 'Longbridge', span: 1},
            {label: '--', value: '--', span: 1},
            {label: 'Repository', value: 'https://github.com/longbridge/gpui-kit', span: 2},
            {label: 'Category', value: 'UI, Desktop, Framework', span: 1},
            {label: 'This is a long label for Platform', value: 'macOS, Windows, Linux', span: 1},
        ];
        bordered = true;
        size = Medium;
        layout = Horizontal;
        focusHandle = cx.focusHandle();
    }

    public static function view(window:Window, cx:App):Entity<DescriptionListStory> {
        return cx.newEntity((cx:Context<DescriptionListStory>) -> new DescriptionListStory(window, cx));
    }

    public static function title():String {
        return 'DescriptionList';
    }

    public static function description():String {
        return 'Present labels and values in a structured summary.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function zoomable():Null<PanelControl> {
        return null;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<DescriptionListStory> = cast cx;
        final vertical = layout == Vertical;
        final bordered = this.bordered;
        return vFlex()
            .id('example')
            .onAction(ChangeStorySize, self.listener((this_:DescriptionListStory, action:ChangeStorySize, _, cx) -> {
                this_.size = action.value;
                cx.notify();
            }))
            .onAction(DescriptionListToggleOption, self.listener((this_:DescriptionListStory, action:DescriptionListToggleOption, _, cx) -> {
                switch action.value {
                    case Vertical:
                        this_.layout = this_.layout == Vertical ? Horizontal : Vertical;
                    case Bordered:
                        this_.bordered = !this_.bordered;
                }
                cx.notify();
            }))
            .p4()
            .sizeFull()
            .itemsCenter()
            .gap6()
            .child(storyToolbar(size).dropdownChild(Button.component('description-list-options').label('Options'), (menu, _, _) -> menu
                .menuWithCheck('Vertical', vertical, new DescriptionListToggleOption(Vertical))
                .menuWithCheck('Bordered', bordered, new DescriptionListToggleOption(Bordered))))
            .child(div().w(px(720.)).child(DescriptionList.component()
                .columns(3)
                .layout(layout)
                .bordered(bordered)
                .withSize(size)
                .children([for (ix => item in items) {
                    if (item.label == '--') {
                        DescriptionItem.separator();
                    } else {
                        DescriptionItem.create(item.label)
                            .value((TextView.markdown(ix, item.value) : IntoElement))
                            .span(item.span);
                    }
                }])));
    }

}
