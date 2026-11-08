// Ported from gpui-kit 0.8.1: crates/story/src/stories/color_picker_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.Model;
import glaze.Subscription;
import glaze.Window;
import glaze.kit.base.ColorPicker.ColorPickerEvent;
import glaze.kit.base.ColorPicker.ColorPickerState;
import glaze.kit.Size;
import glaze.kit.colorpicker.ColorPicker;
import glaze.kit.theme.Color;
import glaze.kit.theme.Theme;
import story.Story;
import story.StoryActions.ChangeStorySize;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

using glaze.kit.base.StyledExt;
using glaze.kit.theme.Colorize;

class ColorPickerStory extends Model implements Story {

    final color:Entity<ColorPickerState>;

    final selectColor:Entity<ColorPickerState>;

    final emptySelectColor:Entity<ColorPickerState>;

    var selectedColor:Null<Hsla>;

    var size:Size;

    final subscriptions:Array<Subscription>;

    public static function title():String {
        return 'ColorPicker';
    }

    public static function description():String {
        return 'Choose and preview a color value.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<ColorPickerStory> {
        return cx.newEntity((cx:Context<ColorPickerStory>) -> new ColorPickerStory(window, cx));
    }

    function new(window:Window, cx:Context<ColorPickerStory>) {
        super();
        final defaultColor = Color.indigo500();
        color = cx.newEntity((cx:Context<ColorPickerState>) -> new ColorPickerState(window, cx).defaultValue(defaultColor));
        selectColor = cx.newEntity((cx:Context<ColorPickerState>) -> new ColorPickerState(window, cx).defaultValue(defaultColor));
        emptySelectColor = cx.newEntity((cx:Context<ColorPickerState>) -> new ColorPickerState(window, cx));

        subscriptions = [cx.subscribe(color, ColorPickerEvent, (this_:ColorPickerStory, _, ev:ColorPickerEvent, _) -> {
            switch ev {
                case Change(color):
                    this_.selectedColor = color;
            }
        })];

        selectedColor = defaultColor;
        size = Medium;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<ColorPickerStory> = cast cx;
        final theme = Theme.global(cx);
        final card = vFlex()
            .wFull()
            .gap4()
            .p4()
            .rounded(theme.radiusLg)
            .border1()
            .borderColor(theme.border)
            .child(hFlex()
                .wFull()
                .itemsCenter()
                .justifyBetween()
                .gap4()
                .child(vFlex()
                    .gap1()
                    .child(div().fontMedium().child('Accent color'))
                    .child(div()
                        .textSm()
                        .textColor(theme.mutedForeground)
                        .child('Used for primary actions and highlights.')))
                .child(ColorPicker.component(color).withSize(size)));
        final selected = selectedColor;
        if (selected != null) {
            card.child(vFlex()
                .wFull()
                .overflowHidden()
                .rounded(theme.radiusLg)
                .border1()
                .borderColor(theme.border)
                .child(div()
                    .wFull()
                    .roundedT(theme.radiusLg)
                    .h(px(96.))
                    .bg(selected))
                .child(hFlex()
                    .wFull()
                    .itemsCenter()
                    .justifyBetween()
                    .px3()
                    .py2()
                    .bg(theme.muted)
                    .child(div()
                        .textSm()
                        .textColor(theme.mutedForeground)
                        .child('Selected color'))
                    .child(div()
                        .fontFamily('monospace')
                        .fontMedium()
                        .child(selected.toHex()))));
        }

        return vFlex()
            .wFull()
            .itemsCenter()
            .gap6()
            .onAction(ChangeStorySize, self.listener((this_:ColorPickerStory, action:ChangeStorySize, _, cx) -> {
                this_.size = action.value;
                cx.notify();
            }))
            .child(storyToolbar(size))
            .child(section('Theme Color')
                .description('Select a color and preview the resulting value.')
                .w(px(440.))
                .child(card))
            .child(section('Color Select')
                .description('A framed field for forms: the whole field opens the picker, like a Select.')
                .w(px(440.))
                .child(vFlex()
                    .wFull()
                    .gap3()
                    .child(ColorSelect.component(selectColor).withSize(size))
                    .child(ColorSelect.component(emptySelectColor)
                        .withSize(size)
                        .placeholder('Pick a color'))));
    }

}
