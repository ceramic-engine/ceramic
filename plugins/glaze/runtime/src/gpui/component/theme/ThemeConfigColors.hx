// Ported from gpui-kit 0.8.1: crates/component/src/theme/schema.rs (ThemeConfigColors)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.theme;

/**
 * The `colors` section of a theme file: every value is the raw string of the
 * file (a color, a Tailwind color expression or a `linear-gradient(...)`),
 * parsed when the config is applied. `null` when the key is absent.
 *
 * `switch` is a Haxe keyword: the `switch.background` value is `switch_`.
 */
class ThemeConfigColors {

    /**
     * Used for accents such as hover background on MenuItem, ListItem, etc.
     */
    // `accent.background`
    public var accent:Null<String> = null;

    /**
     * Used for accent text color.
     */
    // `accent.foreground`
    public var accentForeground:Null<String> = null;

    /**
     * Accordion background color.
     */
    // `accordion.background`
    public var accordion:Null<String> = null;

    /**
     * Default background color.
     */
    // `background`
    public var background:Null<String> = null;

    /**
     * Default border color
     */
    // `border`
    public var border:Null<String> = null;

    /**
     * Default Button background color.
     */
    // `button.background`
    public var button:Null<String> = null;

    /**
     * Default Button active background color.
     */
    // `button.active.background`
    public var buttonActive:Null<String> = null;

    /**
     * Default Button text color.
     */
    // `button.foreground`
    public var buttonForeground:Null<String> = null;

    /**
     * Default Button hover background color.
     */
    // `button.hover.background`
    public var buttonHover:Null<String> = null;

    /**
     * Button danger background color, fallback to `danger`.
     */
    // `button.danger.background`
    public var buttonDanger:Null<String> = null;

    /**
     * Button danger active background color, fallback to `danger_active`.
     */
    // `button.danger.active.background`
    public var buttonDangerActive:Null<String> = null;

    /**
     * Button danger text color, fallback to `danger_foreground`.
     */
    // `button.danger.foreground`
    public var buttonDangerForeground:Null<String> = null;

    /**
     * Button danger hover background color, fallback to `danger_hover`.
     */
    // `button.danger.hover.background`
    public var buttonDangerHover:Null<String> = null;

    /**
     * Button info background color, fallback to `info`.
     */
    // `button.info.background`
    public var buttonInfo:Null<String> = null;

    /**
     * Button info active background color, fallback to `info_active`.
     */
    // `button.info.active.background`
    public var buttonInfoActive:Null<String> = null;

    /**
     * Button info text color, fallback to `info_foreground`.
     */
    // `button.info.foreground`
    public var buttonInfoForeground:Null<String> = null;

    /**
     * Button info hover background color, fallback to `info_hover`.
     */
    // `button.info.hover.background`
    public var buttonInfoHover:Null<String> = null;

    /**
     * Button primary background color, fallback to `primary`.
     */
    // `button.primary.background`
    public var buttonPrimary:Null<String> = null;

    /**
     * Button primary active background color, fallback to `primary_active`.
     */
    // `button.primary.active.background`
    public var buttonPrimaryActive:Null<String> = null;

    /**
     * Button primary text color, fallback to `primary_foreground`.
     */
    // `button.primary.foreground`
    public var buttonPrimaryForeground:Null<String> = null;

    /**
     * Button primary hover background color, fallback to `primary_hover`.
     */
    // `button.primary.hover.background`
    public var buttonPrimaryHover:Null<String> = null;

    /**
     * Button secondary background color, fallback to `secondary`.
     */
    // `button.secondary.background`
    public var buttonSecondary:Null<String> = null;

    /**
     * Button secondary active background color, fallback to `secondary_active`.
     */
    // `button.secondary.active.background`
    public var buttonSecondaryActive:Null<String> = null;

    /**
     * Button secondary text color, fallback to `secondary_foreground`.
     */
    // `button.secondary.foreground`
    public var buttonSecondaryForeground:Null<String> = null;

    /**
     * Button secondary hover background color, fallback to `secondary_hover`.
     */
    // `button.secondary.hover.background`
    public var buttonSecondaryHover:Null<String> = null;

    /**
     * Button success background color, fallback to `success`.
     */
    // `button.success.background`
    public var buttonSuccess:Null<String> = null;

    /**
     * Button success active background color, fallback to `success_active`.
     */
    // `button.success.active.background`
    public var buttonSuccessActive:Null<String> = null;

    /**
     * Button success text color, fallback to `success_foreground`.
     */
    // `button.success.foreground`
    public var buttonSuccessForeground:Null<String> = null;

    /**
     * Button success hover background color, fallback to `success_hover`.
     */
    // `button.success.hover.background`
    public var buttonSuccessHover:Null<String> = null;

    /**
     * Button warning background color, fallback to `warning`.
     */
    // `button.warning.background`
    public var buttonWarning:Null<String> = null;

    /**
     * Button warning active background color, fallback to `warning_active`.
     */
    // `button.warning.active.background`
    public var buttonWarningActive:Null<String> = null;

    /**
     * Button warning text color, fallback to `warning_foreground`.
     */
    // `button.warning.foreground`
    public var buttonWarningForeground:Null<String> = null;

    /**
     * Button warning hover background color, fallback to `warning_hover`.
     */
    // `button.warning.hover.background`
    public var buttonWarningHover:Null<String> = null;

    /**
     * Background color for GroupBox.
     */
    // `group_box.background`
    public var groupBox:Null<String> = null;

    /**
     * Text color for GroupBox.
     */
    // `group_box.foreground`
    public var groupBoxForeground:Null<String> = null;

    /**
     * Title text color for GroupBox.
     */
    // `group_box.title.foreground`
    public var groupBoxTitleForeground:Null<String> = null;

    /**
     * Input caret color (Blinking cursor).
     */
    // `caret`
    public var caret:Null<String> = null;

    /**
     * Chart 1 color.
     */
    // `chart.1`
    public var chart1:Null<String> = null;

    /**
     * Chart 2 color.
     */
    // `chart.2`
    public var chart2:Null<String> = null;

    /**
     * Chart 3 color.
     */
    // `chart.3`
    public var chart3:Null<String> = null;

    /**
     * Chart 4 color.
     */
    // `chart.4`
    public var chart4:Null<String> = null;

    /**
     * Chart 5 color.
     */
    // `chart.5`
    public var chart5:Null<String> = null;

    /**
     * Bullish color for candlestick charts (upward price movement).
     */
    // `chart.bullish`
    public var chartBullish:Null<String> = null;

    /**
     * Bearish color for candlestick charts (downward price movement).
     */
    // `chart.bearish`
    public var chartBearish:Null<String> = null;

    /**
     * Chart grid line color.
     */
    // `chart.grid`
    public var chartGrid:Null<String> = null;

    /**
     * Danger background color.
     */
    // `danger.background`
    public var danger:Null<String> = null;

    /**
     * Danger active background color.
     */
    // `danger.active.background`
    public var dangerActive:Null<String> = null;

    /**
     * Danger text color.
     */
    // `danger.foreground`
    public var dangerForeground:Null<String> = null;

    /**
     * Danger hover background color.
     */
    // `danger.hover.background`
    public var dangerHover:Null<String> = null;

    /**
     * Description List label background color.
     */
    // `description_list.label.background`
    public var descriptionListLabel:Null<String> = null;

    /**
     * Description List label foreground color.
     */
    // `description_list.label.foreground`
    public var descriptionListLabelForeground:Null<String> = null;

    /**
     * Drag border color.
     */
    // `drag.border`
    public var dragBorder:Null<String> = null;

    /**
     * Drop target background color.
     */
    // `drop_target.background`
    public var dropTarget:Null<String> = null;

    /**
     * Default text color.
     */
    // `foreground`
    public var foreground:Null<String> = null;

    /**
     * Info background color.
     */
    // `info.background`
    public var info:Null<String> = null;

    /**
     * Info active background color.
     */
    // `info.active.background`
    public var infoActive:Null<String> = null;

    /**
     * Info text color.
     */
    // `info.foreground`
    public var infoForeground:Null<String> = null;

    /**
     * Info hover background color.
     */
    // `info.hover.background`
    public var infoHover:Null<String> = null;

    /**
     * Border color for inputs such as Input, Select, etc.
     */
    // `input.border`
    public var input:Null<String> = null;

    /**
     * Link text color.
     */
    // `link`
    public var link:Null<String> = null;

    /**
     * Active link text color.
     */
    // `link.active`
    public var linkActive:Null<String> = null;

    /**
     * Hover link text color.
     */
    // `link.hover`
    public var linkHover:Null<String> = null;

    /**
     * Background color for List and ListItem.
     */
    // `list.background`
    public var list:Null<String> = null;

    /**
     * Background color for active ListItem.
     */
    // `list.active.background`
    public var listActive:Null<String> = null;

    /**
     * Border color for active ListItem.
     */
    // `list.active.border`
    public var listActiveBorder:Null<String> = null;

    /**
     * Stripe background color for even ListItem.
     */
    // `list.even.background`
    public var listEven:Null<String> = null;

    /**
     * Background color for List header.
     */
    // `list.head.background`
    public var listHead:Null<String> = null;

    /**
     * Hover background color for ListItem.
     */
    // `list.hover.background`
    public var listHover:Null<String> = null;

    /**
     * Muted backgrounds such as Skeleton and Switch.
     */
    // `muted.background`
    public var muted:Null<String> = null;

    /**
     * Muted text color, as used in disabled text.
     */
    // `muted.foreground`
    public var mutedForeground:Null<String> = null;

    /**
     * Background color for Popover.
     */
    // `popover.background`
    public var popover:Null<String> = null;

    /**
     * Text color for Popover.
     */
    // `popover.foreground`
    public var popoverForeground:Null<String> = null;

    /**
     * Primary background color.
     */
    // `primary.background`
    public var primary:Null<String> = null;

    /**
     * Active primary background color.
     */
    // `primary.active.background`
    public var primaryActive:Null<String> = null;

    /**
     * Primary text color.
     */
    // `primary.foreground`
    public var primaryForeground:Null<String> = null;

    /**
     * Hover primary background color.
     */
    // `primary.hover.background`
    public var primaryHover:Null<String> = null;

    /**
     * Progress bar background color.
     */
    // `progress.bar.background`
    public var progressBar:Null<String> = null;

    /**
     * Used for focus ring.
     */
    // `ring`
    public var ring:Null<String> = null;

    /**
     * Scrollbar background color.
     */
    // `scrollbar.background`
    public var scrollbar:Null<String> = null;

    /**
     * Scrollbar thumb background color.
     */
    // `scrollbar.thumb.background`
    public var scrollbarThumb:Null<String> = null;

    /**
     * Scrollbar thumb hover background color.
     */
    // `scrollbar.thumb.hover.background`
    public var scrollbarThumbHover:Null<String> = null;

    /**
     * Secondary background color.
     */
    // `secondary.background`
    public var secondary:Null<String> = null;

    /**
     * Active secondary background color.
     */
    // `secondary.active.background`
    public var secondaryActive:Null<String> = null;

    /**
     * Secondary text color, used for secondary Button text color or secondary text.
     */
    // `secondary.foreground`
    public var secondaryForeground:Null<String> = null;

    /**
     * Hover secondary background color.
     */
    // `secondary.hover.background`
    public var secondaryHover:Null<String> = null;

    /**
     * Input selection background color.
     */
    // `selection.background`
    public var selection:Null<String> = null;

    /**
     * Sidebar background color.
     */
    // `sidebar.background`
    public var sidebar:Null<String> = null;

    /**
     * Sidebar accent background color.
     */
    // `sidebar.accent.background`
    public var sidebarAccent:Null<String> = null;

    /**
     * Sidebar accent text color.
     */
    // `sidebar.accent.foreground`
    public var sidebarAccentForeground:Null<String> = null;

    /**
     * Sidebar border color.
     */
    // `sidebar.border`
    public var sidebarBorder:Null<String> = null;

    /**
     * Sidebar text color.
     */
    // `sidebar.foreground`
    public var sidebarForeground:Null<String> = null;

    /**
     * Sidebar primary background color.
     */
    // `sidebar.primary.background`
    public var sidebarPrimary:Null<String> = null;

    /**
     * Sidebar primary text color.
     */
    // `sidebar.primary.foreground`
    public var sidebarPrimaryForeground:Null<String> = null;

    /**
     * Skeleton background color.
     */
    // `skeleton.background`
    public var skeleton:Null<String> = null;

    /**
     * Slider bar background color.
     */
    // `slider.background`
    public var sliderBar:Null<String> = null;

    /**
     * Slider thumb background color.
     */
    // `slider.thumb.background`
    public var sliderThumb:Null<String> = null;

    /**
     * Success background color.
     */
    // `success.background`
    public var success:Null<String> = null;

    /**
     * Success text color.
     */
    // `success.foreground`
    public var successForeground:Null<String> = null;

    /**
     * Success hover background color.
     */
    // `success.hover.background`
    public var successHover:Null<String> = null;

    /**
     * Success active background color.
     */
    // `success.active.background`
    public var successActive:Null<String> = null;

    /**
     * Switch background color.
     */
    // `switch.background`
    public var switch_:Null<String> = null;

    /**
     * Switch thumb background color.
     */
    // `switch.thumb.background`
    public var switchThumb:Null<String> = null;

    /**
     * Tab background color.
     */
    // `tab.background`
    public var tab:Null<String> = null;

    /**
     * Tab active background color.
     */
    // `tab.active.background`
    public var tabActive:Null<String> = null;

    /**
     * Tab active text color.
     */
    // `tab.active.foreground`
    public var tabActiveForeground:Null<String> = null;

    /**
     * TabBar background color.
     */
    // `tab_bar.background`
    public var tabBar:Null<String> = null;

    /**
     * TabBar segmented background color.
     */
    // `tab_bar.segmented.background`
    public var tabBarSegmented:Null<String> = null;

    /**
     * Tab text color.
     */
    // `tab.foreground`
    public var tabForeground:Null<String> = null;

    /**
     * Table background color.
     */
    // `table.background`
    public var table:Null<String> = null;

    /**
     * Table active item background color.
     */
    // `table.active.background`
    public var tableActive:Null<String> = null;

    /**
     * Table active item border color.
     */
    // `table.active.border`
    public var tableActiveBorder:Null<String> = null;

    /**
     * Stripe background color for even TableRow.
     */
    // `table.even.background`
    public var tableEven:Null<String> = null;

    /**
     * Table header background color.
     */
    // `table.head.background`
    public var tableHead:Null<String> = null;

    /**
     * Table header text color.
     */
    // `table.head.foreground`
    public var tableHeadForeground:Null<String> = null;

    /**
     * Table footer background color.
     */
    // `table.foot.background`
    public var tableFoot:Null<String> = null;

    /**
     * Table footer text color.
     */
    // `table.foot.foreground`
    public var tableFootForeground:Null<String> = null;

    /**
     * Table item hover background color.
     */
    // `table.hover.background`
    public var tableHover:Null<String> = null;

    /**
     * Table row border color.
     */
    // `table.row.border`
    public var tableRowBorder:Null<String> = null;

    /**
     * TitleBar background color, use for Window title bar.
     */
    // `title_bar.background`
    public var titleBar:Null<String> = null;

    /**
     * TitleBar border color.
     */
    // `title_bar.border`
    public var titleBarBorder:Null<String> = null;

    /**
     * StatusBar background color, use for the bottom status bar.
     */
    // `status_bar.background`
    public var statusBar:Null<String> = null;

    /**
     * StatusBar border color.
     */
    // `status_bar.border`
    public var statusBarBorder:Null<String> = null;

    /**
     * Warning background color.
     */
    // `warning.background`
    public var warning:Null<String> = null;

    /**
     * Warning active background color.
     */
    // `warning.active.background`
    public var warningActive:Null<String> = null;

    /**
     * Warning hover background color.
     */
    // `warning.hover.background`
    public var warningHover:Null<String> = null;

    /**
     * Warning foreground color.
     */
    // `warning.foreground`
    public var warningForeground:Null<String> = null;

    /**
     * Overlay background color.
     */
    // `overlay`
    public var overlay:Null<String> = null;

    /**
     * Window border color.
     *
     * # Platform specific:
     *
     * This is only works on Linux, other platforms we can't change the window border color.
     */
    // `window.border`
    public var windowBorder:Null<String> = null;

    /**
     * Base blue color.
     */
    // `base.blue`
    public var blue:Null<String> = null;

    /**
     * Base light blue color.
     */
    // `base.blue.light`
    public var blueLight:Null<String> = null;

    /**
     * Base cyan color.
     */
    // `base.cyan`
    public var cyan:Null<String> = null;

    /**
     * Base light cyan color.
     */
    // `base.cyan.light`
    public var cyanLight:Null<String> = null;

    /**
     * Base green color.
     */
    // `base.green`
    public var green:Null<String> = null;

    /**
     * Base light green color.
     */
    // `base.green.light`
    public var greenLight:Null<String> = null;

    /**
     * Base magenta color.
     */
    // `base.magenta`
    public var magenta:Null<String> = null;

    // `base.magenta.light`
    public var magentaLight:Null<String> = null;

    /**
     * Base red color.
     */
    // `base.red`
    public var red:Null<String> = null;

    /**
     * Base light red color.
     */
    // `base.red.light`
    public var redLight:Null<String> = null;

    /**
     * Base yellow color.
     */
    // `base.yellow`
    public var yellow:Null<String> = null;

    /**
     * Base light yellow color.
     */
    // `base.yellow.light`
    public var yellowLight:Null<String> = null;

    public function new() {}

    /**
     * The JSON keys of the fields, as in the theme files.
     */
    public static final KEYS:Array<String> = [
        'accent.background',
        'accent.foreground',
        'accordion.background',
        'background',
        'border',
        'button.background',
        'button.active.background',
        'button.foreground',
        'button.hover.background',
        'button.danger.background',
        'button.danger.active.background',
        'button.danger.foreground',
        'button.danger.hover.background',
        'button.info.background',
        'button.info.active.background',
        'button.info.foreground',
        'button.info.hover.background',
        'button.primary.background',
        'button.primary.active.background',
        'button.primary.foreground',
        'button.primary.hover.background',
        'button.secondary.background',
        'button.secondary.active.background',
        'button.secondary.foreground',
        'button.secondary.hover.background',
        'button.success.background',
        'button.success.active.background',
        'button.success.foreground',
        'button.success.hover.background',
        'button.warning.background',
        'button.warning.active.background',
        'button.warning.foreground',
        'button.warning.hover.background',
        'group_box.background',
        'group_box.foreground',
        'group_box.title.foreground',
        'caret',
        'chart.1',
        'chart.2',
        'chart.3',
        'chart.4',
        'chart.5',
        'chart.bullish',
        'chart.bearish',
        'chart.grid',
        'danger.background',
        'danger.active.background',
        'danger.foreground',
        'danger.hover.background',
        'description_list.label.background',
        'description_list.label.foreground',
        'drag.border',
        'drop_target.background',
        'foreground',
        'info.background',
        'info.active.background',
        'info.foreground',
        'info.hover.background',
        'input.border',
        'link',
        'link.active',
        'link.hover',
        'list.background',
        'list.active.background',
        'list.active.border',
        'list.even.background',
        'list.head.background',
        'list.hover.background',
        'muted.background',
        'muted.foreground',
        'popover.background',
        'popover.foreground',
        'primary.background',
        'primary.active.background',
        'primary.foreground',
        'primary.hover.background',
        'progress.bar.background',
        'ring',
        'scrollbar.background',
        'scrollbar.thumb.background',
        'scrollbar.thumb.hover.background',
        'secondary.background',
        'secondary.active.background',
        'secondary.foreground',
        'secondary.hover.background',
        'selection.background',
        'sidebar.background',
        'sidebar.accent.background',
        'sidebar.accent.foreground',
        'sidebar.border',
        'sidebar.foreground',
        'sidebar.primary.background',
        'sidebar.primary.foreground',
        'skeleton.background',
        'slider.background',
        'slider.thumb.background',
        'success.background',
        'success.foreground',
        'success.hover.background',
        'success.active.background',
        'switch.background',
        'switch.thumb.background',
        'tab.background',
        'tab.active.background',
        'tab.active.foreground',
        'tab_bar.background',
        'tab_bar.segmented.background',
        'tab.foreground',
        'table.background',
        'table.active.background',
        'table.active.border',
        'table.even.background',
        'table.head.background',
        'table.head.foreground',
        'table.foot.background',
        'table.foot.foreground',
        'table.hover.background',
        'table.row.border',
        'title_bar.background',
        'title_bar.border',
        'status_bar.background',
        'status_bar.border',
        'warning.background',
        'warning.active.background',
        'warning.hover.background',
        'warning.foreground',
        'overlay',
        'window.border',
        'base.blue',
        'base.blue.light',
        'base.cyan',
        'base.cyan.light',
        'base.green',
        'base.green.light',
        'base.magenta',
        'base.magenta.light',
        'base.red',
        'base.red.light',
        'base.yellow',
        'base.yellow.light'
    ];

    /**
     * Reads the `colors` object of a theme file (serde semantics: unknown keys
     * are ignored, `null` is absent, any other non string value throws).
     */
    public static function fromJson(json:Dynamic):ThemeConfigColors {

        final result = new ThemeConfigColors();
        if (json == null) return result;
        if (!JsonValue.isObject(json)) {
            throw 'invalid type for `colors`, expected a map';
        }
        result.accent = JsonValue.optString(json, 'accent.background');
        result.accentForeground = JsonValue.optString(json, 'accent.foreground');
        result.accordion = JsonValue.optString(json, 'accordion.background');
        result.background = JsonValue.optString(json, 'background');
        result.border = JsonValue.optString(json, 'border');
        result.button = JsonValue.optString(json, 'button.background');
        result.buttonActive = JsonValue.optString(json, 'button.active.background');
        result.buttonForeground = JsonValue.optString(json, 'button.foreground');
        result.buttonHover = JsonValue.optString(json, 'button.hover.background');
        result.buttonDanger = JsonValue.optString(json, 'button.danger.background');
        result.buttonDangerActive = JsonValue.optString(json, 'button.danger.active.background');
        result.buttonDangerForeground = JsonValue.optString(json, 'button.danger.foreground');
        result.buttonDangerHover = JsonValue.optString(json, 'button.danger.hover.background');
        result.buttonInfo = JsonValue.optString(json, 'button.info.background');
        result.buttonInfoActive = JsonValue.optString(json, 'button.info.active.background');
        result.buttonInfoForeground = JsonValue.optString(json, 'button.info.foreground');
        result.buttonInfoHover = JsonValue.optString(json, 'button.info.hover.background');
        result.buttonPrimary = JsonValue.optString(json, 'button.primary.background');
        result.buttonPrimaryActive = JsonValue.optString(json, 'button.primary.active.background');
        result.buttonPrimaryForeground = JsonValue.optString(json, 'button.primary.foreground');
        result.buttonPrimaryHover = JsonValue.optString(json, 'button.primary.hover.background');
        result.buttonSecondary = JsonValue.optString(json, 'button.secondary.background');
        result.buttonSecondaryActive = JsonValue.optString(json, 'button.secondary.active.background');
        result.buttonSecondaryForeground = JsonValue.optString(json, 'button.secondary.foreground');
        result.buttonSecondaryHover = JsonValue.optString(json, 'button.secondary.hover.background');
        result.buttonSuccess = JsonValue.optString(json, 'button.success.background');
        result.buttonSuccessActive = JsonValue.optString(json, 'button.success.active.background');
        result.buttonSuccessForeground = JsonValue.optString(json, 'button.success.foreground');
        result.buttonSuccessHover = JsonValue.optString(json, 'button.success.hover.background');
        result.buttonWarning = JsonValue.optString(json, 'button.warning.background');
        result.buttonWarningActive = JsonValue.optString(json, 'button.warning.active.background');
        result.buttonWarningForeground = JsonValue.optString(json, 'button.warning.foreground');
        result.buttonWarningHover = JsonValue.optString(json, 'button.warning.hover.background');
        result.groupBox = JsonValue.optString(json, 'group_box.background');
        result.groupBoxForeground = JsonValue.optString(json, 'group_box.foreground');
        result.groupBoxTitleForeground = JsonValue.optString(json, 'group_box.title.foreground');
        result.caret = JsonValue.optString(json, 'caret');
        result.chart1 = JsonValue.optString(json, 'chart.1');
        result.chart2 = JsonValue.optString(json, 'chart.2');
        result.chart3 = JsonValue.optString(json, 'chart.3');
        result.chart4 = JsonValue.optString(json, 'chart.4');
        result.chart5 = JsonValue.optString(json, 'chart.5');
        result.chartBullish = JsonValue.optString(json, 'chart.bullish');
        result.chartBearish = JsonValue.optString(json, 'chart.bearish');
        result.chartGrid = JsonValue.optString(json, 'chart.grid');
        result.danger = JsonValue.optString(json, 'danger.background');
        result.dangerActive = JsonValue.optString(json, 'danger.active.background');
        result.dangerForeground = JsonValue.optString(json, 'danger.foreground');
        result.dangerHover = JsonValue.optString(json, 'danger.hover.background');
        result.descriptionListLabel = JsonValue.optString(json, 'description_list.label.background');
        result.descriptionListLabelForeground = JsonValue.optString(json, 'description_list.label.foreground');
        result.dragBorder = JsonValue.optString(json, 'drag.border');
        result.dropTarget = JsonValue.optString(json, 'drop_target.background');
        result.foreground = JsonValue.optString(json, 'foreground');
        result.info = JsonValue.optString(json, 'info.background');
        result.infoActive = JsonValue.optString(json, 'info.active.background');
        result.infoForeground = JsonValue.optString(json, 'info.foreground');
        result.infoHover = JsonValue.optString(json, 'info.hover.background');
        result.input = JsonValue.optString(json, 'input.border');
        result.link = JsonValue.optString(json, 'link');
        result.linkActive = JsonValue.optString(json, 'link.active');
        result.linkHover = JsonValue.optString(json, 'link.hover');
        result.list = JsonValue.optString(json, 'list.background');
        result.listActive = JsonValue.optString(json, 'list.active.background');
        result.listActiveBorder = JsonValue.optString(json, 'list.active.border');
        result.listEven = JsonValue.optString(json, 'list.even.background');
        result.listHead = JsonValue.optString(json, 'list.head.background');
        result.listHover = JsonValue.optString(json, 'list.hover.background');
        result.muted = JsonValue.optString(json, 'muted.background');
        result.mutedForeground = JsonValue.optString(json, 'muted.foreground');
        result.popover = JsonValue.optString(json, 'popover.background');
        result.popoverForeground = JsonValue.optString(json, 'popover.foreground');
        result.primary = JsonValue.optString(json, 'primary.background');
        result.primaryActive = JsonValue.optString(json, 'primary.active.background');
        result.primaryForeground = JsonValue.optString(json, 'primary.foreground');
        result.primaryHover = JsonValue.optString(json, 'primary.hover.background');
        result.progressBar = JsonValue.optString(json, 'progress.bar.background');
        result.ring = JsonValue.optString(json, 'ring');
        result.scrollbar = JsonValue.optString(json, 'scrollbar.background');
        result.scrollbarThumb = JsonValue.optString(json, 'scrollbar.thumb.background');
        result.scrollbarThumbHover = JsonValue.optString(json, 'scrollbar.thumb.hover.background');
        result.secondary = JsonValue.optString(json, 'secondary.background');
        result.secondaryActive = JsonValue.optString(json, 'secondary.active.background');
        result.secondaryForeground = JsonValue.optString(json, 'secondary.foreground');
        result.secondaryHover = JsonValue.optString(json, 'secondary.hover.background');
        result.selection = JsonValue.optString(json, 'selection.background');
        result.sidebar = JsonValue.optString(json, 'sidebar.background');
        result.sidebarAccent = JsonValue.optString(json, 'sidebar.accent.background');
        result.sidebarAccentForeground = JsonValue.optString(json, 'sidebar.accent.foreground');
        result.sidebarBorder = JsonValue.optString(json, 'sidebar.border');
        result.sidebarForeground = JsonValue.optString(json, 'sidebar.foreground');
        result.sidebarPrimary = JsonValue.optString(json, 'sidebar.primary.background');
        result.sidebarPrimaryForeground = JsonValue.optString(json, 'sidebar.primary.foreground');
        result.skeleton = JsonValue.optString(json, 'skeleton.background');
        result.sliderBar = JsonValue.optString(json, 'slider.background');
        result.sliderThumb = JsonValue.optString(json, 'slider.thumb.background');
        result.success = JsonValue.optString(json, 'success.background');
        result.successForeground = JsonValue.optString(json, 'success.foreground');
        result.successHover = JsonValue.optString(json, 'success.hover.background');
        result.successActive = JsonValue.optString(json, 'success.active.background');
        result.switch_ = JsonValue.optString(json, 'switch.background');
        result.switchThumb = JsonValue.optString(json, 'switch.thumb.background');
        result.tab = JsonValue.optString(json, 'tab.background');
        result.tabActive = JsonValue.optString(json, 'tab.active.background');
        result.tabActiveForeground = JsonValue.optString(json, 'tab.active.foreground');
        result.tabBar = JsonValue.optString(json, 'tab_bar.background');
        result.tabBarSegmented = JsonValue.optString(json, 'tab_bar.segmented.background');
        result.tabForeground = JsonValue.optString(json, 'tab.foreground');
        result.table = JsonValue.optString(json, 'table.background');
        result.tableActive = JsonValue.optString(json, 'table.active.background');
        result.tableActiveBorder = JsonValue.optString(json, 'table.active.border');
        result.tableEven = JsonValue.optString(json, 'table.even.background');
        result.tableHead = JsonValue.optString(json, 'table.head.background');
        result.tableHeadForeground = JsonValue.optString(json, 'table.head.foreground');
        result.tableFoot = JsonValue.optString(json, 'table.foot.background');
        result.tableFootForeground = JsonValue.optString(json, 'table.foot.foreground');
        result.tableHover = JsonValue.optString(json, 'table.hover.background');
        result.tableRowBorder = JsonValue.optString(json, 'table.row.border');
        result.titleBar = JsonValue.optString(json, 'title_bar.background');
        result.titleBarBorder = JsonValue.optString(json, 'title_bar.border');
        result.statusBar = JsonValue.optString(json, 'status_bar.background');
        result.statusBarBorder = JsonValue.optString(json, 'status_bar.border');
        result.warning = JsonValue.optString(json, 'warning.background');
        result.warningActive = JsonValue.optString(json, 'warning.active.background');
        result.warningHover = JsonValue.optString(json, 'warning.hover.background');
        result.warningForeground = JsonValue.optString(json, 'warning.foreground');
        result.overlay = JsonValue.optString(json, 'overlay');
        result.windowBorder = JsonValue.optString(json, 'window.border');
        result.blue = JsonValue.optString(json, 'base.blue');
        result.blueLight = JsonValue.optString(json, 'base.blue.light');
        result.cyan = JsonValue.optString(json, 'base.cyan');
        result.cyanLight = JsonValue.optString(json, 'base.cyan.light');
        result.green = JsonValue.optString(json, 'base.green');
        result.greenLight = JsonValue.optString(json, 'base.green.light');
        result.magenta = JsonValue.optString(json, 'base.magenta');
        result.magentaLight = JsonValue.optString(json, 'base.magenta.light');
        result.red = JsonValue.optString(json, 'base.red');
        result.redLight = JsonValue.optString(json, 'base.red.light');
        result.yellow = JsonValue.optString(json, 'base.yellow');
        result.yellowLight = JsonValue.optString(json, 'base.yellow.light');
        return result;

    }

    /**
     * Writes the values back to a JSON object (absent values are `null`).
     */
    public function toJson():Dynamic {

        final json:Dynamic = {};
        Reflect.setField(json, 'accent.background', accent);
        Reflect.setField(json, 'accent.foreground', accentForeground);
        Reflect.setField(json, 'accordion.background', accordion);
        Reflect.setField(json, 'background', background);
        Reflect.setField(json, 'border', border);
        Reflect.setField(json, 'button.background', button);
        Reflect.setField(json, 'button.active.background', buttonActive);
        Reflect.setField(json, 'button.foreground', buttonForeground);
        Reflect.setField(json, 'button.hover.background', buttonHover);
        Reflect.setField(json, 'button.danger.background', buttonDanger);
        Reflect.setField(json, 'button.danger.active.background', buttonDangerActive);
        Reflect.setField(json, 'button.danger.foreground', buttonDangerForeground);
        Reflect.setField(json, 'button.danger.hover.background', buttonDangerHover);
        Reflect.setField(json, 'button.info.background', buttonInfo);
        Reflect.setField(json, 'button.info.active.background', buttonInfoActive);
        Reflect.setField(json, 'button.info.foreground', buttonInfoForeground);
        Reflect.setField(json, 'button.info.hover.background', buttonInfoHover);
        Reflect.setField(json, 'button.primary.background', buttonPrimary);
        Reflect.setField(json, 'button.primary.active.background', buttonPrimaryActive);
        Reflect.setField(json, 'button.primary.foreground', buttonPrimaryForeground);
        Reflect.setField(json, 'button.primary.hover.background', buttonPrimaryHover);
        Reflect.setField(json, 'button.secondary.background', buttonSecondary);
        Reflect.setField(json, 'button.secondary.active.background', buttonSecondaryActive);
        Reflect.setField(json, 'button.secondary.foreground', buttonSecondaryForeground);
        Reflect.setField(json, 'button.secondary.hover.background', buttonSecondaryHover);
        Reflect.setField(json, 'button.success.background', buttonSuccess);
        Reflect.setField(json, 'button.success.active.background', buttonSuccessActive);
        Reflect.setField(json, 'button.success.foreground', buttonSuccessForeground);
        Reflect.setField(json, 'button.success.hover.background', buttonSuccessHover);
        Reflect.setField(json, 'button.warning.background', buttonWarning);
        Reflect.setField(json, 'button.warning.active.background', buttonWarningActive);
        Reflect.setField(json, 'button.warning.foreground', buttonWarningForeground);
        Reflect.setField(json, 'button.warning.hover.background', buttonWarningHover);
        Reflect.setField(json, 'group_box.background', groupBox);
        Reflect.setField(json, 'group_box.foreground', groupBoxForeground);
        Reflect.setField(json, 'group_box.title.foreground', groupBoxTitleForeground);
        Reflect.setField(json, 'caret', caret);
        Reflect.setField(json, 'chart.1', chart1);
        Reflect.setField(json, 'chart.2', chart2);
        Reflect.setField(json, 'chart.3', chart3);
        Reflect.setField(json, 'chart.4', chart4);
        Reflect.setField(json, 'chart.5', chart5);
        Reflect.setField(json, 'chart.bullish', chartBullish);
        Reflect.setField(json, 'chart.bearish', chartBearish);
        Reflect.setField(json, 'chart.grid', chartGrid);
        Reflect.setField(json, 'danger.background', danger);
        Reflect.setField(json, 'danger.active.background', dangerActive);
        Reflect.setField(json, 'danger.foreground', dangerForeground);
        Reflect.setField(json, 'danger.hover.background', dangerHover);
        Reflect.setField(json, 'description_list.label.background', descriptionListLabel);
        Reflect.setField(json, 'description_list.label.foreground', descriptionListLabelForeground);
        Reflect.setField(json, 'drag.border', dragBorder);
        Reflect.setField(json, 'drop_target.background', dropTarget);
        Reflect.setField(json, 'foreground', foreground);
        Reflect.setField(json, 'info.background', info);
        Reflect.setField(json, 'info.active.background', infoActive);
        Reflect.setField(json, 'info.foreground', infoForeground);
        Reflect.setField(json, 'info.hover.background', infoHover);
        Reflect.setField(json, 'input.border', input);
        Reflect.setField(json, 'link', link);
        Reflect.setField(json, 'link.active', linkActive);
        Reflect.setField(json, 'link.hover', linkHover);
        Reflect.setField(json, 'list.background', list);
        Reflect.setField(json, 'list.active.background', listActive);
        Reflect.setField(json, 'list.active.border', listActiveBorder);
        Reflect.setField(json, 'list.even.background', listEven);
        Reflect.setField(json, 'list.head.background', listHead);
        Reflect.setField(json, 'list.hover.background', listHover);
        Reflect.setField(json, 'muted.background', muted);
        Reflect.setField(json, 'muted.foreground', mutedForeground);
        Reflect.setField(json, 'popover.background', popover);
        Reflect.setField(json, 'popover.foreground', popoverForeground);
        Reflect.setField(json, 'primary.background', primary);
        Reflect.setField(json, 'primary.active.background', primaryActive);
        Reflect.setField(json, 'primary.foreground', primaryForeground);
        Reflect.setField(json, 'primary.hover.background', primaryHover);
        Reflect.setField(json, 'progress.bar.background', progressBar);
        Reflect.setField(json, 'ring', ring);
        Reflect.setField(json, 'scrollbar.background', scrollbar);
        Reflect.setField(json, 'scrollbar.thumb.background', scrollbarThumb);
        Reflect.setField(json, 'scrollbar.thumb.hover.background', scrollbarThumbHover);
        Reflect.setField(json, 'secondary.background', secondary);
        Reflect.setField(json, 'secondary.active.background', secondaryActive);
        Reflect.setField(json, 'secondary.foreground', secondaryForeground);
        Reflect.setField(json, 'secondary.hover.background', secondaryHover);
        Reflect.setField(json, 'selection.background', selection);
        Reflect.setField(json, 'sidebar.background', sidebar);
        Reflect.setField(json, 'sidebar.accent.background', sidebarAccent);
        Reflect.setField(json, 'sidebar.accent.foreground', sidebarAccentForeground);
        Reflect.setField(json, 'sidebar.border', sidebarBorder);
        Reflect.setField(json, 'sidebar.foreground', sidebarForeground);
        Reflect.setField(json, 'sidebar.primary.background', sidebarPrimary);
        Reflect.setField(json, 'sidebar.primary.foreground', sidebarPrimaryForeground);
        Reflect.setField(json, 'skeleton.background', skeleton);
        Reflect.setField(json, 'slider.background', sliderBar);
        Reflect.setField(json, 'slider.thumb.background', sliderThumb);
        Reflect.setField(json, 'success.background', success);
        Reflect.setField(json, 'success.foreground', successForeground);
        Reflect.setField(json, 'success.hover.background', successHover);
        Reflect.setField(json, 'success.active.background', successActive);
        Reflect.setField(json, 'switch.background', switch_);
        Reflect.setField(json, 'switch.thumb.background', switchThumb);
        Reflect.setField(json, 'tab.background', tab);
        Reflect.setField(json, 'tab.active.background', tabActive);
        Reflect.setField(json, 'tab.active.foreground', tabActiveForeground);
        Reflect.setField(json, 'tab_bar.background', tabBar);
        Reflect.setField(json, 'tab_bar.segmented.background', tabBarSegmented);
        Reflect.setField(json, 'tab.foreground', tabForeground);
        Reflect.setField(json, 'table.background', table);
        Reflect.setField(json, 'table.active.background', tableActive);
        Reflect.setField(json, 'table.active.border', tableActiveBorder);
        Reflect.setField(json, 'table.even.background', tableEven);
        Reflect.setField(json, 'table.head.background', tableHead);
        Reflect.setField(json, 'table.head.foreground', tableHeadForeground);
        Reflect.setField(json, 'table.foot.background', tableFoot);
        Reflect.setField(json, 'table.foot.foreground', tableFootForeground);
        Reflect.setField(json, 'table.hover.background', tableHover);
        Reflect.setField(json, 'table.row.border', tableRowBorder);
        Reflect.setField(json, 'title_bar.background', titleBar);
        Reflect.setField(json, 'title_bar.border', titleBarBorder);
        Reflect.setField(json, 'status_bar.background', statusBar);
        Reflect.setField(json, 'status_bar.border', statusBarBorder);
        Reflect.setField(json, 'warning.background', warning);
        Reflect.setField(json, 'warning.active.background', warningActive);
        Reflect.setField(json, 'warning.hover.background', warningHover);
        Reflect.setField(json, 'warning.foreground', warningForeground);
        Reflect.setField(json, 'overlay', overlay);
        Reflect.setField(json, 'window.border', windowBorder);
        Reflect.setField(json, 'base.blue', blue);
        Reflect.setField(json, 'base.blue.light', blueLight);
        Reflect.setField(json, 'base.cyan', cyan);
        Reflect.setField(json, 'base.cyan.light', cyanLight);
        Reflect.setField(json, 'base.green', green);
        Reflect.setField(json, 'base.green.light', greenLight);
        Reflect.setField(json, 'base.magenta', magenta);
        Reflect.setField(json, 'base.magenta.light', magentaLight);
        Reflect.setField(json, 'base.red', red);
        Reflect.setField(json, 'base.red.light', redLight);
        Reflect.setField(json, 'base.yellow', yellow);
        Reflect.setField(json, 'base.yellow.light', yellowLight);
        return json;

    }

}
