// Ported from gpui-kit 0.8.1: crates/story/src/stories/slider_story.rs
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
import gpui.Action;
import gpui.Corners;
import gpui.Hsla;
import gpui.Subscription;
import gpui.base.Slider.SliderEvent;
import gpui.base.Slider.SliderScale;
import gpui.base.Slider.SliderState;
import gpui.base.Slider.SliderValue;
import gpui.component.button.Button;
import gpui.component.chart.ChartFormat;
import gpui.component.clipboard.Clipboard;
import gpui.component.slider.Slider;
import gpui.component.theme.Colorize;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using gpui.base.StyledExt;
using gpui.component.WindowExt;

@:action(namespace = slider_story, noJson) private class ToggleDisabled implements Action {}

class SliderStory extends Model implements Story {

    public static function title():String {
        return 'Slider';
    }

    public static function description():String {
        return 'Displays a slider control for selecting a value within a range.';
    }

    public static function newView(window:Window, cx:App):gpui.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<SliderStory> {
        return cx.newEntity((c:Context<SliderStory>) -> new SliderStory(window, c));
    }

    final focusHandle_:FocusHandle;

    final slider1:Entity<SliderState>;

    @observe var slider1Value:Float = 75.;

    @observe var slider1ReleasedValue:Float = 75.;

    final slider3:Entity<SliderState>;

    @observe var slider3ReleasedValue:SliderValue = Range(12.0, 45.0);

    final sliderHsl:Array<Entity<SliderState>>;

    @observe var sliderHslValue:Hsla = red();

    final sliderLogarithmic:Entity<SliderState>;

    final sliderReverse:Entity<SliderState>;

    final sliderDuration:Entity<SliderState>;

    @observe var durationMonths:Float = 5.;

    final sliderTemperature:Entity<SliderState>;

    @observe var temperatureKelvin:Float = 3600.;

    @observe var disabled:Bool = false;

    final subscriptions:Array<Subscription>;

    function new(window:Window, cx:Context<SliderStory>) {
        super();
        slider1 = cx.newEntity((_:Context<SliderState>) -> new SliderState().min(-255.).max(255.).defaultValue(75.).step(15.));
        sliderHsl = [
            cx.newEntity((_:Context<SliderState>) -> new SliderState().min(0.).max(1.).step(0.01).defaultValue(0.38)),
            cx.newEntity((_:Context<SliderState>) -> new SliderState().min(0.).max(1.).step(0.01).defaultValue(0.5)),
            cx.newEntity((_:Context<SliderState>) -> new SliderState().min(0.).max(1.).step(0.01).defaultValue(0.5)),
            cx.newEntity((_:Context<SliderState>) -> new SliderState().min(0.).max(1.).step(0.01).defaultValue(0.5)),
        ];
        slider3 = cx.newEntity((_:Context<SliderState>) -> new SliderState().min(0.).max(100.).defaultValue([12.0, 45.0]).step(1.));
        sliderLogarithmic = cx.newEntity((_:Context<SliderState>) -> new SliderState()
            .min(0.25)
            .max(4.0)
            .defaultValue(1.0)
            .step(0.05)
            .scale(SliderScale.Logarithmic));
        sliderReverse = cx.newEntity((_:Context<SliderState>) -> new SliderState().min(0.).max(10.).step(1.).defaultValue(5.));
        sliderDuration = cx.newEntity((_:Context<SliderState>) -> new SliderState().min(0.).max(12.).step(1.).defaultValue(5.));
        sliderTemperature = cx.newEntity((_:Context<SliderState>) -> new SliderState().max(6500.).min(2000.).step(100.).defaultValue(3600.));
        final subs = [
            cx.subscribe(slider1, SliderEvent, (this_, _, event, _) -> switch event {
                case Change(value):
                    this_.slider1Value = value.start();
                case Release(value):
                    this_.slider1ReleasedValue = value.start();
            }),
            cx.subscribe(slider3, SliderEvent, (this_, _, event, _) -> switch event {
                case Change(_):
                case Release(value):
                    this_.slider3ReleasedValue = value;
            }),
            cx.subscribeIn(sliderDuration, SliderEvent, window, (this_, slider, event, window, cx) -> switch event {
                case Change(value):
                    final month = value.start();
                    slider.update(cx, (slider, cx) -> slider.setValue(month, window, cx));
                    this_.durationMonths = month;
                case _:
            }),
            cx.subscribe(sliderTemperature, SliderEvent, (this_, _, event, _) -> switch event {
                case Change(value):
                    this_.temperatureKelvin = value.start();
                case _:
            }),
        ];
        for (slider in sliderHsl) {
            subs.push(cx.subscribe(slider, SliderEvent, (this_, _, event, cx) -> switch event {
                case Change(_):
                    this_.sliderHslValue = hsla(
                        this_.sliderHsl[0].read(cx.app).value().start(),
                        this_.sliderHsl[1].read(cx.app).value().start(),
                        this_.sliderHsl[2].read(cx.app).value().start(),
                        this_.sliderHsl[3].read(cx.app).value().start()
                    );
                case Release(_):
            }));
        }
        subscriptions = subs;
        sliderHsl[0].update(cx, (slider, cx) -> cx.emit(SliderEvent.Change(slider.value())));
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    /** Rust `format!("{}", f32)`: the shortest digits, no `.0` on integers. */
    static function display(value:Float):String {
        final text = gpui.base.dock.JsonValue.JsonValueTools.formatF32(value);
        return StringTools.endsWith(text, '.0') ? text.substr(0, text.length - 2) : text;
    }

    /** Rust `SliderValue`'s `Display`. */
    static function displayValue(value:SliderValue):String {
        return switch value {
            case Single(v): display(v);
            case Range(start, end): '${display(start)}..${display(end)}';
        }
    }

    function hslColumn(slider:Entity<SliderState>, label:String, value:Float):IntoElement {
        return vFlex()
            .h32()
            .gap3()
            .itemsCenter()
            .justifyCenter()
            .child(new Slider(slider).vertical().disabled(disabled))
            .child(vFlex().itemsCenter().child(label).child(ChartFormat.fixed(value, 0)));
    }

    static function labelRow(cx:App, label:String, value:String):IntoElement {
        return hFlex()
            .itemsCenter()
            .justifyBetween()
            .child(div().fontMedium().child(label))
            .child(div().textSm().textColor(Theme.global(cx).mutedForeground).child(value));
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final app = cx.app;
        final rgb = Colorize.toHex(sliderHslValue);
        final neutralTemperature = theme.mode.isDark() ? theme.foreground : theme.background;
        final warmTemperature = neutralTemperature.blend(theme.warning.opacity(0.85));
        final coolTemperature = neutralTemperature.blend(theme.info.opacity(0.65));
        final temperatureRadius = theme.radiusFull();
        final disabled = this.disabled;
        return vFlex()
            .wFull()
            .itemsCenter()
            .gap3()
            .onAction(ToggleDisabled, (_, _, _) -> this.disabled = !this.disabled)
            .child(storyToolbarGroup().dropdownChild(new Button('slider-options').label('Options'),
                (menu, _, _) -> menu.menuWithCheck('Disabled', disabled, new ToggleDisabled())))
            .child(section('Default')
                .description('Adjust a single value within a defined range.')
                .w128()
                .itemsCenter()
                .child(vFlex()
                    .w(px(360.))
                    .gap4()
                    .p4()
                    .rounded(theme.radiusLg)
                    .border1()
                    .borderColor(theme.border)
                    .child(labelRow(app, 'Output volume', display(slider1Value)))
                    .child(new Slider(slider1).disabled(disabled))))
            .child(section('Range')
                .description('Choose minimum and maximum values together.')
                .w128()
                .itemsCenter()
                .child(vFlex()
                    .w(px(360.))
                    .gap4()
                    .p4()
                    .rounded(theme.radiusLg)
                    .bg(theme.muted.opacity(0.4))
                    .child(labelRow(app, 'Price range', '$$' + displayValue(slider3.read(app).value())))
                    .child(new Slider(slider3).disabled(disabled))))
            .child(section('Reverse')
                .description('Reverse the fill direction for remaining capacity.')
                .w128()
                .itemsCenter()
                .child(vFlex()
                    .w(px(360.))
                    .gap4()
                    .child(labelRow(app, 'Storage remaining', '${display(gpui.SpringMath.f32(10. - sliderReverse.read(app).value().start()))} GB'))
                    .child(new Slider(sliderReverse).horizontal().reverse().disabled(disabled))))
            .child(section('Duration')
                .description('Compose a slider with a labeled tick scale.')
                .w128()
                .itemsCenter()
                .child(vFlex()
                    .w(px(360.))
                    .gap2()
                    .child(labelRow(app, 'Duration (months)', ChartFormat.fixed(durationMonths, 0)))
                    .child(vFlex()
                        .px4()
                        .child(new Slider(sliderDuration).disabled(disabled))
                        .child(div().relative().wFull().h(px(34.)).children([for (month in 0...13) {
                            final major = month % 2 == 0;
                            (vFlex()
                                .absolute()
                                .left(relative(month / 12.))
                                .ml(px(-16.))
                                .w(px(32.))
                                .itemsCenter()
                                .child(div()
                                    .w(px(1.))
                                    .h(major ? px(6.) : px(3.))
                                    .bg(theme.mutedForeground))
                                .when(major, this_ -> this_.child(div()
                                    .mt2()
                                    .textSm()
                                    .textColor(theme.mutedForeground)
                                    .child(Std.string(month)))) : IntoElement);
                        }])))))
            .child(section('Color temperature')
                .description('Place a color scale beside a regular slider.')
                .w128()
                .itemsCenter()
                .child(vFlex()
                    .w(px(360.))
                    .gap3()
                    .child(labelRow(app, 'Color temperature', '${ChartFormat.fixed(temperatureKelvin, 0)} K'))
                    .child(hFlex()
                        .wFull()
                        .h3()
                        .child(div()
                            .flex1()
                            .hFull()
                            .cornerRadii(new Corners(temperatureRadius, 0., 0., temperatureRadius))
                            .bg(linearGradient(90., linearColorStop(warmTemperature, 0.), linearColorStop(neutralTemperature, 1.))))
                        .child(div()
                            .flex1()
                            .hFull()
                            .cornerRadii(new Corners(0., temperatureRadius, temperatureRadius, 0.))
                            .bg(linearGradient(90., linearColorStop(neutralTemperature, 0.), linearColorStop(coolTemperature, 1.)))))
                    .child(new Slider(sliderTemperature).disabled(disabled))))
            .child(section('Color Picker')
                .subTitle(hFlex()
                    .gap2()
                    .itemsCenter()
                    .child(hFlex().textColor(sliderHslValue).child(rgb))
                    .child(new Clipboard('copy-hsl').value(rgb).onCopied((_, window, cx) -> window.pushNotification('Color copied to clipboard.', cx))))
                .w128()
                .itemsCenter()
                .justifyAround()
                .child(hslColumn(sliderHsl[0], 'Hue', sliderHslValue.h * 360.))
                .child(hslColumn(sliderHsl[1], 'Saturation', sliderHslValue.s * 100.))
                .child(hslColumn(sliderHsl[2], 'Lightness', sliderHslValue.l * 100.))
                .child(hslColumn(sliderHsl[3], 'Alpha', sliderHslValue.a * 100.)))
            .child(section('Playback speed')
                .description('Logarithmic scales provide finer control near common values.')
                .w128()
                .itemsCenter()
                .child(vFlex()
                    .w(px(360.))
                    .gap4()
                    .child(hFlex()
                        .itemsCenter()
                        .justifyBetween()
                        .child(div().fontMedium().child('Speed'))
                        .child('${ChartFormat.fixed(sliderLogarithmic.read(app).value().start(), 2)}×'))
                    .child(new Slider(sliderLogarithmic).horizontal().disabled(disabled))));
    }

}
