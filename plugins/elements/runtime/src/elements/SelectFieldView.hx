package elements;

import ceramic.KeyCode;
import ceramic.Line;
import ceramic.Point;
import ceramic.ReadOnlyArray;
import ceramic.RowLayout;
import ceramic.ScanCode;
import ceramic.Shortcuts.*;
import ceramic.TextView;
import ceramic.View;
import elements.Context.context;
import elements.FieldView;
import elements.SelectListView;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;
import tracker.Observable;

using StringTools;

/**
 * A dropdown selection field that allows users to choose from a predefined list of options.
 * 
 * SelectFieldView provides a text-based dropdown interface with keyboard navigation support.
 * It displays the currently selected value and shows a dropdown list when activated. The field
 * supports null values, keyboard shortcuts, and intelligent positioning of the dropdown list.
 * 
 * Key features:
 * - Dropdown list with hover and click selection
 * - Keyboard navigation (Arrow keys, Enter, Space, Escape)
 * - Support for null values with custom text
 * - Auto-positioning above/below based on available space
 * - Focus management and escape handling
 * - Clipping support for scrollable containers
 * 
 * Usage example:
 * ```haxe
 * var selectField = new SelectFieldView();
 * selectField.list = ['Option 1', 'Option 2', 'Option 3'];
 * selectField.nullValueText = 'Choose an option...';
 * selectField.value = 'Option 1';
 * selectField.onValueChange(this, (value, prev) -> {
 *     trace('Selected: ' + value);
 * });
 * add(selectField);
 * ```
 */
class SelectFieldView extends FieldView {

    /** Custom theme override for this select field. If null, uses the global context theme */
    @observe public var theme:Theme = null;

    /** Reusable point for coordinate calculations */
    static var _point = new Point();

    /** Maximum height of the dropdown list in pixels */
    static final MAX_LIST_HEIGHT = 200;

    /** Height of each item in the dropdown list */
    static final ITEM_HEIGHT = SelectListView.ITEM_HEIGHT;

/// Hooks

    /**
     * Hook called when the field value changes.
     * 
     * Override this function to implement custom behavior when the value is set.
     * The default implementation does nothing.
     * 
     * @param field The select field instance
     * @param value The new value being set
     */
    public dynamic function setValue(field:SelectFieldView, value:String):Void {

        // Default implementation does nothing

    }

/// Public properties

    /** The currently selected value. Can be null if no value is selected */
    @observe public var value:String = null;

    /** Array of available options to choose from */
    @observe public var list:ReadOnlyArray<String> = [];

    /** Text to display when value is null. If null, empty text is shown */
    @observe public var nullValueText:String = null;

    /** Visual style of the field (DEFAULT, OVERLAY, or MINIMAL) */
    @observe public var inputStyle:InputStyle = DEFAULT;

    /** Whether to clip the dropdown list to scrollable container bounds */
    public var clipList:Bool = false;

/// Internal properties

    /** Whether the dropdown list is currently visible */
    @observe var listVisible:Bool = false;

    /** Container for the field display elements */
    var container:RowLayout;

    /** Text view displaying the current selection */
    var textView:TextView;

    /** The dropdown list view component */
    var listView:SelectListView;

    /** Container for positioning the dropdown list */
    var listContainer:View;

    /** Arrow/triangle indicator showing dropdown availability */
    var tip:Line;

    /** Whether the dropdown list is positioned above the field */
    var listIsAbove:Bool = false;

    /** Tracks if list was visible in the current frame for input handling */
    var listVisibleThisFrame:Bool = false;

    /**
     * Creates a new SelectFieldView.
     * 
     * Sets up the field container, text display, dropdown positioning,
     * keyboard navigation, and all necessary event handlers.
     */
    public function new() {

        super();
        transparent = true;

        direction = HORIZONTAL;
        align = LEFT;

        container = new RowLayout();
        container.viewSize(fill(), auto());
        container.padding(6, 6, 6, 6);
        container.borderSize = 1;
        container.borderPosition = INSIDE;
        container.transparent = false;
        container.depth = 1;
        add(container);

        container.onPointerDown(this, _ -> {
            toggleListVisible();
        });

        listContainer = new View();
        listContainer.transparent = true;
        listContainer.viewSize(0, 0);
        listContainer.active = false;
        listContainer.depth = 100;
        context.view.add(listContainer);

        tip = new Line();
        tip.points = [
            -5, -5,
            0, 0,
            5, -5
        ];
        tip.thickness = 1;
        tip.depth = 2;
        container.onLayout(tip, () -> {
            tip.pos(
                container.x + container.width - 13,
                container.y + container.height * 0.6
            );
        });
        add(tip);

        /*var filler = new View();
        filler.transparent = true;
        filler.viewSize(fill(), fill());
        add(filler);*/

        textView = new TextView();
        textView.minHeight = 15;
        textView.viewSize(auto(), auto());
        textView.align = LEFT;
        textView.verticalAlign = CENTER;
        textView.pointSize = 12;
        textView.preRenderedSize = 20;
        container.add(textView);

        /*
        editText = new EditText();
        editText.container = textView;
        textView.text.component('editText', editText);
        editText.onUpdate(this, updateFromEditText);
        editText.onStop(this, handleStopEditText);
        editText.onSubmit(this, handleEditTextSubmit);
        */

        autorun(updateStyle);
        autorun(updateFromValue);
        autorun(updateListContainer);

        container.onLayout(this, layoutContainer);
        listContainer.onLayout(this, layoutListContainer);

        // Update list view value & list when it changes on the field
        onValueChange(listView, (value, _) -> {
            if (listView != null)
                listView.value = value;
        });
        onListChange(listView, (list, _) -> {
            if (listView != null)
                listView.list = list;
        });
        onNullValueTextChange(listView, (nullValueText, _) -> {
            if (listView != null)
                listView.nullValueText = nullValueText;
        });

        app.onUpdate(this, _ -> updateListVisibility());
        app.onPostUpdate(this, _ -> updateListPosition());
        app.onFinishDraw(this, updateListVisibleThisFrame);

        // If the field is put inside a scrolling layout right after being initialized,
        // check its scroll transform to update position instantly (without loosing a frame)
        app.onceUpdate(this, function(_) {
            var scrollingLayout = getScrollingLayout();
            if (scrollingLayout != null) {
                scrollingLayout.scroller.scrollTransform.onChange(this, updateListPosition);
            }
        });

        // Some keyboard shortcuts
        input.onKeyDown(this, key -> {
            if (key.scanCode == ScanCode.ESCAPE) {
                listVisible = false;
            }
            else if (focused && key.scanCode == ScanCode.DOWN) {
                if (list != null) {
                    if (value == null) {
                        if (list.length > 0) {
                            value = list[0];
                        }
                    }
                    else if (list.indexOf(value) < list.length - 1) {
                        value = list[list.indexOf(value) + 1];
                    }
                }
            }
            else if (focused && key.scanCode == ScanCode.UP) {
                if (list != null) {
                    if (list.indexOf(value) > 0) {
                        value = list[list.indexOf(value) - 1];
                    }
                    else if (nullValueText != null) {
                        value = null;
                    }
                }
            }
            else if (focused && key.scanCode == ScanCode.ENTER) {
                listVisible = true;
            }
            else if (focused && key.scanCode == ScanCode.SPACE) {
                listVisible = !listVisible;
            }
            else if (focused && key.scanCode == ScanCode.BACKSPACE) {
                if (nullValueText != null) {
                    this.value = null;
                }
            }
        });

    }

/// Layout

    /**
     * Handles focus events for the field.
     * 
     * Currently delegates to parent focus behavior. Text editing is disabled
     * for select fields in favor of dropdown selection.
     */
    override function focus() {

        super.focus();

        /*
        if (!focused) {
            editText.focus();
        }
        */

    }

    override function didLostFocus() {

        super.didLostFocus();

    }

/// Layout

    override function layout() {

        super.layout();

        /*
        listView.pos(0, container.height);
        listView.size(width, 100);
        */

    }

    /**
     * Layouts the field container and clips text to fit available space.
     * 
     * Ensures the displayed text doesn't overflow into the dropdown arrow area
     * by clipping it to the available width minus arrow space.
     */
    function layoutContainer() {

        if (textView != null) {
            textView.text.clipText(
                0, 0,
                container.width - textView.text.x - textView.x - container.paddingRight - 20 /* tip width */,
                999999999
            );
        }

    }

    /**
     * Layouts the dropdown list container.
     * 
     * Sizes the list view to match the field width and calculated height
     * based on the number of available options.
     */
    function layoutListContainer() {

        if (listView != null) {

            listView.size(
                container.width,
                listHeight()
            );
        }

    }

    /**
     * Calculates the optimal height for the dropdown list.
     * 
     * @return Height in pixels, limited by MAX_LIST_HEIGHT
     */
    function listHeight() {

        return Math.min(ITEM_HEIGHT * (list.length + (nullValueText != null ? 1 : 0)), MAX_LIST_HEIGHT);

    }

/// Internal

    override function destroy() {

        super.destroy();

        if (listContainer != null) {
            listContainer.destroy();
            listContainer = null;
        }

    }

    /*
    function updateFromEditText(text:String) {

        //

    }

    function handleStopEditText() {

        //

    }
    */

    /**
     * Updates the displayed text based on the current value.
     * 
     * Shows the selected value or the null value text if no value is selected.
     * Sanitizes the display text by trimming whitespace and replacing newlines.
     */
    function updateFromValue() {

        var value = this.value;
        var nullValueText = this.nullValueText;

        unobserve();

        if (value != null) {
            var displayedValue = value.trim().replace("\n", ' ');
            textView.content = displayedValue;
        }
        else {
            textView.content = nullValueText != null ? nullValueText : '';
        }

        setValue(this, value);

        reobserve();

    }

    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        container.color = theme.darkBackgroundColor;

        textView.font = theme.mediumFont;
        if (value == null) {
            textView.textColor = theme.mediumTextColor;
            textView.text.skewX = 8;
        }
        else {
            textView.textColor = theme.fieldTextColor;
            textView.text.skewX = 0;
        }

        if (focused && inputStyle != MINIMAL) {
            tip.color = theme.lightTextColor;
            container.borderColor = theme.focusedFieldBorderColor;
        }
        else {
            tip.color = theme.lighterBorderColor;
            container.borderColor = theme.lightBorderColor;
        }

    }

    /// List

    function updateListVisibility() {

        if (listView == null || !listVisible)
            return;

        if (FieldSystem.shared.focusedField == this)
            return;

        var parent = screen.focusedVisual;
        var keepFocus = false;
        while (parent != null) {
            if (parent == listView) {
                keepFocus = true;
                break;
            }
            parent = parent.parent;
        }

        if (!keepFocus) {
            listVisible = false;
        }

    }

    function updateListPosition() {

        if (!listContainer.active)
            return;


        var scrollingLayout = getScrollingLayout();

        container.visualToScreen(
            0,
            0,
            _point
        );

        var x = _point.x;
        var y = _point.y;

        // if (scrollingLayout != null && scrollingLayout.filter != null && scrollingLayout.filter.enabled) {
        //     scrollingLayout.visualToScreen(0, 0, _point);
        //     x += _point.x;
        //     y += _point.y;
        // }

        context.view.screenToVisual(x, y, _point);
        x = _point.x;
        y = _point.y;

        if (context.view.height - y <= listHeight()) {
            listIsAbove = true;
            container.visualToScreen(
                0,
                container.height - listHeight(),
                _point
            );

            x = _point.x;
            y = _point.y;

            // if (scrollingLayout != null && scrollingLayout.filter != null && scrollingLayout.filter.enabled) {
            //     scrollingLayout.visualToScreen(0, 0, _point);
            //     x += _point.x;
            //     y += _point.y;
            // }

            context.view.screenToVisual(x, y, _point);
            x = _point.x;
            y = _point.y;
        }
        else {
            listIsAbove = false;
        }

        // Clip if needed
        if (listVisible) {
            if (clipList && scrollingLayout != null) {
                scrollingLayout.screenToVisual(0, 0, _point);
                context.view.screenToVisual(_point.x, _point.y, _point);
                if (y + _point.y < 0) {
                    listContainer.clip = scrollingLayout;
                }
                else {
                    listContainer.clip = null;
                }
            }
            else {
                listContainer.clip = null;
            }
        }
        else {
            listContainer.clip = null;
        }

        if (x != listContainer.x || y != listContainer.y)
            listContainer.layoutDirty = true;

        listContainer.pos(x, y);

    }

    function updateListVisibleThisFrame() {

        listVisibleThisFrame = (listView != null && listView.computedVisible);

    }

    /**
     * Toggles the visibility of the dropdown list.
     */
    function toggleListVisible() {

        listVisible = !listVisible;

    }

    function updateListContainer() {

        var listVisible = this.listVisible;
        var value = this.value;

        unobserve();

        if (listVisible) {

            if (listView == null) {
                listView = new SelectListView();
                listView.autorun(() -> {
                    var theme = this.theme;
                    unobserve();
                    listView.theme = theme;
                });
                listView.depth = 10;
                listView.value = this.value;
                listView.list = this.list;
                listView.nullValueText = this.nullValueText;
                listContainer.add(listView);

                // Update value from list view if a new value is selected
                listView.onValueChange(this, (value, _) -> {
                    this.value = value;
                    this.listVisible = false;
                    focus();
                });

                listContainer.active = true;
                updateListPosition();

                listView.scrollToValue(listIsAbove ? END : START);
                app.oncePostFlushImmediate(() -> {
                    if (destroyed || listView == null)
                        return;
                    listView.scrollToValue(listIsAbove ? END : START);
                    app.onceUpdate(listView, _ -> {
                        listView.scrollToValue(listIsAbove ? END : START);
                    });
                });
            }

        }
        else if (!listVisible && listView != null) {

            listView.destroy();
            listView = null;

            listContainer.active = false;
        }

        reobserve();

    }

    override function hitsSelfOrDerived(x:Float, y:Float):Bool {

        return hits(x, y) || (listView != null && listView.computedVisible && listView.hits(x, y));

    }

    override function usesScanCode(scanCode:ScanCode):Bool {

        if (super.usesScanCode(scanCode))
            return true;

        if (!listVisibleThisFrame && (listView == null || !listView.computedVisible)) {
            return false;
        }

        if (scanCode == ScanCode.ESCAPE) {
            return true;
        }
        else if (focused && scanCode == ScanCode.DOWN) {
            return true;
        }
        else if (focused && scanCode == ScanCode.UP) {
            return true;
        }
        else if (focused && scanCode == ScanCode.ENTER) {
            return true;
        }
        else if (focused && scanCode == ScanCode.SPACE) {
            return true;
        }
        else if (focused && scanCode == ScanCode.BACKSPACE) {
            return true;
        }

        return false;

    }

    override function usesKeyCode(keyCode:KeyCode):Bool {

        if (super.usesKeyCode(keyCode))
            return true;

        if (!listVisibleThisFrame && (listView == null || !listView.computedVisible)) {
            return false;
        }

        if (keyCode == KeyCode.ESCAPE) {
            return true;
        }
        else if (focused && keyCode == KeyCode.DOWN) {
            return true;
        }
        else if (focused && keyCode == KeyCode.UP) {
            return true;
        }
        else if (focused && keyCode == KeyCode.ENTER) {
            return true;
        }
        else if (focused && keyCode == KeyCode.SPACE) {
            return true;
        }
        else if (focused && keyCode == KeyCode.BACKSPACE) {
            return true;
        }

        return false;

    }

}
