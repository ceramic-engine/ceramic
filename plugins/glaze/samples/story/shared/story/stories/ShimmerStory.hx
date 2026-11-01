// Ported from gpui-kit 0.8.1: crates/story/src/stories/shimmer_story.rs
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
import gpui.ElementId;
import gpui.component.attachment.Attachment;
import gpui.component.button.Button;
import gpui.component.marker.Marker;
import gpui.component.marker.Marker.MarkerAlignment;
import gpui.component.marker.Marker.MarkerContent;
import gpui.component.marker.Marker.MarkerIcon;
import gpui.component.marker.Marker.MarkerLoadingStyle;
import gpui.component.marker.Marker.MarkerVariant;
import gpui.component.shimmer.ShimmerText;
import gpui.component.shimmer.ShimmerText.ShimmerStyle;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using gpui.base.StyledExt;

class ShimmerStory extends Model implements Story {

    public static function title():String {
        return 'Shimmer';
    }

    public static function description():String {
        return 'Reusable, theme-aware text loading effects with composable timing and appearance.';
    }

    public static function newView(window:Window, cx:App):gpui.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<ShimmerStory> {
        return cx.newEntity((c:Context<ShimmerStory>) -> new ShimmerStory(window, c));
    }

    final focusHandle_:FocusHandle;

    @observe var replayCount:Int = 0;

    function new(_:Window, cx:Context<ShimmerStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final replayCount = this.replayCount;
        final sharedStyle = new ShimmerStyle()
            .duration(3.)
            .highlightColor(theme.primary)
            .spread(Relative(0.42));

        return vFlex()
            .gap4()
            .child(section('Default')
                .description('A readable, theme-aware highlight crosses the existing text.')
                .maxW(rems(42.5))
                .vFlex()
                .gap2()
                .child(new ShimmerText('Thinking…'))
                .child(new ShimmerText('Searching the current project…').textColor(theme.mutedForeground)))
            .child(section('Color')
                .description('Highlight colors come from semantic theme roles.')
                .maxW(rems(42.5))
                .vFlex()
                .gap2()
                .child(new ShimmerText('Automatic theme-aware highlight'))
                .child(new ShimmerText('Primary highlight').highlightColor(theme.primary))
                .child(new ShimmerText('Success highlight').highlightColor(theme.success)))
            .child(section('Duration')
                .description('Each duration controls one complete sweep.')
                .maxW(rems(42.5))
                .vFlex()
                .gap2()
                .child(new ShimmerText('Quick sweep · 1 second').duration(1.))
                .child(new ShimmerText('Default sweep · 2 seconds').duration(2.))
                .child(new ShimmerText('Relaxed sweep · 4 seconds').duration(4.)))
            .child(section('Spread')
                .description('Spread is a relative or absolute highlight half-width.')
                .maxW(rems(42.5))
                .vFlex()
                .gap2()
                .child(new ShimmerText('Narrow highlight · 0.12').spread(Relative(0.12)))
                .child(new ShimmerText('Default highlight · 0.30').spread(Relative(0.30)))
                .child(new ShimmerText('Wide highlight · 0.60').spread(Relative(0.60)))
                .child(new ShimmerText('Fixed highlight · 48px').spread(Absolute(px(48.)))))
            .child(section('Direction')
                .description('Reverse changes movement without replacing text or layout.')
                .maxW(rems(42.5))
                .vFlex()
                .gap2()
                .child(new ShimmerText('Forward · left to right'))
                .child(new ShimmerText('Reverse · right to left').reverse(true)))
            .child(section('Play once')
                .description('A stable explicit identity controls one-shot playback and replay.')
                .maxW(rems(42.5))
                .vFlex()
                .gap3()
                .child(new ShimmerText('A single sweep completes and then stops')
                    .id(ElementId.NamedInteger('shimmer-single-sweep', replayCount))
                    .once(true))
                .child(new Button('shimmer-replay')
                    .label('Replay')
                    .onClick((_, _, _) -> this.replayCount++)))
            .child(section('Reusable style')
                .description('One ShimmerStyle can be shared by independent status labels.')
                .maxW(rems(42.5))
                .vFlex()
                .gap2()
                .child(new ShimmerText('Analyzing source files…').withShimmerStyle(sharedStyle))
                .child(new ShimmerText('Preparing a response…').withShimmerStyle(sharedStyle)))
            .child(section('Typography and wrapping')
                .description('Text inherits typography, color, and the surrounding layout.')
                .maxW(rems(42.5))
                .vFlex()
                .gap3()
                .child(new ShimmerText('Compact supporting status').textSm().textColor(theme.mutedForeground))
                .child(new ShimmerText('Prominent status').textLg().fontSemibold())
                .child(hFlex()
                    .w(rems(24.))
                    .maxWFull()
                    .minW0()
                    .child(new ShimmerText('Long loading messages remain readable as the surrounding region becomes narrower.'))))
            .child(section('Marker')
                .description('Marker applies the same reusable style to its text content.')
                .maxW(rems(42.5))
                .vFlex()
                .child(new Marker()
                    .loading(true)
                    .withLoadingStyle(MarkerLoadingStyle.Shimmer)
                    .withShimmerStyle(sharedStyle)
                    .content(new MarkerContent().text('Generating an answer…'))))
            .child(section('Attachment')
                .description('An uploading or processing title can share its loading style.')
                .maxW(rems(42.5))
                .child(new Attachment()
                    .status(AttachmentStatus.Processing)
                    .content(new AttachmentContent()
                        .title(new AttachmentTitle('meeting-transcript.pdf').withShimmerStyle(sharedStyle))
                        .description(new AttachmentDescription('Extracting key discussion points')))));
    }

}
