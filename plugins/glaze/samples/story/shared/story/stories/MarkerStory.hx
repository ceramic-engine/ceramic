// Ported from gpui-kit 0.8.1: crates/story/src/stories/marker_story.rs
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
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.button.Button;
import glaze.kit.link.Link;
import glaze.kit.marker.Marker;
import glaze.kit.marker.Marker.MarkerAlignment;
import glaze.kit.marker.Marker.MarkerContent;
import glaze.kit.marker.Marker.MarkerIcon;
import glaze.kit.marker.Marker.MarkerLoadingStyle;
import glaze.kit.marker.Marker.MarkerVariant;
import glaze.kit.shimmer.ShimmerText;
import glaze.kit.shimmer.ShimmerText.ShimmerStyle;
import glaze.kit.spinner.Spinner;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

class MarkerStory extends Model implements Story {

    public static function title():String {
        return 'Marker';
    }

    public static function description():String {
        return 'A compact row for conversation status, notifications, and separators.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<MarkerStory> {
        return cx.newEntity((c:Context<MarkerStory>) -> new MarkerStory(window, c));
    }

    final focusHandle_:FocusHandle;

    function new(_:Window, cx:Context<MarkerStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    static function icon(name:IconName):MarkerIcon {
        return MarkerIcon.component().child(Icon.component(name));
    }

    static function shimmer(text:String, ?style:ShimmerStyle):Marker {
        final marker = Marker.component().loading(true).withLoadingStyle(MarkerLoadingStyle.Shimmer);
        if (style != null) marker.withShimmerStyle(style);
        return marker.content(MarkerContent.component().text(text));
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        return vFlex()
            .gap4()
            .child(section('Variants')
                .description('Choose a plain row, a centered separator, or a bordered boundary.')
                .maxW(rems(42.5))
                .vFlex()
                .gap4()
                .child(Marker.component().content(MarkerContent.component().child('Plain status update')))
                .child(Marker.component().withVariant(MarkerVariant.Separator).content(MarkerContent.component().child('Earlier messages')))
                .child(Marker.component().withVariant(MarkerVariant.Border).content(MarkerContent.component().child('Unread messages'))))
            .child(section('Alignment')
                .description('Center a system notice or trail a delivery state; Separator centers by default.')
                .maxW(rems(42.5))
                .vFlex()
                .gap3()
                .child(Marker.component().content(MarkerContent.component().child('Leading by default')))
                .child(Marker.component()
                    .alignment(MarkerAlignment.Center)
                    .icon(icon(IconName.Info))
                    .content(MarkerContent.component().child('Messages are end-to-end encrypted')))
                .child(Marker.component()
                    .alignment(MarkerAlignment.Center)
                    .content(MarkerContent.component().child('The answer was stopped before it finished. Edit the question or ask again, and a long notice wraps around its center.')))
                .child(Marker.component()
                    .alignment(MarkerAlignment.Center)
                    .content(MarkerContent.component().child('The message could not be sent.'))
                    .child(Button.component('marker-retry-send').text().small().label('Retry')))
                .child(Marker.component().alignment(MarkerAlignment.End).content(MarkerContent.component().child('Delivered')))
                .child(Marker.component()
                    .withVariant(MarkerVariant.Separator)
                    .alignment(MarkerAlignment.End)
                    .content(MarkerContent.component().child('Today'))))
            .child(section('Status')
                .description('Compose icons, spinners, and labels without a fixed status model.')
                .maxW(rems(42.5))
                .vFlex()
                .gap3()
                .child(Marker.component()
                    .textColor(theme.success)
                    .icon(icon(IconName.CircleCheck))
                    .content(MarkerContent.component().child('Online')))
                .child(Marker.component()
                    .icon(MarkerIcon.component().child(glaze.kit.spinner.Spinner.component().xsmall()))
                    .content(MarkerContent.component().child('Alice is typing…')))
                .child(Marker.component()
                    .icon(icon(IconName.Bell))
                    .content(MarkerContent.component().child('Unread notifications')))
                .child(Marker.component()
                    .textColor(theme.danger)
                    .icon(icon(IconName.Info))
                    .content(MarkerContent.component().child('Message could not be delivered'))))
            .child(section('With icon')
                .description('Icons can communicate sender activity, notices, and saved items.')
                .maxW(rems(42.5))
                .vFlex()
                .gap3()
                .child(Marker.component().icon(icon(IconName.Info)).content(MarkerContent.component().child('Conversation details updated')))
                .child(Marker.component().icon(icon(IconName.Star)).content(MarkerContent.component().child('Pinned for your team')))
                .child(Marker.component().content(MarkerContent.component().child('No icon is required'))))
            .child(section('Loading styles')
                .description('Choose a spinner or a sweeping, ChatGPT-style text shimmer.')
                .maxW(rems(42.5))
                .vFlex()
                .gap4()
                .child(Marker.component()
                    .loading(true)
                    .withLoadingStyle(MarkerLoadingStyle.Spinner)
                    .content(MarkerContent.component().text('shadcn/ui · Loading messages…')))
                .child(shimmer('ChatGPT · Thinking'))
                .child(Marker.component()
                    .loading(true)
                    .withLoadingStyle(MarkerLoadingStyle.Shimmer)
                    .icon(icon(IconName.Info))
                    .content(MarkerContent.component().text('正在探索 4 个文件…')))
                .child(shimmer('Custom color, width, and direction', new ShimmerStyle()
                    .duration(3.)
                    .highlightColor(theme.primary)
                    .spread(Relative(0.45))
                    .reverse(true)))
                .child(ShimmerText.component('Reusable shimmer without a Marker').textColor(theme.mutedForeground)))
            .child(section('Shimmer settings')
                .description('Customize timing, highlight width, direction, and playback independently.')
                .maxW(rems(42.5))
                .vFlex()
                .gap3()
                .child(shimmer('Faster highlight sweep', new ShimmerStyle().duration(0.9)))
                .child(shimmer('Wider highlight band', new ShimmerStyle().spread(Relative(0.55))))
                .child(shimmer('Right-to-left sweep', new ShimmerStyle().reverse(true)))
                .child(shimmer('Semantic primary highlight', new ShimmerStyle().highlightColor(theme.primary)))
                .child(shimmer('Play the highlight once', new ShimmerStyle().once(true)))
                .child(Marker.component()
                    .loading(false)
                    .withLoadingStyle(MarkerLoadingStyle.Shimmer)
                    .content(MarkerContent.component().text('Loading is disabled'))))
            .child(section('Separator')
                .description('Place a conversation boundary between two semantic lines.')
                .maxW(rems(42.5))
                .vFlex()
                .gap4()
                .child(Marker.component().withVariant(MarkerVariant.Separator).content(MarkerContent.component().child('Today')))
                .child(Marker.component()
                    .withVariant(MarkerVariant.Separator)
                    .separatorStyle(new StyleBuilder(new StyleRefinement()).bg(theme.primary.opacity(0.35)).style())
                    .icon(icon(IconName.Star))
                    .content(MarkerContent.component().child('Pinned messages'))))
            .child(section('Border')
                .description('Use a bottom edge for an unread or section boundary.')
                .maxW(rems(42.5))
                .vFlex()
                .gap3()
                .child(Marker.component()
                    .withVariant(MarkerVariant.Border)
                    .icon(icon(IconName.Info))
                    .content(MarkerContent.component().child('3 unread messages')))
                .child(Marker.component()
                    .withVariant(MarkerVariant.Border)
                    .borderColor(theme.primary.opacity(0.4))
                    .content(MarkerContent.component().child('New replies since your last visit'))))
            .child(section('Links and buttons')
                .description('Keep external destinations and in-app commands semantically distinct.')
                .maxW(rems(42.5))
                .vFlex()
                .gap3()
                .child(Marker.component()
                    .icon(icon(IconName.Info))
                    .content(MarkerContent.component().child(glaze.kit.link.Link.component('marker-documentation-link')
                        .href('https://gpui-kit.com/')
                        .child('Open the component documentation'))))
                .child(Marker.component()
                    .icon(icon(IconName.Star))
                    .content(MarkerContent.component().child('A saved draft is ready'))
                    .child(Button.component('marker-open-draft').ghost().small().label('Open draft'))))
            .child(section('Custom style')
                .description('Caller refinements can replace spacing, color, and surface.')
                .maxW(rems(42.5))
                .child(Marker.component()
                    .px3()
                    .py2()
                    .rounded(theme.radius)
                    .bg(theme.accent)
                    .textColor(theme.accentForeground)
                    .icon(icon(IconName.Star))
                    .content(MarkerContent.component().child('Pinned message'))));
    }

}
