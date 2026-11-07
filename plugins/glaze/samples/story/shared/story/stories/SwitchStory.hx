// Ported from gpui-kit 0.8.1: crates/story/src/stories/switch_story.rs
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
import glaze.kit.Size;
import glaze.kit.separator.Separator;
import glaze.kit.switch_.Switch;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

class SwitchStory extends Model implements Story {

    public static function title():String {
        return 'Switch';
    }

    public static function description():String {
        return 'Turn a setting on or off.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<SwitchStory> {
        return cx.newEntity((c:Context<SwitchStory>) -> new SwitchStory(window, c));
    }

    final focusHandle_:FocusHandle;

    @observe var switch1:Bool = true;

    @observe var switch2:Bool = false;

    @observe var switch3:Bool = true;

    @observe var switch4:Bool = true;

    @observe var switch5:Bool = false;

    @observe var longLabelChecked:Bool = false;

    @observe var size:Size = glaze.kit.Size.Medium;

    function new(_:Window, cx:Context<SwitchStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    function settingRow(theme:Theme, title:String, description:String, control:Switch):IntoElement {
        return hFlex()
            .wFull()
            .itemsCenter()
            .justifyBetween()
            .gap6()
            .p4()
            .child(vFlex()
                .gap1()
                .child(div().fontMedium().child(title))
                .child(div().textSm().textColor(theme.mutedForeground).child(description)))
            .child(control);
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        return vFlex()
            .wFull()
            .gap3()
            .onAction(ChangeStorySize, (action, _, _) -> size = action.value)
            .child(storyToolbar(size))
            .child(section('Default')
                .description('Switches work well in a compact settings list.')
                .w128()
                .itemsStretch()
                .child(vFlex()
                    .wFull()
                    .border1()
                    .borderColor(theme.border)
                    .rounded(theme.radiusLg)
                    .child(settingRow(theme, 'Product updates', 'New features and release notes.', new Switch('switch1')
                        .withSize(size)
                        .checked(switch1)
                        .onClick((checked, _, _) -> switch1 = checked)))
                    .child(Separator.horizontal())
                    .child(settingRow(theme, 'Security alerts', 'Important activity on your account.', new Switch('switch2')
                        .withSize(size)
                        .checked(switch2)
                        .onClick((checked, _, _) -> switch2 = checked)))))
            .child(section('Long labels')
                .description('Long setting names wrap while the track keeps its size.')
                .child(vFlex()
                    .w(px(320.))
                    .border1()
                    .borderColor(theme.border)
                    .rounded(theme.radiusLg)
                    .child(new Switch('long-label')
                        .p4()
                        .withSize(size)
                        .label('Automatically transcribe downloaded episodes')
                        .checked(longLabelChecked)
                        .onChange((checked, _, _) -> longLabelChecked = checked))
                    .child(Separator.horizontal())
                    .child(new Switch('long-label-disabled')
                        .p4()
                        .withSize(size)
                        .label('Automatically download new episodes')
                        .checked(true)
                        .disabled(true))))
            .child(section('Disabled')
                .description('Unavailable switches preserve their current value.')
                .w128()
                .child(new Switch('switch3').withSize(size).checked(switch3).disabled(true))
                .child(new Switch('switch3_1')
                    .withSize(size)
                    .w(px(200.))
                    .label('Airplane mode')
                    .checked(true)
                    .disabled(true)))
            .child(section('Color')
                .description('Semantic colors can reinforce the setting state.')
                .child(new Switch('switch4')
                    .withSize(size)
                    .checked(switch4)
                    .label('Success')
                    .color(theme.success)
                    .onClick((checked, _, _) -> switch4 = checked))
                .child(new Switch('switch5')
                    .withSize(size)
                    .checked(switch5)
                    .label('Destructive')
                    .color(theme.danger)
                    .onClick((checked, _, _) -> switch5 = checked))
                .child(new Switch('switch4_disabled')
                    .withSize(size)
                    .checked(true)
                    .label('Disabled')
                    .color(theme.success)
                    .disabled(true)));
    }

}
