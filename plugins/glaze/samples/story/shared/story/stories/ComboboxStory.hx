// Ported from gpui-kit 0.8.1: crates/story/src/stories/combobox_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import gpui.AnyElement;
import gpui.AnyView;
import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Model;
import gpui.Window;
import gpui.base.IndexPath;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.button.Button;
import gpui.component.combobox.Combobox;
import gpui.component.combobox.ComboboxState;
import gpui.component.searchablelist.SearchableListChange;
import gpui.component.searchablelist.SearchableListDelegate.SearchableListDelegateBase;
import gpui.component.searchablelist.SearchableListItem.SearchableListItemBase;
import gpui.component.searchablelist.SearchableVec;
import gpui.component.searchablelist.SearchableVec.SearchableGroup;
import gpui.component.searchablelist.SelectedItem;
import gpui.component.select.Caret;
import gpui.component.theme.Theme;
import story.Story;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Lib.*;

using gpui.base.StyledExt;
using gpui.component.ThemeStyled;

// MARK: Data

private class FoodItem extends SearchableListItemBase {

    public final label:String;

    public var isDisabled:Bool = false;

    public function new(label:String) {
        this.label = label;
    }

    public function withDisabled():FoodItem {
        isDisabled = true;
        return this;
    }

    public function title():String {
        return label;
    }

    public function value():Any {
        return label;
    }

    override public function disabled():Bool {
        return isDisabled;
    }

}

private class Industry extends SearchableListItemBase {

    public final label:String;

    public final icon:IconName;

    public function new(label:String, icon:IconName) {
        this.label = label;
        this.icon = icon;
    }

    public function title():String {
        return label;
    }

    public function value():Any {
        return label;
    }

    override public function render(_window:Window, cx:App):IntoElement {
        return hFlex()
            .wFull()
            .gap2()
            .itemsCenter()
            .child(new Icon(icon)
                .small()
                .textColor(Theme.global(cx).mutedForeground))
            .child(div().child(label));
    }

}

// MARK: Max2Delegate: allows at most 2 items to be selected simultaneously

/**
 * Shadows the current selection indices so `isItemEnabled` can disable
 * unselected items when the capacity is reached, providing visual feedback
 * without `currentSelection` access.
 */
private class Max2Delegate<I> extends SearchableListDelegateBase<I> {

    // Generic over the item type (used with String): on C#, Haxe cannot override the
    // base `item(ix):Null<I>` with a concrete `Null<String>` (the output does not compile).

    final items:SearchableVec<I>;

    var selectedIndices:Array<IndexPath> = [];

    public function new(items:SearchableVec<I>) {
        this.items = items;
    }

    public function itemsCount(section:Int):Int {
        return items.itemsCount(section);
    }

    public function item(ix:IndexPath):Null<I> {
        return items.item(ix);
    }

    public function position(value:Any):Null<IndexPath> {
        return items.position(value);
    }

    override public function isItemEnabled(ix:IndexPath, _item:I, _cx:App):Bool {
        final atCapacity = selectedIndices.length >= 2;
        final isSelected = Lambda.exists(selectedIndices, i -> i.equals(ix));
        return !atCapacity || isSelected;
    }

    override public function onWillChange(selection:Array<SelectedItem<I>>, changes:Array<SearchableListChange>):Void {
        for (change in changes) {
            switch change {
                case Deselect(index):
                    var i = selection.length;
                    while (i-- > 0) {
                        if (selection[i].index.equals(index)) selection.splice(i, 1);
                    }
                case Select(index):
                    if (selection.length < 2) {
                        final item = item(index);
                        if (item != null) {
                            if (!Lambda.exists(selection, s -> s.index.equals(index))) {
                                selection.push(new SelectedItem(index, item));
                            }
                        }
                    }
            }
        }

        // Keep the shadow in sync for isItemEnabled.
        selectedIndices = [for (s in selection) s.index];
    }

}

// MARK: PinnedDelegate: first two items always appear checked regardless of selection

private class PinnedDelegate<I> extends SearchableListDelegateBase<I> {

    final items:SearchableVec<I>;

    public function new(items:SearchableVec<I>) {
        this.items = items;
    }

    public function itemsCount(section:Int):Int {
        return items.itemsCount(section);
    }

    public function item(ix:IndexPath):Null<I> {
        return items.item(ix);
    }

    public function position(value:Any):Null<IndexPath> {
        return items.position(value);
    }

    override public function isItemEnabled(ix:IndexPath, _item:I, _cx:App):Bool {
        // Pinned items are non-interactive: their checked state is fixed.
        return !ix.equals(new IndexPath(0)) && !ix.equals(new IndexPath(1));
    }

    override public function isItemChecked(ix:IndexPath, _item:I, currentSelection:Array<SelectedItem<I>>, _cx:App):Bool {
        // First two items are always rendered checked (externally pinned),
        // regardless of what is in the normal selection.
        return ix.equals(new IndexPath(0)) || ix.equals(new IndexPath(1)) || Lambda.exists(currentSelection, s -> s.index.equals(ix));
    }

}

// MARK: FeaturedDelegate: first item gets a "Featured" badge via renderItem

private class FeaturedDelegate<I> extends SearchableListDelegateBase<I> {

    final items:SearchableVec<I>;

    public function new(items:SearchableVec<I>) {
        this.items = items;
    }

    public function itemsCount(section:Int):Int {
        return items.itemsCount(section);
    }

    public function item(ix:IndexPath):Null<I> {
        return items.item(ix);
    }

    public function position(value:Any):Null<IndexPath> {
        return items.position(value);
    }

    override public function renderItem(ix:IndexPath, item:I, checked:Bool, _window:Window, cx:App):Null<AnyElement> {
        if (!ix.equals(new IndexPath(0))) {
            return null;
        }

        final theme = Theme.global(cx);
        final row = hFlex()
            .wFull()
            .justifyBetween()
            .itemsCenter()
            .child(Std.string(item));
        if (checked) {
            row.child(new Icon(IconName.Check)
                .xsmall()
                .textColor(theme.mutedForeground));
        }
        return row.child(div()
            .rounded(theme.radius.half())
            .bg(theme.primary)
            .textColor(theme.primaryForeground)
            .px1()
            .textXs()
            .child('Featured'))
            .intoAnyElement();
    }

}

// MARK: Story

class ComboboxStory extends Model implements Story {

    // 01 basic single-select
    var basic:Entity<ComboboxState<String>>;
    // 02 basic multi-select
    var basicMulti:Entity<ComboboxState<String>>;
    // 03 grouped single-select
    var grouped:Entity<ComboboxState<FoodItem>>;
    // 03 disabled items (single)
    var disabledItems:Entity<ComboboxState<FoodItem>>;
    // 04 item icon (single)
    var withIcon:Entity<ComboboxState<Industry>>;
    // 05 custom check icon (single)
    var customCheck:Entity<ComboboxState<String>>;
    // 06 footer button (single)
    var withFooter:Entity<ComboboxState<String>>;
    // 07 custom trigger (single)
    var customTrigger:Entity<ComboboxState<String>>;
    // 08 multi badges
    var multiBadges:Entity<ComboboxState<String>>;
    // 09 onWillChange: max 2 items
    var customMax2:Entity<ComboboxState<String>>;
    // 10 isItemChecked: externally pinned items
    var pinned:Entity<ComboboxState<String>>;
    // 11 renderItem delegate hook: custom row renderer
    var featured:Entity<ComboboxState<String>>;
    // 12 multi expandable
    var multiExpand:Entity<ComboboxState<String>>;
    // 12 multi count-badge
    var multiCount:Entity<ComboboxState<String>>;

    static final FRAMEWORKS:Array<String> = ['Next.js', 'SvelteKit', 'Nuxt.js', 'Remix', 'Astro'];

    static final MULTI_FRAMEWORKS:Array<String> = [
        'React', 'Nextjs', 'Angular', 'VueJS', 'Django', 'Astro', 'Remix', 'Svelte', 'SolidJS', 'Qwik',
    ];

    public static function init(_:App):Void {}

    public static function title():String {
        return 'Combobox';
    }

    public static function description():String {
        return 'An autocomplete input paired with a searchable dropdown list.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<ComboboxStory> {
        return create(window, cx);
    }

    function new() {
        super();
    }

    public function focusHandle(cx:App):FocusHandle {
        return basic.read(cx).focusHandle(cx);
    }

    static function foodGroups() {
        return SearchableVec.groups([
            new SearchableGroup<FoodItem>('Fruits').withItems([
                new FoodItem('Apples'),
                new FoodItem('Bananas'),
                new FoodItem('Cherries'),
            ]),
            new SearchableGroup<FoodItem>('Vegetables').withItems([
                new FoodItem('Carrots'),
                new FoodItem('Broccoli').withDisabled(),
                new FoodItem('Spinach'),
            ]),
            new SearchableGroup<FoodItem>('Beverages').withItems([
                new FoodItem('Tea'),
                new FoodItem('Coffee').withDisabled(),
                new FoodItem('Juice'),
            ]),
        ]);
    }

    static function industries():SearchableVec<Industry> {
        return new SearchableVec([
            new Industry('Information Technology', IconName.Cpu),
            new Industry('Healthcare', IconName.Heart),
            new Industry('Finance', IconName.Globe),
            new Industry('Education', IconName.BookOpen),
            new Industry('Entertainment', IconName.Star),
        ]);
    }

    static function rows(rows:Array<Int>):Array<IndexPath> {
        return [for (row in rows) new IndexPath(row)];
    }

    /** Rust `ComboboxStory::new`. */
    static function create(window:Window, cx:App):Entity<ComboboxStory> {
        final basic = cx.newEntity((cx:Context<ComboboxState<String>>) -> new ComboboxState<String>(new SearchableVec(FRAMEWORKS), [], window, cx)
            .searchable(true));

        final basicMulti = cx.newEntity((cx:Context<ComboboxState<String>>) -> new ComboboxState<String>(new SearchableVec(FRAMEWORKS), [], window, cx)
            .multiple(true)
            .searchable(true));

        final grouped = cx.newEntity((cx:Context<ComboboxState<FoodItem>>) -> new ComboboxState<FoodItem>(foodGroups(), [IndexPath.defaultValue()], window, cx)
            .searchable(true));

        final disabledItems = cx.newEntity((cx:Context<ComboboxState<FoodItem>>) -> {
            final items = new SearchableVec([
                new FoodItem('Apples'),
                new FoodItem('Bananas').withDisabled(),
                new FoodItem('Cherries'),
                new FoodItem('Carrots'),
                new FoodItem('Broccoli').withDisabled(),
            ]);
            return new ComboboxState<FoodItem>(items, [], window, cx).searchable(true);
        });

        final withIcon = cx.newEntity((cx:Context<ComboboxState<Industry>>) -> new ComboboxState<Industry>(industries(), [], window, cx).searchable(true));

        final customCheck = cx.newEntity((cx:Context<ComboboxState<String>>) -> new ComboboxState<String>(new SearchableVec(FRAMEWORKS), [], window, cx)
            .searchable(true));

        final withFooter = cx.newEntity((cx:Context<ComboboxState<String>>) -> {
            final items = new SearchableVec(['Harvard University', 'MIT', 'Stanford', 'Cambridge']);
            return new ComboboxState<String>(items, [IndexPath.defaultValue()], window, cx).searchable(true);
        });

        final customTrigger = cx.newEntity((cx:Context<ComboboxState<String>>) -> new ComboboxState<String>(new SearchableVec(FRAMEWORKS), [], window, cx)
            .searchable(true));

        final multiBadges = cx.newEntity((cx:Context<ComboboxState<String>>) -> new ComboboxState<String>(new SearchableVec(MULTI_FRAMEWORKS),
            rows([0, 2]), window, cx)
            .multiple(true)
            .searchable(true));

        final customMax2 = cx.newEntity((cx:Context<ComboboxState<String>>) -> new ComboboxState<String>(new Max2Delegate(new SearchableVec(MULTI_FRAMEWORKS)),
            [], window, cx)
            .multiple(true)
            .searchable(true));

        final pinned = cx.newEntity((cx:Context<ComboboxState<String>>) -> new ComboboxState<String>(new PinnedDelegate(new SearchableVec(FRAMEWORKS)), [],
            window, cx)
            .searchable(true));

        final featured = cx.newEntity((cx:Context<ComboboxState<String>>) -> new ComboboxState<String>(new FeaturedDelegate(new SearchableVec(FRAMEWORKS)),
            [], window, cx)
            .searchable(true));

        final multiExpand = cx.newEntity((cx:Context<ComboboxState<String>>) -> new ComboboxState<String>(new SearchableVec(MULTI_FRAMEWORKS),
            rows([0, 2, 5, 8, 9]), window, cx)
            .multiple(true)
            .searchable(true));

        final multiCount = cx.newEntity((cx:Context<ComboboxState<String>>) -> new ComboboxState<String>(new SearchableVec(MULTI_FRAMEWORKS),
            rows([0, 1, 2, 3, 4, 5]), window, cx)
            .multiple(true)
            .searchable(true));

        return cx.newEntity((_:Context<ComboboxStory>) -> {
            final story = new ComboboxStory();
            story.basic = basic;
            story.basicMulti = basicMulti;
            story.grouped = grouped;
            story.disabledItems = disabledItems;
            story.withIcon = withIcon;
            story.customCheck = customCheck;
            story.withFooter = withFooter;
            story.customTrigger = customTrigger;
            story.multiBadges = multiBadges;
            story.customMax2 = customMax2;
            story.pinned = pinned;
            story.featured = featured;
            story.multiExpand = multiExpand;
            story.multiCount = multiCount;
            return story;
        });
    }

    /** Rust `{:?}` of a `Vec` of strings. */
    static function debugList(values:Array<Any>):String {
        return '[' + [for (v in values) haxe.Json.stringify(Std.string(v))].join(', ') + ']';
    }

    public function render(_window:Window, cx:Context<Dynamic>):IntoElement {
        final multiBadgesState = multiBadges;
        final withFooterState = withFooter;

        return vFlex()
            .sizeFull()
            .itemsCenter()
            .gap4()
            .child(section('Default')
                .w(px(280.))
                .description('Search and choose one option.')
                .child(new Combobox(basic)
                    .placeholder('Select framework...')
                    .searchPlaceholder('Search…')
                    .w(px(280.))))
            .child(section('Multiple')
                .w(px(280.))
                .description('Select more than one option.')
                .child(new Combobox(basicMulti)
                    .placeholder('Select frameworks...')
                    .searchPlaceholder('Search…')
                    .w(px(280.))))
            .child(section('Groups')
                .w(px(280.))
                .description('Organize results into groups.')
                .child(new Combobox(grouped)
                    .placeholder('Select item...')
                    .searchPlaceholder('Search…')
                    .w(px(280.))))
            .child(section('Disabled items')
                .w(px(280.))
                .description('Keep unavailable options visible.')
                .child(new Combobox(disabledItems)
                    .placeholder('Select item...')
                    .searchPlaceholder('Search…')
                    .w(px(280.))))
            .child(section('Icons')
                .w(px(280.))
                .description('Show icons in options and the trigger.')
                .child(new Combobox(withIcon)
                    .placeholder('Select industry category')
                    .searchPlaceholder('Search…')
                    .renderTrigger((trigger, _, cx) -> {
                        final theme = Theme.global(cx);
                        final selection = trigger.selection();
                        var icon:Null<IconName> = null;
                        var title:Null<String> = null;
                        if (selection.length == 1) {
                            icon = selection[0].item.icon;
                            title = selection[0].item.title();
                        } else if (selection.length > 1) {
                            title = '${selection.length} selected';
                        }

                        final row = hFlex()
                            .wFull()
                            .gap2()
                            .itemsCenter();
                        if (icon != null) {
                            row.child(new Icon(icon)
                                .small()
                                .textColor(theme.mutedForeground));
                        }
                        final label = div()
                            .wFull()
                            .overflowHidden()
                            .truncate();
                        if (title != null) label.child(title);
                        if (trigger.selection().length == 0) {
                            label.textColor(theme.mutedForeground)
                                .child('Select industry category');
                        }
                        return row
                            .child(label)
                            .child(new Caret(trigger.size())
                                .textColor(theme.mutedForeground))
                            .intoAnyElement();
                    })
                    .w(px(280.))))
            .child(section('Check icon')
                .w(px(280.))
                .description('Replace the default selection mark.')
                .child(new Combobox(customCheck)
                    .placeholder('Select framework...')
                    .searchPlaceholder('Search…')
                    .checkIcon(new Icon(IconName.CircleCheck))
                    .w(px(280.))))
            .child(section('Footer')
                .w(px(280.))
                .description('Add an action below the option list.')
                .child({
                    final state = withFooterState;
                    new Combobox(withFooter)
                        .placeholder('Select university')
                        .searchPlaceholder('Search…')
                        .footer((_, cx) -> {
                            new Button('add-new')
                                .ghost()
                                .label('New university')
                                .icon(new Icon(IconName.Plus))
                                .textColor(Theme.global(cx).foreground)
                                .wFull()
                                .justifyStart()
                                .onClick((_, window, cx) -> {
                                    final searchQuery = state.read(cx).query(cx);
                                    final items = new SearchableVec([
                                        'Harvard University',
                                        'MIT',
                                        'Stanford',
                                        'Cambridge',
                                        searchQuery,
                                    ]);

                                    items.performSearch(searchQuery, window, cx);

                                    state.update(cx, (state, cx) -> {
                                        state.setItems(items, window, cx);
                                    });
                                });
                        })
                        .w(px(280.));
                }))
            .child(section('Custom trigger')
                .w(px(280.))
                .description('Render custom trigger content.')
                .child(new Combobox(customTrigger)
                    .placeholder('Select framework')
                    .searchPlaceholder('Search…')
                    .renderTrigger((trigger, _, cx) -> {
                        final theme = Theme.global(cx);
                        final selection = trigger.selection();
                        final title:Null<String> = switch selection.length {
                            case 0: null;
                            case 1: SearchableListItems_title(selection[0].item);
                            case n: '$n selected';
                        }

                        final inner = hFlex()
                            .itemsCenter()
                            .gap2()
                            .child(new Icon(IconName.Palette)
                                .small()
                                .textColor(theme.primary));
                        if (title != null) {
                            inner.child(div()
                                .bg(theme.primary)
                                .textColor(theme.primaryForeground)
                                .roundedFullStyle(cx)
                                .px2()
                                .py0p5()
                                .textXs()
                                .child(title));
                        }
                        if (trigger.selection().length == 0) {
                            final placeholder = trigger.placeholder();
                            inner.textColor(theme.mutedForeground).child(placeholder != null ? placeholder : 'Select...');
                        }

                        return hFlex()
                            .wFull()
                            .itemsCenter()
                            .justifyBetween()
                            .gap2()
                            .child(inner)
                            .child(new Caret(trigger.size())
                                .textColor(theme.mutedForeground))
                            .intoAnyElement();
                    })
                    .w(px(280.))))
            .child(section('Badges')
                .w(px(280.))
                .description('Show removable selected badges.')
                .child(new Combobox(multiBadges)
                    .placeholder('Select frameworks')
                    .searchPlaceholder('Search…')
                    .renderTrigger((trigger, _, cx) -> {
                        final theme = Theme.global(cx);
                        final items = trigger.selection();

                        if (items.length == 0) {
                            return div()
                                .textColor(theme.mutedForeground)
                                .child('Select frameworks')
                                .intoAnyElement();
                        }

                        final hidden = items.length - 1;
                        final badges = hFlex()
                            .minW0()
                            .itemsCenter()
                            .gap1()
                            .children([for (selected in items.slice(0, 1)) {
                                final index = selected.index;
                                final item = selected.item;
                                final state = multiBadgesState;
                                hFlex()
                                    .minW0()
                                    .gap0p5()
                                    .itemsCenter()
                                    .rounded(theme.radius.half())
                                    .border1()
                                    .borderColor(theme.border)
                                    .px1()
                                    .textXs()
                                    .child(div().truncate().child(item))
                                    .child(new Button('remove-$item')
                                        .ghost()
                                        .xsmall()
                                        .icon(new Icon(IconName.Close).xsmall())
                                        .tabStop(false)
                                        .onClick((_ev, _window, cx) -> {
                                            cx.stopPropagation();
                                            state.update(cx, (s, cx) -> {
                                                s.removeSelectedIndex(index, cx);
                                            });
                                        }));
                            }]);
                        if (hidden > 0) {
                            badges.child(div()
                                .flexShrink0()
                                .textXs()
                                .textColor(theme.mutedForeground)
                                .child('+$hidden'));
                        }
                        return hFlex()
                            .wFull()
                            .itemsCenter()
                            .justifyBetween()
                            .gap2()
                            .child(badges)
                            .child(div().flexShrink0().child(new Caret(trigger.size())
                                .textColor(theme.mutedForeground)))
                            .intoAnyElement();
                    })
                    .w(px(280.))))
            .child(section('Maximum selections')
                .w(px(280.))
                .description('Limit how many items can be selected.')
                .child(new Combobox(customMax2)
                    .placeholder('Select up to 2 frameworks')
                    .searchPlaceholder('Search…')
                    .w(px(280.))))
            .child(section('Pinned items')
                .w(px(280.))
                .description('Keep required items selected.')
                .child(new Combobox(pinned)
                    .placeholder('Select framework...')
                    .searchPlaceholder('Search…')
                    .w(px(280.))))
            .child(section('Rich items')
                .w(px(280.))
                .description('Render supporting content in option rows.')
                .child(new Combobox(featured)
                    .placeholder('Select framework...')
                    .searchPlaceholder('Search…')
                    .w(px(280.))))
            .child(section('Overflow')
                .w(px(280.))
                .description('Collapse selections after a visible limit.')
                .child(new Combobox(multiExpand)
                    .placeholder('Select frameworks')
                    .searchPlaceholder('Search…')
                    .renderTrigger((trigger, _, cx) -> {
                        final MAX_SHOWN = 2;
                        final theme = Theme.global(cx);

                        if (trigger.selection().length == 0) {
                            return div()
                                .textColor(theme.mutedForeground)
                                .child('Select frameworks')
                                .intoAnyElement();
                        }

                        final row = hFlex()
                            .wFull()
                            .flexWrap()
                            .gap1()
                            .children([for (selected in trigger.selection().slice(0, MAX_SHOWN)) div()
                                .rounded(theme.radius.half())
                                .border1()
                                .borderColor(theme.border)
                                .px1()
                                .textXs()
                                .child(selected.item)]);
                        if (trigger.selection().length > MAX_SHOWN) {
                            final hidden = trigger.selection().length - MAX_SHOWN;
                            row.child(div()
                                .rounded(theme.radius.half())
                                .border1()
                                .borderColor(theme.border)
                                .px1()
                                .textXs()
                                .textColor(theme.mutedForeground)
                                .child('+$hidden more'));
                        }
                        return row.intoAnyElement();
                    })
                    .w(px(280.))))
            .child(section('Count')
                .w(px(280.))
                .description('Summarize selections as a count.')
                .child(new Combobox(multiCount)
                    .placeholder('Select frameworks')
                    .searchPlaceholder('Search…')
                    .renderTrigger((trigger, _, cx) -> {
                        final theme = Theme.global(cx);
                        final count = trigger.selection().length;

                        if (count == 0) {
                            return div()
                                .textColor(theme.mutedForeground)
                                .child('Select frameworks')
                                .intoAnyElement();
                        }

                        final display = count > 99 ? '99+' : Std.string(count);

                        return hFlex()
                            .gap1p5()
                            .itemsCenter()
                            .child(hFlex()
                                .justifyCenter()
                                .itemsCenter()
                                .minW(px(16.))
                                .h(px(16.))
                                .px1()
                                .roundedFullStyle(cx)
                                .bg(theme.red)
                                .textColor(white())
                                .textSize(px(10.))
                                .lineHeight(relative(1.))
                                .child(display))
                            .child(div()
                                .textColor(theme.foreground)
                                .child('frameworks selected'))
                            .intoAnyElement();
                    })
                    .w(px(280.))))
            .child(section('Values')
                .description('Read selected values from each delegate.')
                .wFull()
                .child(vFlex()
                    .gap2()
                    .child('basic: ' + debugList(basic.read(cx).selectedValues()))
                    .child('grouped: ' + debugList(grouped.read(cx).selectedValues()))
                    .child('multi_badges: ' + debugList(multiBadges.read(cx).selectedValues()))
                    .child('multi_count: ' + debugList(multiCount.read(cx).selectedValues()))));
    }

    static inline function SearchableListItems_title(item:Any):String {
        return gpui.component.searchablelist.SearchableListItems.title(item);
    }

}
