package elements;

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

class SelectFieldView extends FieldView {

    static var _point = new Point();

    static final MAX_LIST_HEIGHT = 200;

    static final ITEM_HEIGHT = SelectListView.ITEM_HEIGHT;

/// Hooks

    public dynamic function setValue(field:SelectFieldView, value:String):Void {

        // Default implementation does nothing

    }

/// Public properties

    @observe public var value:String = null;

    @observe public var list:ReadOnlyArray<String> = [];

    @observe public var nullValueText:String = null;

    @observe public var inputStyle:InputStyle = DEFAULT;

/// Internal properties

    @observe var listVisible:Bool = false;

    var container:RowLayout;

    var textView:TextView;

    var listView:SelectListView;

    var listContainer:View;

    var tip:Line;

    var listIsAbove:Bool = false;

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
        textView.viewSize(fill(), auto());
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

    override function focus() {

        super.focus();

        /*
        if (!focused) {
            editText.focus();
        }
        */

    }

    override function didLostFocus() {

        //

    }

/// Layout

    override function layout() {

        super.layout();

        /*
        listView.pos(0, container.height);
        listView.size(width, 100);
        */

    }

    function layoutContainer() {

        //

    }

    function layoutListContainer() {

        if (listView != null) {

            listView.size(
                container.width,
                listHeight()
            );
        }

    }

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

    function updateFromValue() {

        var value = this.value;
        var nullValueText = this.nullValueText;

        unobserve();

        if (value != null) {
            var displayedValue = value.trim().replace("\n", ' ');
            if (displayedValue.length > 20) {
                displayedValue = displayedValue.substr(0, 20) + '...'; // TODO at textview level
            }
            textView.content = displayedValue;
        }
        else {
            textView.content = nullValueText != null ? nullValueText : '';
        }

        setValue(this, value);

        reobserve();

    }

    function updateStyle() {

        var theme = context.theme;

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
            if (scrollingLayout != null) {
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

}
