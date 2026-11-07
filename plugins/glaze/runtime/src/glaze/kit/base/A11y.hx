// Ported from gpui-kit 0.8.1: crates/base/src/a11y_disabled.rs, and the accessibility properties
// (role, aria label, numeric values) Base controls set through GPUI's accesskit API
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base;

/**
 * The accessibility role of an element (the subset of accesskit's roles
 * the ported components use).
 */
enum abstract Role(String) to String {
    var Link = 'link';
    var ListItem = 'listItem';
    var ProgressIndicator = 'progressIndicator';
    var Alert = 'alert';
    var Status = 'status';
    var Dialog = 'dialog';
    var AlertDialog = 'alertDialog';
    var Image = 'image';
    var Button = 'button';
    var CheckBox = 'checkBox';
    var RadioButton = 'radioButton';
    var RadioGroup = 'radioGroup';
    var Switch = 'switch';
    var Slider = 'slider';
    var Toolbar = 'toolbar';
    var Group = 'group';
    var TextInput = 'textInput';
    var MultilineTextInput = 'multilineTextInput';
    var PhoneNumberInput = 'phoneNumberInput';
    var EmailInput = 'emailInput';
    var UrlInput = 'urlInput';
    var PasswordInput = 'passwordInput';
    var DateTimeInput = 'dateTimeInput';
    var DateInput = 'dateInput';
    var SpinButton = 'spinButton';
    var List = 'list';
    var ComboBox = 'comboBox';
    var TimeInput = 'timeInput';
    var Tab = 'tab';
    var TabList = 'tabList';
    var Heading = 'heading';
    var Region = 'region';
    var Navigation = 'navigation';
    var Table = 'table';
    var Grid = 'grid';
    var RowGroup = 'rowGroup';
    var Row = 'row';
    var ColumnHeader = 'columnHeader';
    var Cell = 'cell';
    var GridCell = 'gridCell';
    var Tree = 'tree';
    var TreeItem = 'treeItem';
    var Form = 'form';
}

/**
 * The toggled state of an accessibility node (accesskit's `Toggled`).
 */
enum abstract Toggled(String) to String {
    var False = 'false';
    var True = 'true';
    var Mixed = 'mixed';
}

/**
 * The orientation of an accessibility node (accesskit's `Orientation`).
 */
enum abstract Orientation(String) to String {
    var Horizontal = 'horizontal';
    var Vertical = 'vertical';
}

/**
 * Accessibility properties of a Base element.
 *
 * Glaze has no accessibility tree (no accesskit): the properties a
 * control would export are kept here, as plain data, so applications and
 * tests can read what the control declares (Rust writes them to an
 * `accesskit::Node` in `write_a11y_info`).
 */
class A11y {

    public var role:Null<Role> = null;

    public var label:Null<String> = null;

    public var description:Null<String> = null;

    public var disabled:Bool = false;

    /** Whether the element supports the click action. */
    public var clickable:Bool = false;

    public var numericValue:Null<Float> = null;

    public var minNumericValue:Null<Float> = null;

    public var maxNumericValue:Null<Float> = null;

    public var numericValueStep:Null<Float> = null;

    public var toggled:Null<Toggled> = null;

    public var selected:Null<Bool> = null;

    public var positionInSet:Null<Int> = null;

    public var sizeOfSet:Null<Int> = null;

    public var orientation:Null<Orientation> = null;

    /** Whether the element supports the increment and decrement actions. */
    public var adjustable:Bool = false;

    /** The expanded state of a collapsible control (accesskit's `expanded`). */
    public var expanded:Null<Bool> = null;

    /** The text value of the element (accesskit's `value`). */
    public var value:Null<String> = null;

    /** The heading level (accesskit's `level`, set by `aria_level`). */
    public var level:Null<Int> = null;

    /** The row index of a table row (accesskit's `row_index`, set by `aria_row_index`). */
    public var rowIndex:Null<Int> = null;

    /** The column index of a table cell (accesskit's `column_index`, set by `aria_column_index`). */
    public var columnIndex:Null<Int> = null;

    /** The total number of rows of a table (accesskit's `row_count`, set by `aria_row_count`). */
    public var rowCount:Null<Int> = null;

    /** The total number of columns of a table (accesskit's `column_count`, set by `aria_column_count`). */
    public var columnCount:Null<Int> = null;

    public function new(?role:Role) {
        this.role = role;
    }

}

/**
 * How an element exposes its role: the control's own default, none
 * (presentational), or an explicit role.
 */
enum RoleOverride {
    Implicit;
    Presentational;
    Explicit(role:Role);
}

class RoleOverrideTools {

    /**
     * The resolved role: `defaultRole()` when implicit, null when
     * presentational.
     */
    public static function resolve(self:RoleOverride, defaultRole:() -> Role):Null<Role> {
        return switch self {
            case Implicit: defaultRole();
            case Presentational: null;
            case Explicit(role): role;
        }
    }

}
