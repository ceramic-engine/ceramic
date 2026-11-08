// Ported from gpui-kit 0.8.1: crates/story/src/stories/shimmer_story.rs
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
import glaze.ElementId;
import glaze.kit.attachment.Attachment;
import glaze.kit.button.Button;
import glaze.kit.marker.Marker;
import glaze.kit.marker.Marker.MarkerAlignment;
import glaze.kit.marker.Marker.MarkerContent;
import glaze.kit.marker.Marker.MarkerIcon;
import glaze.kit.marker.Marker.MarkerLoadingStyle;
import glaze.kit.marker.Marker.MarkerVariant;
import glaze.kit.shimmer.ShimmerText;
import glaze.kit.shimmer.ShimmerText.ShimmerStyle;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

class ShimmerStory extends Model implements Story {

    public static function title():String {
        return 'Shimmer';
    }

    public static function description():String {
        return 'Reusable, theme-aware text loading effects with composable timing and appearance.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
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
                .child(ShimmerText.component('Thinking…'))
                .child(ShimmerText.component('Searching the current project…').textColor(theme.mutedForeground)))
            .child(section('Color')
                .description('Highlight colors come from semantic theme roles.')
                .maxW(rems(42.5))
                .vFlex()
                .gap2()
                .child(ShimmerText.component('Automatic theme-aware highlight'))
                .child(ShimmerText.component('Primary highlight').highlightColor(theme.primary))
                .child(ShimmerText.component('Success highlight').highlightColor(theme.success)))
            .child(section('Duration')
                .description('Each duration controls one complete sweep.')
                .maxW(rems(42.5))
                .vFlex()
                .gap2()
                .child(ShimmerText.component('Quick sweep · 1 second').duration(1.))
                .child(ShimmerText.component('Default sweep · 2 seconds').duration(2.))
                .child(ShimmerText.component('Relaxed sweep · 4 seconds').duration(4.)))
            .child(section('Spread')
                .description('Spread is a relative or absolute highlight half-width.')
                .maxW(rems(42.5))
                .vFlex()
                .gap2()
                .child(ShimmerText.component('Narrow highlight · 0.12').spread(Relative(0.12)))
                .child(ShimmerText.component('Default highlight · 0.30').spread(Relative(0.30)))
                .child(ShimmerText.component('Wide highlight · 0.60').spread(Relative(0.60)))
                .child(ShimmerText.component('Fixed highlight · 48px').spread(Absolute(px(48.)))))
            .child(section('Direction')
                .description('Reverse changes movement without replacing text or layout.')
                .maxW(rems(42.5))
                .vFlex()
                .gap2()
                .child(ShimmerText.component('Forward · left to right'))
                .child(ShimmerText.component('Reverse · right to left').reverse(true)))
            .child(section('Play once')
                .description('A stable explicit identity controls one-shot playback and replay.')
                .maxW(rems(42.5))
                .vFlex()
                .gap3()
                .child(ShimmerText.component('A single sweep completes and then stops')
                    .id(ElementId.NamedInteger('shimmer-single-sweep', replayCount))
                    .once(true))
                .child(Button.component('shimmer-replay')
                    .label('Replay')
                    .onClick((_, _, _) -> this.replayCount++)))
            .child(section('Reusable style')
                .description('One ShimmerStyle can be shared by independent status labels.')
                .maxW(rems(42.5))
                .vFlex()
                .gap2()
                .child(ShimmerText.component('Analyzing source files…').withShimmerStyle(sharedStyle))
                .child(ShimmerText.component('Preparing a response…').withShimmerStyle(sharedStyle)))
            .child(section('Typography and wrapping')
                .description('Text inherits typography, color, and the surrounding layout.')
                .maxW(rems(42.5))
                .vFlex()
                .gap3()
                .child(ShimmerText.component('Compact supporting status').textSm().textColor(theme.mutedForeground))
                .child(ShimmerText.component('Prominent status').textLg().fontSemibold())
                .child(hFlex()
                    .w(rems(24.))
                    .maxWFull()
                    .minW0()
                    .child(ShimmerText.component('Long loading messages remain readable as the surrounding region becomes narrower.'))))
            .child(section('Marker')
                .description('Marker applies the same reusable style to its text content.')
                .maxW(rems(42.5))
                .vFlex()
                .child(Marker.component()
                    .loading(true)
                    .withLoadingStyle(MarkerLoadingStyle.Shimmer)
                    .withShimmerStyle(sharedStyle)
                    .content(MarkerContent.component().text('Generating an answer…'))))
            .child(section('Attachment')
                .description('An uploading or processing title can share its loading style.')
                .maxW(rems(42.5))
                .child(Attachment.component()
                    .status(AttachmentStatus.Processing)
                    .content(AttachmentContent.component()
                        .title(AttachmentTitle.component('meeting-transcript.pdf').withShimmerStyle(sharedStyle))
                        .description(AttachmentDescription.component('Extracting key discussion points')))));
    }

}
