// Ported from gpui-kit 0.8.1: crates/story/src/stories/toggle_story.rs
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
import glaze.kit.IconName;
import glaze.kit.Size;
import glaze.kit.button.Toggle;
import glaze.kit.button.Toggle.ToggleGroup;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

class ToggleStory extends Model implements Story {

    public static function title():String {
        return 'Toggle';
    }

    public static function description():String {
        return 'Turn an option on or off, alone or in a group.';
    }

    public static function closable():Bool {
        return false;
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(_:Window, cx:App):Entity<ToggleStory> {
        return cx.newEntity((c:Context<ToggleStory>) -> new ToggleStory(c));
    }

    final focusHandle_:FocusHandle;

    @observe var singleToggle:Int = 1;

    @observe var checked:Array<Bool> = [for (_ in 0...12) false];

    @observe var size:Size = glaze.kit.Size.Medium;

    function new(cx:Context<ToggleStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    /** Rust `this.checked[start..start + values.len()].copy_from_slice(values)`. */
    function copyChecked(start:Int, values:Array<Bool>):Void {
        final next = checked.copy();
        for (i in 0...values.length) next[start + i] = values[i];
        checked = next;
    }

    function iconGroup(id:String, start:Int):ToggleGroup {
        return ToggleGroup.component(id)
            .withSize(size)
            .child(Toggle.component(0).icon(IconName.Bell).checked(checked[start]))
            .child(Toggle.component(1).icon(IconName.Inbox).checked(checked[start + 1]))
            .child(Toggle.component(2).icon(IconName.Check).checked(checked[start + 2]))
            .onClick((values, _, _) -> copyChecked(start, values));
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        return vFlex()
            .wFull()
            .gap3()
            .onAction(ChangeStorySize, (action, _, _) -> size = action.value)
            .child(storyToolbar(size))
            .child(section('Default')
                .description('Text and icon toggles with clear selected states.')
                .w128()
                .vFlex()
                .itemsCenter()
                .gap3()
                .child(hFlex()
                    .gap2()
                    .child(Toggle.component('preview')
                        .label('Preview')
                        .withSize(size)
                        .checked(singleToggle == 1)
                        .onClick((checked, _, _) -> singleToggle = checked ? 1 : 0))
                    .child(Toggle.component('favorite')
                        .icon(IconName.Star)
                        .withSize(size)
                        .checked(checked[0])
                        .onClick((value, _, _) -> copyChecked(0, [value])))))
            .child(section('Variants')
                .description('Ghost and outline treatments for different surfaces.')
                .w128()
                .vFlex()
                .itemsCenter()
                .gap4()
                .child(vFlex()
                    .itemsCenter()
                    .gap2()
                    .child(div().textSm().fontMedium().child('Ghost'))
                    .child(iconGroup('ghost-group', 1)))
                .child(vFlex()
                    .itemsCenter()
                    .gap2()
                    .child(div().textSm().fontMedium().child('Outline'))
                    .child(iconGroup('outline-group', 4).outline())))
            .child(section('Group')
                .description('Connected toggles keep related choices together.')
                .w128()
                .vFlex()
                .itemsCenter()
                .child(ToggleGroup.component('segmented-group')
                    .segmented()
                    .outline()
                    .withSize(size)
                    .child(Toggle.component(0).label('Bold').checked(checked[7]))
                    .child(Toggle.component(1).label('Italic').checked(checked[8]))
                    .child(Toggle.component(2).label('Code').checked(checked[9]))
                    .onClick((values, _, _) -> copyChecked(7, values))));
    }

}
