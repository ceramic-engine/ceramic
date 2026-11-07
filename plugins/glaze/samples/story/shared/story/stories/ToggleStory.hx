// Ported from gpui-kit 0.8.1: crates/story/src/stories/toggle_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.

package story.stories;

import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.Window;
import gpui.component.IconName;
import gpui.component.Size;
import gpui.component.button.Toggle;
import gpui.component.button.Toggle.ToggleGroup;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using gpui.base.StyledExt;

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

    public static function newView(window:Window, cx:App):gpui.AnyView {
        return view(window, cx);
    }

    public static function view(_:Window, cx:App):Entity<ToggleStory> {
        return cx.newEntity((c:Context<ToggleStory>) -> new ToggleStory(c));
    }

    final focusHandle_:FocusHandle;

    @observe var singleToggle:Int = 1;

    @observe var checked:Array<Bool> = [for (_ in 0...12) false];

    @observe var size:Size = gpui.component.Size.Medium;

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
        return new ToggleGroup(id)
            .withSize(size)
            .child(new Toggle(0).icon(IconName.Bell).checked(checked[start]))
            .child(new Toggle(1).icon(IconName.Inbox).checked(checked[start + 1]))
            .child(new Toggle(2).icon(IconName.Check).checked(checked[start + 2]))
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
                    .child(new Toggle('preview')
                        .label('Preview')
                        .withSize(size)
                        .checked(singleToggle == 1)
                        .onClick((checked, _, _) -> singleToggle = checked ? 1 : 0))
                    .child(new Toggle('favorite')
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
                .child(new ToggleGroup('segmented-group')
                    .segmented()
                    .outline()
                    .withSize(size)
                    .child(new Toggle(0).label('Bold').checked(checked[7]))
                    .child(new Toggle(1).label('Italic').checked(checked[8]))
                    .child(new Toggle(2).label('Code').checked(checked[9]))
                    .onClick((values, _, _) -> copyChecked(7, values))));
    }

}
