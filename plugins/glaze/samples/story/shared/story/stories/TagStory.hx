// Ported from gpui-kit 0.8.1: crates/story/src/stories/tag_story.rs
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
import gpui.component.Size;
import gpui.component.tag.Tag;
import gpui.component.theme.ColorName;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import gpui.component.theme.Color.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using gpui.base.StyledExt;

class TagStory extends Model implements Story {

    public static function title():String {
        return 'Tag';
    }

    public static function description():String {
        return 'A short item that can be used to categorize or label content.';
    }

    public static function newView(window:Window, cx:App):gpui.AnyView {
        return view(window, cx);
    }

    public static function view(_:Window, cx:App):Entity<TagStory> {
        return cx.newEntity((c:Context<TagStory>) -> new TagStory(c));
    }

    final focusHandle_:FocusHandle;

    @observe var size:Size = gpui.component.Size.Medium;

    function new(cx:Context<TagStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    function variants():Array<Tag> {
        return [
            Tag.primary().withSize(size),
            Tag.secondary().withSize(size),
            Tag.danger().withSize(size),
            Tag.success().withSize(size),
            Tag.warning().withSize(size),
            Tag.info().withSize(size),
        ];
    }

    static final LABELS = ['Tag', 'Secondary', 'Danger', 'Success', 'Warning', 'Info'];

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final defaults = variants();
        final outlines = variants();
        final roundeds = variants();
        final squares = variants();
        return vFlex()
            .wFull()
            .gap3()
            .onAction(ChangeStorySize, (action, _, _) -> size = action.value)
            .child(storyToolbar(size))
            .child(section('Default').child(hFlex()
                .gap2()
                .children([for (i in 0...6) (defaults[i].child(LABELS[i]) : IntoElement)])
                .child(Tag.custom(indigo500(), indigo50(), indigo500()).withSize(size).child('Custom'))))
            .child(section('Outline').child(hFlex()
                .gap2()
                .children([for (i in 0...6) (outlines[i].outline().child(LABELS[i]) : IntoElement)])
                .child(Tag.custom(indigo500(), indigo500(), indigo500()).withSize(size).outline().child('Custom'))))
            .child(section('Rounded').child(hFlex()
                .gap2()
                .children([for (i in 0...6) (roundeds[i].roundedFull().child(LABELS[i]) : IntoElement)])))
            .child(section('Square').child(hFlex()
                .gap2()
                .children([for (i in 0...6) (squares[i].rounded(px(0.)).child(LABELS[i]) : IntoElement)])))
            .child(section('Colors').w(px(640.)).child(vFlex().wFull().gap4().child(hFlex()
                .wFull()
                .gap2()
                .flexWrap()
                .children([for (color in ColorName.all()) if (color != ColorName.Gray) (Tag.color(color).withSize(size).child(color.toString()) : IntoElement)]))));
    }

}
