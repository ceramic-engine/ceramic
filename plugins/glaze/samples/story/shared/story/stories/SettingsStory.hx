// Ported from gpui-kit 0.8.1: crates/story/src/stories/settings_story.rs
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
import glaze.AnyElement;
import glaze.Axis;
import glaze.Pixels;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Size;
import glaze.kit.button.Button;
import glaze.kit.groupbox.GroupBox.GroupBoxVariant;
import glaze.kit.label.Label;
import glaze.kit.setting.ElementField.SettingFieldElement;
import glaze.kit.setting.NumberField.NumberFieldOptions;
import glaze.kit.setting.RenderOptions;
import glaze.kit.setting.SettingField;
import glaze.kit.setting.SettingGroup;
import glaze.kit.setting.SettingItem;
import glaze.kit.setting.SettingPage;
import glaze.kit.setting.Settings;
import glaze.kit.text.TextView;
import glaze.kit.theme.Theme;
import glaze.kit.theme.ThemeMode;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

private class AppSettings {

    public var autoSwitchTheme:Bool = false;

    public var cliPath:String = '/usr/local/bin/bash';

    public var fontFamily:String = 'Arial';

    public var fontSize:Float = 14.0;

    public var lineHeight:Float = 12.0;

    /**
     * Demonstrates a custom element field driving its own state, with reset
     * support wired up via `SettingField.onReset`.
     */
    public var density:String = 'Comfortable';

    public var notificationsEnabled:Bool = true;

    public var autoUpdate:Bool = true;

    public var resettable:Bool = true;

    public var disabled:Bool = false;

    public function new() {}

    public static function global(cx:App):AppSettings {
        return cx.global(AppSettings);
    }

    public static function globalMut(cx:App):AppSettings {
        return cx.globalMut(AppSettings);
    }

}

private class OpenURLSettingField implements SettingFieldElement {

    final label:String;

    final url:String;

    public function new(label:String, url:String) {
        this.label = label;
        this.url = url;
    }

    public function renderField(options:RenderOptions, _:Window, _:App):AnyElement {
        final url = this.url;
        return (Button.component('open-url')
            .outline()
            .label(label)
            .withSize(options.size())
            .onClick((_, _, cx) -> cx.openUrl(url)) : IntoElement).intoAnyElement();
    }

}

class SettingsStory extends Model implements Story {

    public static function title():String {
        return 'Settings';
    }

    public static function description():String {
        return 'A collection of settings groups and items for the application.';
    }

    public static function paddings():Pixels {
        return px(0.);
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<SettingsStory> {
        return cx.newEntity((c:Context<SettingsStory>) -> new SettingsStory(window, c));
    }

    final focusHandle_:FocusHandle;

    @observe var groupVariant:GroupBoxVariant = GroupBoxVariant.Outline;

    @observe var size:Size = glaze.kit.Size.Medium;

    function new(_:Window, cx:Context<SettingsStory>) {
        super();
        cx.app.setGlobal(new AppSettings());
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    function settingPages(_:Window, cx:Context<Dynamic>):Array<SettingPage> {
        final view:Entity<SettingsStory> = cast cx.entity();
        final defaultSettings = new AppSettings();
        final resettable = AppSettings.global(cx.app).resettable;
        final disabled = AppSettings.global(cx.app).disabled;
        return [
            new SettingPage('General')
                .resettable(resettable)
                .defaultOpen(true)
                .icon(Icon.component(IconName.Settings2))
                .titleSuffix((_, _) -> Button.component('help')
                    .icon(IconName.Info)
                    .ghost()
                    .xsmall()
                    .onClick((_, _, cx) -> cx.openUrl('https://gpui-kit.com/')))
                .groups([
                    new SettingGroup().title('Appearance').items([
                        SettingItem.create('Dark Mode', SettingField.switch_(
                            cx -> Theme.global(cx).mode.isDark(),
                            (val, cx) -> Theme.setMode(val ? ThemeMode.Dark : ThemeMode.Light, cx)
                        ).defaultValue(false))
                            .description('Switch between light and dark themes.')
                            .disabled(disabled),
                        SettingItem.create('Auto Switch Theme', SettingField.checkbox(
                            cx -> AppSettings.global(cx).autoSwitchTheme,
                            (val, cx) -> AppSettings.globalMut(cx).autoSwitchTheme = val
                        ).defaultValue(defaultSettings.autoSwitchTheme))
                            .description('Automatically switch theme based on system settings.')
                            .disabled(disabled),
                        SettingItem.create('resettable', SettingField.switch_(
                            cx -> AppSettings.global(cx).resettable,
                            (checked, cx) -> AppSettings.globalMut(cx).resettable = checked
                        ))
                            .description('Enable/Disable reset button for settings.')
                            .disabled(disabled),
                        SettingItem.create('Group Variant', SettingField.dropdown([
                            {value: GroupBoxVariant.Normal.asStr(), label: 'Normal'},
                            {value: GroupBoxVariant.Outline.asStr(), label: 'Outline'},
                            {value: GroupBoxVariant.Fill.asStr(), label: 'Fill'},
                        ],
                            cx -> view.read(cx).groupVariant.asStr(),
                            (val, cx) -> view.update(cx, (view, _) -> view.groupVariant = GroupBoxVariant.fromStr(val))
                        ).defaultValue(GroupBoxVariant.Outline.asStr()))
                            .description('Select the variant for setting groups.')
                            .disabled(disabled),
                        SettingItem.create('Group Size', SettingField.dropdown([
                            {value: glaze.kit.Size.Medium.asStr(), label: 'Medium'},
                            {value: glaze.kit.Size.Small.asStr(), label: 'Small'},
                            {value: glaze.kit.Size.XSmall.asStr(), label: 'XSmall'},
                        ],
                            cx -> view.read(cx).size.asStr(),
                            (val, cx) -> view.update(cx, (view, _) -> view.size = glaze.kit.Size.SizeTools.fromStr(val))
                        ).defaultValue(glaze.kit.Size.Medium.asStr()))
                            .description('Select the size for the setting group.')
                            .disabled(disabled),
                    ]),
                    new SettingGroup()
                        .title('Font')
                        .footer((_, _) -> 'Font preferences apply to this story only.')
                        .item(SettingItem.create('Font Family', SettingField.dropdown([
                            {value: 'Arial', label: 'Arial'},
                            {value: 'Helvetica', label: 'Helvetica'},
                            {value: 'Times New Roman', label: 'Times New Roman'},
                            {value: 'Courier New', label: 'Courier New'},
                        ],
                            cx -> AppSettings.global(cx).fontFamily,
                            (val, cx) -> AppSettings.globalMut(cx).fontFamily = val
                        ).defaultValue(defaultSettings.fontFamily))
                            .description('Select the font family for the story.')
                            .disabled(disabled))
                        .item(SettingItem.create('Font Size', SettingField.numberInput(new NumberFieldOptions(8.0, 72.0),
                            cx -> AppSettings.global(cx).fontSize,
                            (val, cx) -> AppSettings.globalMut(cx).fontSize = val
                        ).defaultValue(defaultSettings.fontSize))
                            .description('Adjust the font size for better readability between 8 and 72.')
                            .disabled(disabled))
                        .item(SettingItem.create('Line Height', SettingField.numberInput(new NumberFieldOptions(8.0, 32.0),
                            cx -> AppSettings.global(cx).lineHeight,
                            (val, cx) -> AppSettings.globalMut(cx).lineHeight = val
                        ).defaultValue(defaultSettings.lineHeight))
                            .description('Adjust the line height for better readability between 8 and 32.')
                            .disabled(disabled)),
                    new SettingGroup().title('Other').items([
                        SettingItem.create('Disable Settings', SettingField.switch_(
                            cx -> AppSettings.global(cx).disabled,
                            (checked, cx) -> AppSettings.globalMut(cx).disabled = checked
                        ).defaultValue(false))
                            .description('Lock the other settings.'),
                        SettingItem.create('Foo', SettingField.switch_(
                            cx -> AppSettings.global(cx).disabled,
                            (checked, cx) -> AppSettings.globalMut(cx).disabled = checked
                        ).defaultValue(false))
                            .description('Find me by searching for my sibling')
                            .keywords(['Bar']),
                        SettingItem.render((options, _, _) -> hFlex()
                            .wFull()
                            .justifyBetween()
                            .flexWrap()
                            .gap3()
                            .child('View source, report issues, and follow project updates.')
                            .when(options.isDisabled(), this_ -> this_.opacity(0.5))
                            .child(Button.component('action')
                                .icon(IconName.Globe)
                                .label('Repository...')
                                .outline()
                                .withSize(options.size())
                                .disabled(options.isDisabled())
                                .onClick((_, _, cx) -> cx.openUrl('https://github.com/longbridge/gpui-kit'))))
                            .disabled(disabled),
                        SettingItem.create('Density', SettingField.render((options, _, cx) -> {
                            final current = AppSettings.global(cx).density;
                            return hFlex()
                                .gap1()
                                .children([for (value in ['Comfortable', 'Compact']) {
                                    final button = Button.component(value).label(value).withSize(options.size());
                                    (current == value ? button.primary() : button.outline())
                                        .onClick((_, _, cx) -> AppSettings.globalMut(cx).density = value);
                                }]);
                        })
                            // A custom element field manages its own state, so reset
                            // support must be wired up explicitly via `onReset`.
                            .onReset(cx -> AppSettings.global(cx).density != defaultSettings.density,
                                (_, cx) -> AppSettings.globalMut(cx).density = defaultSettings.density))
                            .description('A custom element field with reset support via `on_reset`.')
                            .disabled(disabled),
                        SettingItem.create('CLI Path', SettingField.input(
                            cx -> AppSettings.global(cx).cliPath,
                            (val, cx) -> {
                                trace('cli-path set value: $val');
                                AppSettings.globalMut(cx).cliPath = val;
                            }
                        ).defaultValue(defaultSettings.cliPath))
                            .layout(Axis.Vertical)
                            .description('Path to the CLI executable. \nThis item uses Vertical layout. The title,description, and field are all aligned vertically with width 100%.')
                            .disabled(disabled),
                    ]),
                ]),
            new SettingPage('Software Update')
                .resettable(resettable)
                .icon(Icon.component(IconName.Cpu))
                .groups([new SettingGroup().title('Updates').items([
                    SettingItem.create('Enable Notifications', SettingField.switch_(
                        cx -> AppSettings.global(cx).notificationsEnabled,
                        (val, cx) -> AppSettings.globalMut(cx).notificationsEnabled = val
                    ).defaultValue(defaultSettings.notificationsEnabled))
                        .description('Receive notifications about updates and news.')
                        .disabled(disabled),
                    SettingItem.create('Auto Update', SettingField.switch_(
                        cx -> AppSettings.global(cx).autoUpdate,
                        (val, cx) -> AppSettings.globalMut(cx).autoUpdate = val
                    ).defaultValue(defaultSettings.autoUpdate))
                        .description('Automatically download and install updates.')
                        .disabled(disabled),
                ])]),
            new SettingPage('About')
                .resettable(resettable)
                .icon(Icon.component(IconName.Info))
                .group(new SettingGroup().item(SettingItem.render((_, _, cx) -> vFlex()
                    .gap3()
                    .wFull()
                    .itemsCenter()
                    .justifyCenter()
                    .child(Icon.component(IconName.GalleryVerticalEnd).size16())
                    .child('GPUI Component')
                    .child(Label.component('Rust GUI components for building fantastic cross-platform desktop application by using GPUI.')
                        .textSm()
                        .textColor(Theme.global(cx).mutedForeground)))))
                .group(new SettingGroup().title('Links').items([
                    SettingItem.create('GitHub Repository', SettingField.element(new OpenURLSettingField('Repository...', 'https://github.com/longbridge/gpui-kit')))
                        .description('Open the GitHub repository in your default browser.'),
                    SettingItem.create('Documentation', SettingField.element(new OpenURLSettingField('Rust Docs...', 'https://docs.rs/gpui-component')))
                        .description(TextView.markdownAt('Rust doc for the `gpui-component` crate.')),
                    SettingItem.create('Website', SettingField.render((options, _, _) -> Button.component('open-url')
                        .outline()
                        .label('Website...')
                        .withSize(options.size())
                        .onClick((_, _, cx) -> cx.openUrl('https://gpui-kit.com/'))))
                        .description('Official website and documentation for the GPUI Component.'),
                ])),
        ];
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return Settings.component('app-settings')
            .withSize(size)
            .withGroupVariant(groupVariant)
            .pages(settingPages(window, cx));
    }

}
