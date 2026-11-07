// Ported from gpui-kit 0.8.1: crates/story/src/stories/select_story.rs
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
import glaze.Action;
import glaze.AnyElement;
import glaze.DismissEvent;
import glaze.kit.base.IndexPath;
import glaze.kit.base.input.InputState;
import glaze.kit.IconName;
import glaze.kit.button.Button;
import glaze.kit.input.Input;
import glaze.kit.searchablelist.SearchableListItem;
import glaze.kit.searchablelist.SearchableListItem.SearchableListItemBase;
import glaze.kit.searchablelist.SearchableVec.VecDelegate;
import glaze.kit.searchablelist.SearchableVec;
import glaze.kit.select.Select;
import glaze.kit.select.SelectState;
import glaze.kit.separator.Separator;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

@:action(namespace = select_story, noJson) private class ToggleDisabled implements Action {}

private class Country extends SearchableListItemBase {

    public final name:String;

    public final code:String;

    public function new(name:String, code:String) {
        this.name = name;
        this.code = code;
    }

    public function letterPrefix():String {
        final it = new haxe.iterators.StringIteratorUnicode(name);
        return it.hasNext() ? String.fromCharCode(it.next()) : ' ';
    }

    public function title():String {
        return name;
    }

    override public function displayTitle():Null<AnyElement> {
        return (('$name ($code)' : IntoElement)).intoAnyElement();
    }

    public function value():Any {
        return code;
    }

}

class SelectStory extends Model implements Story {

    public static function title():String {
        return 'Select';
    }

    public static function description():String {
        return 'Displays a list of options for the user to pick from\u2014triggered by a button.';
    }

    public static function init(_:App):Void {}

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<SelectStory> {
        return create(window, cx);
    }

    @observe var disabled:Bool = false;

    @observe var size:glaze.kit.Size = glaze.kit.Size.Medium;

    var countrySelect:Entity<SelectState<Country>>;

    var fruitSelect:Entity<SelectState<String>>;

    var simpleSelect1:Entity<SelectState<String>>;

    var simpleSelect2:Entity<SelectState<String>>;

    var simpleSelect3:Entity<SelectState<String>>;

    var menuMaxHSelect:Entity<SelectState<String>>;

    var disabledSelect:Entity<SelectState<String>>;

    var appearanceSelect:Entity<SelectState<String>>;

    var inputState:Entity<InputState>;

    function new() {
        super();
    }

    /** Rust `SelectStory::new`. */
    static function create(window:Window, cx:App):Entity<SelectStory> {
        final countries:Array<{name:String, code:String}> = haxe.Json.parse(story.Include.str('countries.json'));
        final groupedCountries = SearchableVec.groups([]);
        var group:Null<SelectGroup<Country>> = null;
        var groupItems:Array<Country> = [];
        var prefix:Null<String> = null;
        for (c in countries) {
            final country = new Country(c.name, c.code);
            final p = country.letterPrefix();
            if (prefix != p) {
                if (prefix != null) groupedCountries.push(new SelectGroup<Country>(prefix).withItems(groupItems));
                prefix = p;
                groupItems = [];
            }
            groupItems.push(country);
        }
        if (prefix != null) groupedCountries.push(new SelectGroup<Country>(prefix).withItems(groupItems));

        final countrySelect = cx.newEntity((cx:Context<SelectState<Country>>) -> new SelectState<Country>(groupedCountries,
            new IndexPath().withRow(8).withSection(2), window, cx).searchable(true));
        final appearanceSelect = cx.newEntity((cx:Context<SelectState<String>>) -> new SelectState<String>(new VecDelegate(['CN', 'US', 'HK', 'JP', 'KR']),
            new IndexPath(), window, cx));
        final inputState = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).withPlaceholder('Your phone number'));
        final fruits = new SearchableVec([
            'Apple',
            'Orange',
            'Banana',
            'Grape',
            'Pineapple',
            'Watermelon & This is a long long long long long long long long long title',
            'Avocado',
        ]);
        final fruitSelect = cx.newEntity((cx:Context<SelectState<String>>) -> new SelectState<String>(fruits, null, window, cx).searchable(true));

        return cx.newEntity((cx:Context<SelectStory>) -> {
            cx.subscribeIn(countrySelect, SelectEvent, window, (this_, _, event, _, _) -> onSelectEvent(event)).detach();
            cx.subscribe(countrySelect, DismissEvent, (_, _, _, _) -> trace('Country select dismissed')).detach();
            final story = new SelectStory();
            story.countrySelect = countrySelect;
            story.fruitSelect = fruitSelect;
            story.simpleSelect1 = cx.newEntity((cx:Context<SelectState<String>>) -> new SelectState<String>(new VecDelegate([
                'GPUI', 'Iced', 'egui', 'Makepad', 'Slint', 'QT', 'ImGui', 'Cocoa', 'WinUI',
            ]), new IndexPath(), window, cx));
            story.simpleSelect2 = cx.newEntity((cx:Context<SelectState<String>>) -> {
                final select = new SelectState<String>(new SearchableVec<String>([]), null, window, cx).searchable(true);
                select.setItems(new SearchableVec(['Rust', 'Go', 'C++', 'JavaScript']), window, cx);
                return select;
            });
            story.simpleSelect3 = cx.newEntity((cx:Context<SelectState<String>>) -> new SelectState<String>(new VecDelegate<String>([]), null, window, cx));
            story.menuMaxHSelect = cx.newEntity((cx:Context<SelectState<String>>) -> new SelectState<String>(new VecDelegate([
                'GPUI', 'Iced', 'egui', 'Makepad', 'Slint', 'QT', 'ImGui', 'Cocoa', 'WinUI',
            ]), new IndexPath(), window, cx));
            story.disabledSelect = cx.newEntity((cx:Context<SelectState<String>>) -> new SelectState<String>(new VecDelegate<String>([]), null, window, cx));
            story.appearanceSelect = appearanceSelect;
            story.inputState = inputState;
            return story;
        });
    }

    static function onSelectEvent(event:SelectEvent):Void {
        switch event {
            case Confirm(value):
                trace('Selected country: ${debugOption(value)}');
        }
    }

    /** Rust `{:?}` of an `Option<SharedString>`. */
    static function debugOption(value:Null<Any>):String {
        return value == null ? 'None' : 'Some(${haxe.Json.stringify(Std.string(value))})';
    }

    public function focusHandle(cx:App):FocusHandle {
        return fruitSelect.read(cx).focusHandle(cx);
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final disabled = this.disabled;
        return vFlex()
            .sizeFull()
            .itemsCenter()
            .gap4()
            .onAction(ChangeStorySize, (action, _, _) -> size = action.value)
            .onAction(ToggleDisabled, (_, _, _) -> this.disabled = !this.disabled)
            .child(storyToolbar(size).dropdownChild(new Button('select-options').label('Options'),
                (menu, _, _) -> menu.menuWithCheck('Disabled', disabled, new ToggleDisabled())))
            .child(section('Search and clear')
                .description('Search options and clear the value.')
                .w(px(280.))
                .itemsCenter()
                .child(new Select(countrySelect)
                    .w(px(280.))
                    .withSize(size)
                    .searchPlaceholder('Search…')
                    .cleanable(true)
                    .disabled(disabled)))
            .child(section('Menu width')
                .description('Set trigger and menu widths independently.')
                .w(px(280.))
                .itemsCenter()
                .child(new Select(fruitSelect)
                    .withSize(size)
                    .disabled(disabled)
                    .icon(IconName.Search)
                    .w(px(280.))
                    .menuWidth(px(400.))))
            .child(section('Disabled')
                .description('Keep the selected value visible.')
                .w(px(280.))
                .itemsCenter()
                .child(new Select(disabledSelect)
                    .w(px(280.))
                    .withSize(size)
                    .disabled(true)))
            .child(section('Title prefix')
                .description('Prefix the selected value.')
                .w(px(280.))
                .itemsCenter()
                .child(new Select(simpleSelect1)
                    .w(px(280.))
                    .withSize(size)
                    .disabled(disabled)
                    .placeholder('UI')
                    .titlePrefix('UI: ')))
            .child(section('Menu height')
                .description('Limit the popup height.')
                .w(px(280.))
                .itemsCenter()
                .child(new Select(menuMaxHSelect)
                    .w(px(280.))
                    .withSize(size)
                    .disabled(disabled)
                    .placeholder('UI')
                    .titlePrefix('UI: ')
                    .menuMaxH(rems(6.))))
            .child(section('Search')
                .description('Filter options from the popup.')
                .w(px(280.))
                .itemsCenter()
                .child(new Select(simpleSelect2)
                    .accessibilityLabel('Programming language')
                    .w(px(280.))
                    .withSize(size)
                    .disabled(disabled)
                    .placeholder('Language')
                    .titlePrefix('Language: ')))
            .child(section('Empty')
                .description('Render a custom empty state.')
                .w(px(280.))
                .itemsCenter()
                .child(new Select(simpleSelect3)
                    .w(px(280.))
                    .withSize(size)
                    .disabled(disabled)
                    .empty((_, cx) -> hFlex()
                        .h24()
                        .justifyCenter()
                        .textColor(Theme.global(cx).mutedForeground)
                        .child('No Data'))))
            .child(section('Custom appearance')
                .description('Compose an appearance-free select with another control.')
                .w(px(280.))
                .itemsCenter()
                .child(hFlex()
                    .border1()
                    .borderColor(theme.input)
                    .rounded(theme.radiusLg)
                    .textColor(theme.secondaryForeground)
                    .w(px(280.))
                    .gap1()
                    .child(div().w(px(140.)).child(new Select(appearanceSelect)
                        .withSize(size)
                        .appearance(false)
                        .py2()
                        .pl3()))
                    .child(Separator.vertical())
                    .child(div().flex1().child(new Input(inputState)
                        .appearance(false)
                        .pr3()
                        .py2()))
                    .child(div().p2().child(new Button('send')
                        .withSize(size)
                        .ghost()
                        .label('Send')))))
            .child(section('Values')
                .description('Read selected values from state.')
                .w128()
                .child(vFlex()
                    .gap3()
                    .child('Country: ${debugOption(countrySelect.read(cx.app).selectedValue())}')
                    .child('fruit: ${debugOption(fruitSelect.read(cx.app).selectedValue())}')
                    .child('UI: ${debugOption(simpleSelect1.read(cx.app).selectedValue())}')
                    .child('Language: ${debugOption(simpleSelect2.read(cx.app).selectedValue())}')
                    .child('This is other text.')));
    }

}
