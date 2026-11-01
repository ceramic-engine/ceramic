// Ported from gpui-kit 0.8.1: crates/story/src/stories/theme_story/mapper.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.

package story.stories.themestory;

/**
 * A parsed theme key with a category, a display name, and a canonical
 * dot-notation key.
 */
class ParsedKey {

    public final category:String;

    public final name:String;

    public final canonicalKey:String;

    public function new(category:String, name:String, canonicalKey:String) {
        this.category = category;
        this.name = name;
        this.canonicalKey = canonicalKey;
    }

}

/**
 * A compatibility bridge for mapping theme color keys: translates the legacy
 * snake_case keys of `ThemeColor` into the categories and names the Color
 * Theme Viewer shows (see the original file for how to remove it).
 */
class Mapper {

    static final KEYS:Map<String, Array<String>> = [
        // Accent
        'accent' => ['Accent', 'Background', 'accent.background'],
        'accent_foreground' => ['Accent', 'Foreground', 'accent.foreground'],
        // Primary
        'primary' => ['Primary', 'Background', 'primary.background'],
        'primary_active' => ['Primary', 'Active Background', 'primary.active.background'],
        'primary_foreground' => ['Primary', 'Foreground', 'primary.foreground'],
        'primary_hover' => ['Primary', 'Hover Background', 'primary.hover.background'],
        // Secondary
        'secondary' => ['Secondary', 'Background', 'secondary.background'],
        'secondary_active' => ['Secondary', 'Active Background', 'secondary.active.background'],
        'secondary_foreground' => ['Secondary', 'Foreground', 'secondary.foreground'],
        'secondary_hover' => ['Secondary', 'Hover Background', 'secondary.hover.background'],
        // Sidebar
        'sidebar' => ['Sidebar', 'Background', 'sidebar.background'],
        'sidebar_accent' => ['Sidebar', 'Accent Background', 'sidebar.accent.background'],
        'sidebar_accent_foreground' => ['Sidebar', 'Accent Foreground', 'sidebar.accent.foreground'],
        'sidebar_border' => ['Sidebar', 'Border', 'sidebar.border'],
        'sidebar_foreground' => ['Sidebar', 'Foreground', 'sidebar.foreground'],
        'sidebar_primary' => ['Sidebar', 'Primary Background', 'sidebar.primary.background'],
        'sidebar_primary_foreground' => ['Sidebar', 'Primary Foreground', 'sidebar.primary.foreground'],
        // List
        'list' => ['List', 'Background', 'list.background'],
        'list_active' => ['List', 'Active Background', 'list.active.background'],
        'list_active_border' => ['List', 'Active Border', 'list.active.border'],
        'list_even' => ['List', 'Even Background', 'list.even.background'],
        'list_head' => ['List', 'Head Background', 'list.head.background'],
        'list_hover' => ['List', 'Hover Background', 'list.hover.background'],
        // Table
        'table' => ['Table', 'Background', 'table.background'],
        'table_active' => ['Table', 'Active Background', 'table.active.background'],
        'table_active_border' => ['Table', 'Active Border', 'table.active.border'],
        'table_even' => ['Table', 'Even Background', 'table.even.background'],
        'table_head' => ['Table', 'Head Background', 'table.head.background'],
        'table_head_foreground' => ['Table', 'Head Foreground', 'table.head.foreground'],
        'table_hover' => ['Table', 'Hover Background', 'table.hover.background'],
        'table_row_border' => ['Table', 'Row Border', 'table.row.border'],
        // Tabs
        'tab' => ['Tab', 'Background', 'tab.background'],
        'tab_active' => ['Tab', 'Active Background', 'tab.active.background'],
        'tab_active_foreground' => ['Tab', 'Active Foreground', 'tab.active.foreground'],
        'tab_bar' => ['Tab Bar', 'Background', 'tab_bar.background'],
        'tab_bar_segmented' => ['Tab Bar', 'Segmented Background', 'tab_bar.segmented.background'],
        'tab_foreground' => ['Tab', 'Foreground', 'tab.foreground'],
        // Input
        'input' => ['Input', 'Border', 'input.border'],
        'caret' => ['Input', 'Caret', 'caret'],
        'selection' => ['Input', 'Selection', 'selection.background'],
        // Slider / Switch
        'slider_bar' => ['Slider', 'Bar', 'slider.background'],
        'slider_thumb' => ['Slider', 'Thumb', 'slider.thumb.background'],
        'switch' => ['Switch', 'Background', 'switch.background'],
        'switch_thumb' => ['Switch', 'Thumb', 'switch.thumb.background'],
        // Muted / Skeleton
        'muted' => ['Muted', 'Background', 'muted.background'],
        'muted_foreground' => ['Muted', 'Foreground', 'muted.foreground'],
        'skeleton' => ['Skeleton', 'Background', 'skeleton.background'],
        // Charts
        'chart_1' => ['Chart', 'Color 1', 'chart.1'],
        'chart_2' => ['Chart', 'Color 2', 'chart.2'],
        'chart_3' => ['Chart', 'Color 3', 'chart.3'],
        'chart_4' => ['Chart', 'Color 4', 'chart.4'],
        'chart_5' => ['Chart', 'Color 5', 'chart.5'],
        'chart_bullish' => ['Chart', 'Bullish', 'chart.bullish'],
        'chart_bearish' => ['Chart', 'Bearish', 'chart.bearish'],
        'chart_grid' => ['Chart', 'Grid', 'chart.grid'],
        // Danger / Success / Warning / Info
        'danger' => ['Danger', 'Background', 'danger.background'],
        'danger_active' => ['Danger', 'Active', 'danger.active.background'],
        'danger_foreground' => ['Danger', 'Foreground', 'danger.foreground'],
        'danger_hover' => ['Danger', 'Hover', 'danger.hover.background'],
        'success' => ['Success', 'Background', 'success.background'],
        'success_active' => ['Success', 'Active', 'success.active.background'],
        'success_foreground' => ['Success', 'Foreground', 'success.foreground'],
        'success_hover' => ['Success', 'Hover', 'success.hover.background'],
        'warning' => ['Warning', 'Background', 'warning.background'],
        'warning_active' => ['Warning', 'Active', 'warning.active.background'],
        'warning_foreground' => ['Warning', 'Foreground', 'warning.foreground'],
        'warning_hover' => ['Warning', 'Hover', 'warning.hover.background'],
        'info' => ['Info', 'Background', 'info.background'],
        'info_active' => ['Info', 'Active', 'info.active.background'],
        'info_foreground' => ['Info', 'Foreground', 'info.foreground'],
        'info_hover' => ['Info', 'Hover', 'info.hover.background'],
        // Base Colors
        'red' => ['Base', 'Red', 'base.red'],
        'red_light' => ['Base', 'Red Light', 'base.red.light'],
        'green' => ['Base', 'Green', 'base.green'],
        'green_light' => ['Base', 'Green Light', 'base.green.light'],
        'blue' => ['Base', 'Blue', 'base.blue'],
        'blue_light' => ['Base', 'Blue Light', 'base.blue.light'],
        'yellow' => ['Base', 'Yellow', 'base.yellow'],
        'yellow_light' => ['Base', 'Yellow Light', 'base.yellow.light'],
        'magenta' => ['Base', 'Magenta', 'base.magenta'],
        'magenta_light' => ['Base', 'Magenta Light', 'base.magenta.light'],
        'cyan' => ['Base', 'Cyan', 'base.cyan'],
        'cyan_light' => ['Base', 'Cyan Light', 'base.cyan.light'],
    ];

    /**
     * Parses a theme key (either snake_case or dot-notation) into a logical
     * category and name.
     */
    public static function parseThemeKey(key:String):ParsedKey {
        // 1. Check for dot-notation (e.g. "accent.background")
        final dot = key.indexOf('.');
        if (dot >= 0) {
            return new ParsedKey(toTitleCaseFull(key.substr(0, dot)), toTitleCaseFull(key.substr(dot + 1)), key);
        }

        // 2. Handle legacy snake_case remapping (e.g. "accent_foreground" -> "Accent" / "Foreground")
        var category:String;
        var name:String;
        var canonical:String;
        final known = KEYS.get(key);
        if (known != null) {
            category = known[0];
            name = known[1];
            canonical = known[2];
        } else {
            // Everything else remains in Global or attempts a split
            final underscore = key.indexOf('_');
            if (underscore >= 0) {
                category = key.substr(0, underscore);
                name = key.substr(underscore + 1);
                canonical = key;
            } else {
                category = 'Global';
                name = key;
                canonical = key;
            }
        }
        return new ParsedKey(toTitleCaseFull(category), toTitleCaseFull(name), canonical);
    }

    static function toTitleCase(s:String):String {
        return s.length == 0 ? '' : s.charAt(0).toUpperCase() + s.substr(1);
    }

    static function toTitleCaseFull(s:String):String {
        return [for (part in ~/[_.]/g.split(s)) toTitleCase(part)].join(' ');
    }

}
