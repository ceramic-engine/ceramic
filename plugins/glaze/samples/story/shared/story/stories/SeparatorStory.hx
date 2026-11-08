// Ported from gpui-kit 0.8.1: crates/story/src/stories/separator_story.rs
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
import glaze.kit.label.Label;
import glaze.kit.separator.Separator;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

private final DESCRIPTION = 'GPUI Component is a Rust GUI components for building fantastic cross-platform desktop application by using GPUI.';

class SeparatorStory extends Model implements Story {

    public static function title():String {
        return 'Separator';
    }

    public static function description():String {
        return 'A separator that can be either vertical or horizontal.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(_:Window, cx:App):Entity<SeparatorStory> {
        return cx.newEntity((c:Context<SeparatorStory>) -> new SeparatorStory(c));
    }

    final focusHandle_:FocusHandle;

    function new(cx:Context<SeparatorStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        return vFlex()
            .gap6()
            .child(section('Horizontal')
                .description('Separates stacked content, with optional labels and dashed rules.')
                .w(px(520.))
                .child(vFlex()
                    .gap4()
                    .wFull()
                    .mt4()
                    .child(Separator.horizontal())
                    .child(Separator.horizontal().label('With Label'))
                    .child(Separator.horizontalDashed())
                    .child(Separator.horizontalDashed().label('Dashed With Label'))))
            .child(section('Vertical')
                .description('Separates actions or values arranged in a row.')
                .w(px(520.))
                .child(hFlex()
                    .gap4()
                    .h(px(100.))
                    .child(Separator.vertical())
                    .child(Separator.vertical().label('Solid'))
                    .child(Separator.verticalDashed())
                    .child(Separator.verticalDashed().label('Dashed'))))
            .child(section('In Context')
                .description('Horizontal and vertical rules can structure compact content.')
                .w(px(520.))
                .child(vFlex()
                    .gapY4()
                    .child(vFlex().gapY2().child('Hello GPUI Component').child(Label.component(DESCRIPTION)
                        .textColor(theme.mutedForeground)
                        .textSm()))
                    .child(Separator.horizontal())
                    .child(hFlex()
                        .gapX4()
                        .child('Docs')
                        .child(Separator.vertical().dashed())
                        .child('GitHub')
                        .child(Separator.vertical().dashed())
                        .child('Source'))));
    }

}
