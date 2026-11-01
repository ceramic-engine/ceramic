// Ported from gpui-kit 0.8.1: crates/story/src/stories/carousel_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import gpui.AnyView;
import gpui.App;
import gpui.Axis;
import gpui.Context;
import gpui.ElementId;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Model;
import gpui.StyleBuilder;
import gpui.StyleRefinement;
import gpui.Subscription;
import gpui.Window;
import gpui.component.Size;
import gpui.component.button.Button;
import gpui.component.carousel.Carousel;
import gpui.component.carousel.CarouselContent;
import gpui.component.carousel.CarouselItem;
import gpui.component.carousel.CarouselNext;
import gpui.component.carousel.CarouselPagination;
import gpui.component.carousel.CarouselPaginationItem;
import gpui.component.carousel.CarouselPrevious;
import gpui.component.carousel.CarouselState;
import gpui.component.carousel.CarouselState.CarouselEvent;
import gpui.component.theme.Theme;
import story.Story;
import story.StoryActions.ChangeStorySize;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Lib.*;

using gpui.base.StyledExt;

private enum SlideTypography {
    Large;
    Medium;
    Small;
}

class CarouselStory extends Model implements Story {

    final focusHandleValue:FocusHandle;
    final horizontal:Entity<CarouselState>;
    final customControls:Entity<CarouselState>;
    final multiple:Entity<CarouselState>;
    final vertical:Entity<CarouselState>;
    final looped:Entity<CarouselState>;
    final controlled:Entity<CarouselState>;
    var controlledIndex:Int;
    var size:Size;
    final subscriptions:Array<Subscription>;

    public static function title():String {
        return 'Carousel';
    }

    public static function description():String {
        return 'A carousel for browsing a set of related items with keyboard and pointer navigation.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function view(_:Window, cx:App):Entity<CarouselStory> {
        return cx.newEntity((cx:Context<CarouselStory>) -> new CarouselStory(cx));
    }

    function new(cx:Context<CarouselStory>) {
        super();
        horizontal = cx.newEntity((_:Context<CarouselState>) -> new CarouselState(3));
        customControls = cx.newEntity((_:Context<CarouselState>) -> new CarouselState(3));
        multiple = cx.newEntity((_:Context<CarouselState>) -> new CarouselState(5));
        vertical = cx.newEntity((_:Context<CarouselState>) -> new CarouselState(3).withAxis(Axis.Vertical));
        looped = cx.newEntity((_:Context<CarouselState>) -> new CarouselState(4).withLooping(true));
        controlled = cx.newEntity((_:Context<CarouselState>) -> new CarouselState(3).withSelectedIndex(1));

        final subscription = cx.subscribe(controlled, CarouselEvent, (this_:CarouselStory, _, event, cx) -> {
            switch event {
                case Change(index):
                    this_.controlledIndex = index;
            }
            cx.notify();
        });

        focusHandleValue = cx.focusHandle();
        controlledIndex = 1;
        size = gpui.component.Size.Medium;
        subscriptions = [subscription];
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandleValue;
    }

    static function slide(label:String, typography:SlideTypography, square:Bool, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final el = div().wFull();
        if (square) el.aspectSquare();
        if (!square) el.hFull();
        el.flex()
            .itemsCenter()
            .justifyCenter()
            .p6()
            .rounded(theme.radiusTokens().xl)
            .border1()
            .borderColor(theme.border)
            .bg(theme.background)
            .textColor(theme.foreground)
            .fontSemibold();
        switch typography {
            case Large: el.textSize(rems(2.25));
            case Medium: el.text3xl();
            case Small: el.text2xl();
        }
        return el.child(label);
    }

    static function items(state:Entity<CarouselState>, prefix:String, count:Int, typography:SlideTypography, square:Bool, cx:App):CarouselContent {
        return itemsWith(state, prefix, count, typography, square, item -> item, cx);
    }

    static function itemsWith(state:Entity<CarouselState>, prefix:String, count:Int, typography:SlideTypography, square:Bool,
            configure:CarouselItem->CarouselItem, cx:App):CarouselContent {
        final content = new CarouselContent(state);
        for (index in 0...count) {
            final label = Std.string(index + 1);
            content.child(configure(new CarouselItem(ElementId.NamedInteger(prefix, index), index, state))
                .child(slide(label, typography, square, cx)));
        }
        return content;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<CarouselStory> = cast cx;
        final app = cx.app;
        final trackStyle = new StyleRefinement();
        new StyleBuilder(trackStyle).mlNeg1();

        return vFlex()
            .wFull()
            .gap4()
            .onAction(ChangeStorySize, self.listener((this_:CarouselStory, action:ChangeStorySize, _, cx) -> {
                this_.size = action.value;
                cx.notify();
            }))
            .child(storyToolbar(size))
            .child(section('Basic')
                .description('Browse one full-width item at a time with Left and Right.')
                .vFlex()
                .gap3()
                .child(new Carousel('carousel-horizontal', horizontal)
                    .wFull()
                    .maxW96()
                    .mxAuto()
                    .child(items(horizontal, 'Horizontal', 3, Large, true, app))
                    .child(new CarouselPrevious(horizontal).withSize(size))
                    .child(new CarouselNext(horizontal).withSize(size))
                    .child(new CarouselPagination().children([for (index in 0...3) new CarouselPaginationItem(ElementId.NamedInteger('horizontal-pagination', index), index,
                        horizontal)
                        .withSize(size)
                        .child(Std.string(index + 1))]))))
            .child(section('Custom controls')
                .description('Replace control content and accessibility labels while retaining navigation behavior.')
                .vFlex()
                .gap3()
                .child(new Carousel('carousel-custom-controls', customControls)
                    .wFull()
                    .maxW96()
                    .mxAuto()
                    .child(items(customControls, 'Custom Controls', 3, Large, true, app))
                    .child(new CarouselPrevious(customControls)
                        .withSize(size)
                        .accessibilityLabel('Previous project')
                        .child('Back'))
                    .child(new CarouselNext(customControls)
                        .withSize(size)
                        .accessibilityLabel('Next project')
                        .child('Forward'))))
            .child(section('Multiple items')
                .description('A fractional flex basis shows several items at once. Pair the content\'s negative margin with matching item padding to tune the gap between them.')
                .vFlex()
                .gap3()
                .child(new Carousel('carousel-multiple', multiple)
                    .wFull()
                    .maxW96()
                    .mxAuto()
                    .child(itemsWith(multiple, 'Multiple', 5, Small, true, item -> item.flexBasis(relative(1. / 3.)).pl1(), app)
                        .trackStyle(trackStyle))
                    .child(new CarouselPrevious(multiple).withSize(size))
                    .child(new CarouselNext(multiple).withSize(size))))
            .child(section('Vertical')
                .description('Use Up and Down to navigate a vertical carousel.')
                .vFlex()
                .gap3()
                .child(new Carousel('carousel-vertical', vertical)
                    .wFull()
                    .maxW64()
                    .mxAuto()
                    .child(itemsWith(vertical, 'Vertical', 3, Medium, false, item -> item.flexBasis(relative(0.5)), app)
                        .h48())
                    .child(new CarouselPrevious(vertical).withSize(size))
                    .child(new CarouselNext(vertical).withSize(size))))
            .child(section('Looping')
                .description('Looping navigation wraps from the last slide to the first.')
                .vFlex()
                .gap3()
                .child(new Carousel('carousel-looped', looped)
                    .wFull()
                    .maxW96()
                    .mxAuto()
                    .child(items(looped, 'Looped', 4, Large, true, app))
                    .child(new CarouselPrevious(looped).withSize(size))
                    .child(new CarouselNext(looped).withSize(size))))
            .child(section('Controlled')
                .description('The selected index is owned by application state and can be changed programmatically.')
                .vFlex()
                .gap3()
                .child(new Carousel('carousel-controlled', controlled)
                    .wFull()
                    .maxW96()
                    .mxAuto()
                    .child(items(controlled, 'Controlled', 3, Large, true, app))
                    .child(new CarouselPrevious(controlled).withSize(size))
                    .child(new CarouselNext(controlled).withSize(size)))
                .child(hFlex()
                    .gap2()
                    .child(div().child('Selected slide: ${controlledIndex + 1}'))
                    .child(new Button('controlled-first')
                        .label('Go to first')
                        .onClick(self.listener((this_:CarouselStory, _, _, cx) -> {
                            this_.controlledIndex = 0;
                            final controlled = this_.controlled;
                            controlled.update(cx, (state, cx) -> {
                                state.setSelectedIndex(0, cx);
                            });
                            cx.notify();
                        })))
                    .child(new Button('controlled-last')
                        .label('Go to last')
                        .onClick(self.listener((this_:CarouselStory, _, _, cx) -> {
                            this_.controlledIndex = 2;
                            final controlled = this_.controlled;
                            controlled.update(cx, (state, cx) -> {
                                state.setSelectedIndex(2, cx);
                            });
                            cx.notify();
                        })))));
    }

}
