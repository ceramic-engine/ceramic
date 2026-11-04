// Ported from gpui-kit 0.8.1: crates/story/src/stories/theme_story/color_theme_story.rs
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
import gpui.AnyElement;
import gpui.Hsla;
import gpui.ListAlignment;
import gpui.ListState;
import gpui.SpringMath;
import gpui.base.IndexPath;
import gpui.base.input.InputEvent;
import gpui.base.input.InputState;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.button.Button;
import gpui.component.clipboard.Clipboard;
import gpui.component.input.Input;
import gpui.component.menu.PopupMenu;
import gpui.component.searchablelist.SearchableListItem.SearchableListItemBase;
import gpui.component.searchablelist.SearchableVec.VecDelegate;
import gpui.component.select.Select;
import gpui.component.select.SelectState;
import gpui.component.select.SelectState.SelectEvent;
import gpui.component.sidebar.Sidebar;
import gpui.component.sidebar.SidebarMenu;
import gpui.component.sidebar.SidebarMenu.SidebarMenuItem;
import gpui.component.theme.Theme;
import gpui.component.theme.ThemeColor;
import gpui.component.theme.ThemeConfig;
import gpui.component.theme.ThemeRegistry;
import story.stories.themestory.Checkerboard;
import story.stories.themestory.Mapper;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using gpui.base.StyledExt;
using gpui.component.ThemeStyled;
using gpui.component.WindowExt;
using gpui.component.scroll.Scrollable;

/** Rust `ThemeOption::ShowInherited`. */
@:action(namespace = theme_colors_story, name = ShowInherited, noJson) private class ThemeOptionShowInherited implements Action {}

/** Rust `ThemeOption::ExpandAll`. */
@:action(namespace = theme_colors_story, name = ExpandAll, noJson) private class ThemeOptionExpandAll implements Action {}

private class ColorEntry {

    public final name:String;

    public final color:Hsla;

    public final hex:String;

    public final isExplicit:Bool;

    public function new(name:String, color:Hsla, hex:String, isExplicit:Bool) {
        this.name = name;
        this.color = color;
        this.hex = hex;
        this.isExplicit = isExplicit;
    }

}

private class ColorCategory {

    public final name:String;

    public final entries:Array<ColorEntry>;

    public function new(name:String, entries:Array<ColorEntry>) {
        this.name = name;
        this.entries = entries;
    }

}

private class ThemeItem extends SearchableListItemBase {

    public final name:String;

    public final isActive:Bool;

    public function new(name:String, isActive:Bool) {
        this.name = name;
        this.isActive = isActive;
    }

    public function title():String {
        return name;
    }

    public function value():Any {
        return name;
    }

    override public function render(_:Window, cx:App):IntoElement {
        final isActive = this.isActive;
        return hFlex()
            .wFull()
            .itemsCenter()
            .gap2()
            .child(div()
                .size(rems(1.0))
                .flexShrink0()
                .when(isActive, this_ -> {
                    final icon = new Icon(IconName.Check);
                    new gpui.StyleBuilder(icon.style()).size(rems(1.0));
                    this_.child(icon.textColor(Theme.global(cx).primary));
                }))
            .child(name);
    }

}

class ThemeColorsStory extends Model implements Story {

    public static function title():String {
        return 'Theme Colors';
    }

    public static function description():String {
        // Themes are loaded by applying user-defined color overrides to a default base theme,
        // with inherited colors marked by an indicator dot.
        return 'A color theme viewer to explore colors organized by categories.';
    }

    public static function newView(window:Window, cx:App):gpui.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<ThemeColorsStory> {
        return cx.newEntity((c:Context<ThemeColorsStory>) -> new ThemeColorsStory(window, c));
    }

    final selectState:Entity<SelectState<ThemeItem>>;

    var selectedThemeName:String;

    var showAllColors:Bool = false;

    var sidebarRenderKey:Int = 0;

    var forceOpenState:Null<Bool> = null;

    var filterByValue:Null<Hsla> = null;

    final filterInput:Entity<InputState>;

    var allCategories:Array<ColorCategory> = [];

    var categories:Array<ColorCategory> = [];

    static function lowerCompare(a:String, b:String):Int {
        final al = a.toLowerCase();
        final bl = b.toLowerCase();
        return al < bl ? -1 : (al > bl ? 1 : 0);
    }

    function new(window:Window, cx:Context<ThemeColorsStory>) {
        super();
        final registry = ThemeRegistry.global(cx.app);
        final themes = registry.sortedThemes();
        haxe.ds.ArraySort.sort(themes, (a, b) -> lowerCompare(a.name, b.name));
        final activeThemeName = Theme.global(cx.app).themeName();
        final items = [for (theme in themes) new ThemeItem(theme.name, theme.name == activeThemeName)];
        final currentTheme = activeThemeName;
        var selectedIndex:Null<Int> = null;
        for (ix => item in items) {
            if (item.name == currentTheme) {
                selectedIndex = ix;
                break;
            }
        }
        final selectedPath = selectedIndex != null ? new IndexPath().withRow(selectedIndex) : null;
        selectState = cx.newEntity((cx:Context<SelectState<ThemeItem>>) -> new SelectState<ThemeItem>(new VecDelegate(items), selectedPath, window, cx));
        selectedThemeName = currentTheme;
        filterInput = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).withPlaceholder('Search...'));

        cx.subscribe(selectState, SelectEvent, (this_, _, event, cx) -> switch event {
            case Confirm(themeName):
                if (themeName != null) {
                    this_.selectedThemeName = themeName;
                    this_.filterByValue = null;
                    this_.allCategories = [];
                    this_.computeCategories(cx.app);
                    cx.notify();
                }
        }).detach();
        cx.subscribe(filterInput, InputEvent, (this_, _, event, cx) -> switch event {
            case Change:
                this_.computeCategories(cx.app);
                cx.notify();
            case _:
        }).detach();
        computeCategories(cx.app);
    }

    function getThemeColors(cx:App):ThemeColor {
        final themeConfig = ThemeRegistry.global(cx).themes().get(selectedThemeName);
        if (themeConfig != null) {
            final tempTheme = new Theme(themeConfig.mode.isDark() ? ThemeColor.dark() : ThemeColor.light());
            // Apply the config to get proper colors using the public API
            tempTheme.applyConfig(themeConfig);
            return tempTheme.colors;
        } else {
            // Fallback to current theme if selected theme not found
            return Theme.global(cx).colors;
        }
    }

    function getIsolatedTheme(cx:App):{colors:ThemeColor, isDark:Bool} {
        final registry = ThemeRegistry.global(cx);
        // Look up the selected theme configuration
        final selectedThemeConfig = registry.themes().get(selectedThemeName);
        // Rust falls back to the window appearance when the lookup fails: the
        // port has none, the selected theme always exists here.
        final isDark = selectedThemeConfig != null ? selectedThemeConfig.mode.isDark() : false;
        final themeConfig = isDark ? registry.defaultDarkTheme() : registry.defaultLightTheme();
        final tempTheme = new Theme(themeConfig.mode.isDark() ? ThemeColor.dark() : ThemeColor.light());
        tempTheme.applyConfig(themeConfig);
        return {colors: tempTheme.colors, isDark: isDark};
    }

    function computeCategories(cx:App):Void {
        if (allCategories.length == 0) {
            final theme = getThemeColors(cx);
            final themeConfig = ThemeRegistry.global(cx).themes().get(selectedThemeName);
            allCategories = formatColors(theme, themeConfig != null ? themeConfig : null);
        }

        var categories = allCategories.copy();
        if (filterByValue != null) {
            final filterValue = filterByValue;
            categories = filterCategories(categories, entry -> colorsEqualU8(entry.color, filterValue));
        } else if (!showAllColors) {
            categories = filterCategories(categories, entry -> entry.isExplicit);
        }

        final query = StringTools.trim(filterInput.read(cx).value()).toLowerCase();
        if (query != '') {
            final normalizedQuery = StringTools.startsWith(query, '#') ? query.substr(1) : query;
            final result = [];
            for (category in categories) {
                final categoryMatches = category.name.toLowerCase().indexOf(query) >= 0;
                final filteredColors = [for (entry in category.entries) if (categoryMatches || entry.name.toLowerCase().indexOf(query) >= 0
                    // Hex matching
                    || StringTools.startsWith(entry.hex, normalizedQuery)) entry];
                if (filteredColors.length > 0) result.push(new ColorCategory(category.name, filteredColors));
            }
            categories = result;
        }

        this.categories = categories;
    }

    static function renderColorSwatch(name:String, color:Hsla, hex:String, isExplicit:Bool, isolatedTheme:ThemeColor, cx:App):IntoElement {
        final rgbStr = '#$hex';
        final swatchGroup = 'swatch-$name';
        return hFlex()
            .group(swatchGroup)
            .gap3()
            .itemsCenter()
            .child(div()
                .size16()
                .rounded(Theme.global(cx).radius)
                .bg(color)
                .border1()
                .borderColor(isolatedTheme.border)
                .flexShrink0())
            .child(vFlex()
                .gap1()
                .flex1()
                .child(hFlex()
                    .gap2()
                    .itemsCenter()
                    .when(!isExplicit, this_ -> this_.child(div()
                        .size1p5()
                        .roundedFullStyle(cx)
                        .bg(isolatedTheme.foreground)
                        .flexShrink0()))
                    .child(div()
                        .textSm()
                        .fontMedium()
                        .when(!isExplicit, this_ -> this_.textColor(isolatedTheme.mutedForeground))
                        .when(isExplicit, this_ -> this_.textColor(isolatedTheme.foreground))
                        .child(name)))
                .child(hFlex()
                    .gap1()
                    .itemsCenter()
                    .child(div().textSm().textColor(isolatedTheme.mutedForeground).child(rgbStr))
                    .child(div()
                        .invisible()
                        .groupHover(swatchGroup, this_ -> this_.visible())
                        .child(new Clipboard('copy-$name')
                            .value(rgbStr)
                            .onCopied((value, window, cx) -> window.pushNotification('Copied $value to clipboard', cx))))));
    }

    function renderLeftPanel(_:Window, cx:Context<Dynamic>):Sidebar<SidebarMenu> {
        final categories = this.categories;
        final isFiltering = filterByValue != null;
        final entityRef:Entity<ThemeColorsStory> = cast cx.entity();
        final expandAll = (_:gpui.ClickEvent, _:Window, cx:App) -> entityRef.update(cx, (this_, cx) -> {
            this_.sidebarRenderKey += 1;
            this_.forceOpenState = true;
            cx.notify();
        });
        final collapseAll = (_:gpui.ClickEvent, _:Window, cx:App) -> entityRef.update(cx, (this_, cx) -> {
            this_.sidebarRenderKey += 1;
            this_.forceOpenState = false;
            cx.notify();
        });
        final forceOpenState = this.forceOpenState;

        return new Sidebar<SidebarMenu>('color-theme-sidebar-$sidebarRenderKey')
            .w(px(300.))
            .border0()
            .header(new Input(filterInput).prefix(new Icon(IconName.Search)))
            .child(new SidebarMenu().children([for (idx => category in categories) {
                final isOpen = forceOpenState != null ? forceOpenState : idx == 0;
                new SidebarMenuItem(category.name)
                    .defaultOpen(isOpen)
                    .clickToOpen(true)
                    .contextMenu((menu, _, _) -> menu
                        .item(PopupMenuItem.create('Expand All').onClick(expandAll))
                        .item(PopupMenuItem.create('Collapse All').onClick(collapseAll)))
                    .children([for (entry in category.entries) {
                        final colorValue = entry.color;
                        final isExplicit = entry.isExplicit;
                        new SidebarMenuItem(entry.name)
                            .suffix((_, cx) -> {
                                final theme = Theme.global(cx);
                                return hFlex()
                                    .gap2()
                                    .itemsCenter()
                                    .when(!isExplicit, this_ -> this_.child(div()
                                        .size1p5()
                                        .roundedFullStyle(cx)
                                        .bg(theme.foreground)))
                                    .child(div()
                                        .size4()
                                        .rounded(theme.radius.half())
                                        .bg(colorValue)
                                        .border1()
                                        .borderColor(theme.border)
                                        .flexShrink0());
                            })
                            .contextMenu((menu, _, _) -> {
                                if (isFiltering) {
                                    return menu.item(PopupMenuItem.create('Show All Values').onClick((_, _, cx) -> entityRef.update(cx, (this_, cx) -> {
                                        this_.filterByValue = null;
                                        this_.computeCategories(cx.app);
                                        cx.notify();
                                    })));
                                } else {
                                    return menu.item(PopupMenuItem.create('Filter By Value').onClick((_, _, cx) -> entityRef.update(cx, (this_, cx) -> {
                                        this_.filterByValue = colorValue;
                                        this_.computeCategories(cx.app);
                                        cx.notify();
                                    })));
                                }
                            });
                    }]);
            }]));
    }

    function renderRightPanel(window:Window, cx:Context<Dynamic>):IntoElement {
        final isolated = getIsolatedTheme(cx.app);
        final isolatedTheme = isolated.colors;
        final isDark = isolated.isDark;
        final theme = Theme.global(cx.app);
        final categories = this.categories.copy();
        final categoriesCount = categories.length;
        final listState = window.useKeyedState('color-theme-right-panel-list-state', cx.app, _ -> new ListState(19, ListAlignment.Top, 1000.)).read(cx.app).value;
        if (listState.itemCount() != categoriesCount) {
            listState.reset(categoriesCount);
        }

        return div()
            .border1()
            .borderColor(isolatedTheme.border)
            .rounded(theme.radiusLg)
            .sizeFull()
            .overflowHidden()
            .child(new Checkerboard(isDark).child(vFlex()
                .sizeFull()
                .overflowHidden()
                .rounded(theme.radiusLg)
                .px4()
                .child(list(listState, (ix, _, cx) -> {
                    final category = categories[ix];
                    final isLast = categoriesCount > 0 && ix == (categoriesCount > 0 ? categoriesCount - 1 : 0);
                    return vFlex()
                        .wFull()
                        .gap3()
                        .pt4()
                        .when(isLast, this_ -> this_.pb4())
                        .child(div()
                            .textBase()
                            .fontSemibold()
                            .pb2()
                            .borderB1()
                            .borderColor(isolatedTheme.border)
                            .textColor(isolatedTheme.foreground)
                            .child(category.name))
                        .child(div().flex().flexWrap().gap4().children([for (entry in category.entries) (div()
                            .w(px(220.))
                            .child(renderColorSwatch(entry.name, entry.color, entry.hex, entry.isExplicit, isolatedTheme, cx)) : IntoElement)]));
                })
                    .sizeFull())
                .verticalScrollbar(listState)));
    }

    /** The name of the `ThemeColor` field of a snake_case key. */
    static function fieldOf(key:String):String {
        if (key == 'switch') return 'switch_';
        final parts = key.split('_');
        var name = parts[0];
        for (i in 1...parts.length) {
            final part = parts[i];
            name += part.length > 0 ? part.charAt(0).toUpperCase() + part.substr(1) : '';
        }
        return name;
    }

    static function formatColors(theme:ThemeColor, config:Null<ThemeConfig>):Array<ColorCategory> {
        final categories = new Map<String, Array<ColorEntry>>();
        final categoryNames:Array<String> = [];

        // The keys present in the config (if available)
        var configKeys:Null<Map<String, Bool>> = null;
        if (config != null) {
            configKeys = new Map();
            final json:haxe.DynamicAccess<Dynamic> = config.colors.toJson();
            for (key => value in json) {
                if (value != null) configKeys.set(key, true);
            }
        }

        for (key in ThemeColor.FIELD_NAMES) {
            final value:Null<Hsla> = Reflect.field(theme, fieldOf(key));
            if (value == null) continue;
            // Rust reads the colors back from `serde_json::to_value(theme)`:
            // through the `#rrggbbaa` form of `Hsla`'s serde.
            final color = serdeRoundtrip(value);
            final parsed = Mapper.parseThemeKey(key);
            final category = parsed.category;
            final name = parsed.name;
            // Check if this key is explicit in the user config
            final isExplicit = configKeys != null && configKeys.exists(parsed.canonicalKey);
            if (!categories.exists(category)) {
                categories.set(category, []);
                categoryNames.push(category);
            }
            categories.get(category).push(new ColorEntry(name, color, hslaToHex(color), isExplicit));
        }

        final byteCompare = (a:String, b:String) -> a < b ? -1 : (a > b ? 1 : 0);
        // Rust BTreeMap: categories in key order
        categoryNames.sort(byteCompare);
        final categoriesVec = [for (name in categoryNames) {
            final entries = categories.get(name);
            haxe.ds.ArraySort.sort(entries, (a, b) -> byteCompare(a.name, b.name));
            new ColorCategory(name, entries);
        }];

        // Custom sort: Global first, then Primary, then others
        final priorityOrder = ['Global', 'Primary', 'Secondary', 'Accent', 'Base', 'Background', 'Foreground', 'Structure'];
        haxe.ds.ArraySort.sort(categoriesVec, (a, b) -> {
            final aPriority = priorityOrder.indexOf(a.name);
            final bPriority = priorityOrder.indexOf(b.name);
            if (aPriority >= 0 && bPriority >= 0) return aPriority - bPriority;
            if (aPriority >= 0) return -1;
            if (bPriority >= 0) return 1;
            return byteCompare(a.name, b.name);
        });
        return categoriesVec;
    }

    /** Rust `(x * 255.0) as u8` of an f32: truncated and saturated. */
    static function toU8(value:Float):Int {
        final v = SpringMath.f32(SpringMath.f32(value) * 255.0);
        if (Math.isNaN(v) || v <= 0) return 0;
        if (v >= 255) return 255;
        return Std.int(v);
    }

    static function hex2(value:Int):String {
        return StringTools.hex(value, 2).toLowerCase();
    }

    /**
     * Rust `Hsla::to_rgb`, computed in f32 like the original: the port's
     * `Rgba.fromHsla` computes in f64, which moves some channels by one
     * level once truncated to `u8` (e.g. `#e4e4e4` instead of `#e5e5e5`).
     */
    static function toRgbF32(color:Hsla):{r:Float, g:Float, b:Float} {
        final f = SpringMath.f32;
        final h = f(color.h);
        final s = f(color.s);
        final l = f(color.l);
        final c = f(f(1.0 - Math.abs(f(f(2.0 * l) - 1.0))) * s);
        final h6 = f(h * 6.0);
        final x = f(c * f(1.0 - Math.abs(f(f(h6 % 2.0) - 1.0))));
        final m = f(l - f(c / 2.0));
        final cm = f(c + m);
        final xm = f(x + m);
        var r:Float;
        var g:Float;
        var b:Float;
        switch gpui.util.MathUtil.toI32(Math.ffloor(h6)) {
            case 0 | 6:
                r = cm; g = xm; b = m;
            case 1:
                r = xm; g = cm; b = m;
            case 2:
                r = m; g = cm; b = xm;
            case 3:
                r = m; g = xm; b = cm;
            case 4:
                r = xm; g = m; b = cm;
            case _:
                r = cm; g = m; b = xm;
        }
        final clamp = (v:Float) -> v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v);
        return {r: clamp(r), g: clamp(g), b: clamp(b)};
    }

    /**
     * Rust `serde_json::from_value::<Hsla>(serde_json::to_value(color))`:
     * each channel rounded to 8 bits, then back to HSLA (f32 arithmetic).
     */
    static function serdeRoundtrip(color:Hsla):Hsla {
        final f = SpringMath.f32;
        final rgb = toRgbF32(color);
        final channel = (v:Float) -> f(gpui.util.MathUtil.toU8(gpui.util.MathUtil.round(f(v * 255.0))) / 255.0);
        final r = channel(rgb.r);
        final g = channel(rgb.g);
        final b = channel(rgb.b);
        final a = channel(color.a);
        final max = Math.max(r, Math.max(g, b));
        final min = Math.min(r, Math.min(g, b));
        final delta = f(max - min);
        final l = f(f(max + min) / 2.0);
        final s = if (l == 0.0 || l == 1.0) {
            0.0;
        } else if (l < 0.5) {
            f(delta / f(2.0 * l));
        } else {
            f(delta / f(2.0 - f(2.0 * l)));
        }
        final h = if (delta == 0.0) {
            0.0;
        } else if (max == r) {
            var q = f(f(g - b) / delta) % 6.0;
            if (q < 0) q = f(q + 6.0);
            f(q / 6.0);
        } else if (max == g) {
            f(f(f(f(b - r) / delta) + 2.0) / 6.0);
        } else {
            f(f(f(f(r - g) / delta) + 4.0) / 6.0);
        }
        return new Hsla(h, s, l, a);
    }

    static function hslaToHex(color:Hsla):String {
        final rgb = toRgbF32(color);
        if (color.a < 1.0) {
            return hex2(toU8(rgb.r)) + hex2(toU8(rgb.g)) + hex2(toU8(rgb.b)) + hex2(toU8(color.a));
        } else {
            return hex2(toU8(rgb.r)) + hex2(toU8(rgb.g)) + hex2(toU8(rgb.b));
        }
    }

    /** Compares two HSLA colors for equality at 8-bit precision. */
    static function colorsEqualU8(c1:Hsla, c2:Hsla):Bool {
        final rgb1 = toRgbF32(c1);
        final rgb2 = toRgbF32(c2);
        final eq = (a:Float, b:Float) -> gpui.util.MathUtil.toU8(gpui.util.MathUtil.round(SpringMath.f32(a * 255.0)))
            == gpui.util.MathUtil.toU8(gpui.util.MathUtil.round(SpringMath.f32(b * 255.0)));
        return eq(rgb1.r, rgb2.r) && eq(rgb1.g, rgb2.g) && eq(rgb1.b, rgb2.b) && eq(c1.a, c2.a);
    }

    /** Filters categories by a predicate on color entries, removing empty categories. */
    static function filterCategories(categories:Array<ColorCategory>, predicate:(ColorEntry) -> Bool):Array<ColorCategory> {
        final result = [];
        for (category in categories) {
            final filtered = [for (entry in category.entries) if (predicate(entry)) entry];
            if (filtered.length > 0) result.push(new ColorCategory(category.name, filtered));
        }
        return result;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final entity:Entity<ThemeColorsStory> = cast cx.entity();
        final showAllColors = this.showAllColors;
        final expandAll = forceOpenState == true;
        return vFlex()
            .onAction(ThemeOptionShowInherited, (_, _, cx) -> entity.update(cx, (this_, cx) -> {
                this_.showAllColors = !this_.showAllColors;
                this_.computeCategories(cx.app);
                cx.notify();
            }))
            .onAction(ThemeOptionExpandAll, (_, _, cx) -> entity.update(cx, (this_, cx) -> {
                this_.sidebarRenderKey += 1;
                this_.forceOpenState = this_.forceOpenState != true;
                cx.notify();
            }))
            .gap4()
            .sizeFull()
            .overflowHidden()
            // Theme selector at the top
            .child(hFlex()
                .wFull()
                .itemsCenter()
                .justifyBetween()
                .gap3()
                .flexWrap()
                .child(hFlex()
                    .gap2()
                    .child(div().w(px(300.)).child(new Select(selectState)))
                    .child(new Button('set_theme')
                        .primary()
                        .label('Set Theme')
                        .onClick((_, window, cx) -> entity.update(cx, (this_, _) -> {
                            final registry = ThemeRegistry.global(cx);
                            final themeConfig = registry.themes().get(this_.selectedThemeName);
                            if (themeConfig != null) {
                                Theme.update(cx, theme -> theme.applyConfig(themeConfig));
                                // Refresh the select items to update the active checkmark
                                final activeThemeName = Theme.global(cx).themeName();
                                final themes = ThemeRegistry.global(cx).sortedThemes();
                                // Re-create items with new active state
                                final items = [for (theme in themes) new ThemeItem(theme.name, theme.name == activeThemeName)];
                                // Sort again to be safe/consistent
                                haxe.ds.ArraySort.sort(items, (a, b) -> lowerCompare(a.name, b.name));
                                // Update the select state
                                this_.selectState.update(cx, (state, cx) -> state.setItems(new VecDelegate(items), window, cx));
                            }
                        }))))
                .child(storyToolbarGroup().dropdownChild(new Button('theme-options').label('Options'), (menu, _, _) -> menu
                    .menuWithCheck('Inherited Colors', showAllColors, new ThemeOptionShowInherited())
                    .menuWithCheck('Expand All', expandAll, new ThemeOptionExpandAll()))))
            .child(hFlex()
                .flex1()
                .itemsStart()
                .gap4()
                .child(renderLeftPanel(window, cx))
                .child(renderRightPanel(window, cx)));
    }

}
