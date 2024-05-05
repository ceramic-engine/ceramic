package elements;

import ceramic.Color;
import ceramic.Equal;
import ceramic.Filter;
import ceramic.Flags;
import ceramic.Pool;
import ceramic.Shortcuts.*;
import ceramic.View;
import ceramic.ViewSize;
import ceramic.Visual;
import elements.Context.context;
import elements.TextFieldView;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;

using StringTools;
using ceramic.Extensions;
using elements.WindowItem.WindowItemExtensions;

/**
 * A simple class to hold window item data.
 * The same class is used for every window item kind so
 * that it's easier to recycle it and avoid allocating
 * too much data at every frame.
 */
class WindowItem {

    static var pool = new Pool<WindowItem>();

    public static function get():WindowItem {

        var item = pool.get();
        if (item == null) {
            item = new WindowItem();
        }
        return item;

    }

    public var kind:WindowItemKind = UNKNOWN;

    public var previous:WindowItem = null;

    public var theme:Theme = null;

    public var int0:Int = 0;

    public var int1:Int = 0;

    public var int2:Int = 0;

    public var int3:Int = 0;

    public var labelPosition:Int = 0;

    public var disabled:Bool = false;

    public var flex:Int = 1;

    public var float0:Float = 0;

    public var float1:Float = 0;

    public var labelWidth:Float = 0;

    public var float3:Float = 0;

    public var float4:Float = 0;

    public var bool0:Bool = false;

    public var bool1:Bool = false;

    public var bool2:Bool = false;

    public var bool3:Bool = false;

    public var string0:String = null;

    public var string1:String = null;

    public var string2:String = null;

    public var string3:String = null;

    public var string4:String = null;

    public var any0:Any = null;

    public var any1:Any = null;

    public var any2:Any = null;

    public var any3:Any = null;

    public var any4:Any = null;

    public var any5:Any = null;

    public var visual:Visual = null;

    public var intArray0:Array<Int> = null;

    public var stringArray0:Array<String> = null;

    public var stringArray1:Array<String> = null;

    public var anyArray0:Array<Any> = null;

    public var row:Int = -1;

    public function new() {}

    inline public function hasManagedVisual():Bool {

        return kind == VISUAL && int0 > 0 && visual != null;

    }

    public function isSameItem(item:WindowItem):Bool {

        if (item == null)
            return false;

        if (item.kind != kind)
            return false;

        if (item.row != row)
            return false;

        switch kind {

            case UNKNOWN:
                return false;

            case SELECT:
                if (isSimilarLabel(item) &&
                    (item.stringArray0 == stringArray0 || Equal.arrayEqual(item.stringArray0, stringArray0))) {
                    return true;
                }
                else {
                    return false;
                }

            case EDIT_TEXT:
                return isSimilarLabel(item);

            case EDIT_FLOAT:
                return isSimilarLabel(item);

            case EDIT_INT:
                return isSimilarLabel(item);

            case EDIT_COLOR:
                return isSimilarLabel(item);

            #if plugin_dialogs

            case EDIT_DIR:
                return isSimilarLabel(item);

            case EDIT_FILE:
                return isSimilarLabel(item);

            #end

            case SLIDE_FLOAT:
                return isSimilarLabel(item);

            case SLIDE_INT:
                return isSimilarLabel(item);

            case TEXT:
                return true;

            case VISUAL:
                return isSimilarLabel(item) && item.visual == visual;

            case BUTTON:
                return true;

            case SPACE:
                return true;

            case SEPARATOR:
                return true;

            case CHECK:
                return isSimilarLabel(item);

            case LIST:
                return isSimilarLabel(item);

            case TABS:
                return true;

        }

    }

    inline function isSimilarLabel(item:WindowItem):Bool {

        return ((item.string2 != null && string2 != null) || (item.string2 == null && string2 == null));

    }

    public function updateView(view:View):View {

        view = switch kind {

            case UNKNOWN:
                view;

            case SELECT:
                createOrUpdateSelectField(view);

            case EDIT_TEXT | EDIT_FLOAT | EDIT_INT:
                createOrUpdateEditTextField(view);

            #if plugin_dialogs

            case EDIT_DIR | EDIT_FILE:
                createOrUpdateEditTextField(view);

            #end

            case EDIT_COLOR:
                createOrUpdateColorField(view);

            case SLIDE_FLOAT | SLIDE_INT:
                createOrUpdateSliderField(view);

            case TEXT:
                createOrUpdateText(view);

            case BUTTON:
                createOrUpdateButton(view);

            case SPACE:
                createOrUpdateSpace(view);

            case SEPARATOR:
                createOrUpdateSeparator(view);

            case VISUAL:
                createOrUpdateVisualContainer(view);

            case CHECK:
                createOrUpdateBooleanField(view);

            case LIST:
                createOrUpdateList(view);

            case TABS:
                createOrUpdateTabs(view);

        }

        if (view != null) {
            view.flex = flex;
        }

        return view;

    }

    public function recycle() {

        kind = UNKNOWN;
        previous = null;
        int0 = 0;
        int1 = 0;
        int2 = 0;
        int3 = 0;
        labelPosition = 0;
        disabled = false;
        theme = null;
        flex = 1;
        float0 = 0;
        float1 = 0;
        labelWidth = 0;
        float3 = 0;
        float4 = 0;
        bool0 = false;
        bool1 = false;
        bool2 = false;
        bool3 = false;
        string0 = null;
        string1 = null;
        string2 = null;
        string3 = null;
        string4 = null;
        any0 = null;
        any1 = null;
        any2 = null;
        any3 = null;
        any4 = null;
        any5 = null;
        intArray0 = null;
        stringArray0 = null;
        stringArray1 = null;
        anyArray0 = null;
        if (visual != null && visual.parent == null) {
            visual.active = false;
        }
        visual = null;
        row = -1;

        pool.recycle(this);

    }

    function createOrUpdateSpace(view:View):View {

        if (view == null) {
            view = new View();
            view.transparent = true;
        }

        view.viewHeight = float0;
        view.viewWidth = ViewSize.fill();

        return view;

    }

    function createOrUpdateSeparator(view:View):View {

        var separator:Separator;
        if (view != null) {
            separator = cast view;
        }
        else {
            separator = new Separator();
        }

        separator.theme = theme;
        separator.viewHeight = float0;
        separator.viewWidth = ViewSize.fill();

        return separator;

    }

    function createOrUpdateVisualContainer(view:View):View {

        var container:VisualContainerView = null;
        var labeled:LabeledView<VisualContainerView> = null;
        var justCreated = false;
        if (string2 != null) {
            labeled = (view != null ? cast view : null);
            if (labeled == null) {
                justCreated = true;
                container = new VisualContainerView();
                labeled = new LabeledView(container);
            }
            else {
                container = labeled.view;
            }
            labeled.label = string2;
            labeled.labelPosition = labelPosition;
            labeled.labelWidth = labelWidth;
            switch labeled.labelPosition {
                case LEFT: container.contentAlign = LEFT;
                case RIGHT: container.contentAlign = RIGHT;
            }
        }
        else {
            container = view != null ? cast view : null;
            if (container == null) {
                justCreated = true;
                container = new VisualContainerView();
            }
            container.contentAlign = CENTER;
        }

        if (justCreated) {
            container.transparent = true;
            container.destroyVisualOnRemove = false;
        }

        visual.active = true;
        container.visual = visual;

        if (bool1) {
            if (container.filter == null) {
                container.filter = new Filter();
            }
            container.filter.density = screen.nativeDensity;
        }
        else {
            if (container.filter != null) {
                container.filter = null;
            }
        }

        var scaleToFit = bool0;
        if (labeled != null) {
            labeled.viewWidth = ViewSize.fill();
            if (scaleToFit) {
                container.viewWidth = ViewSize.fill();
            }
            else {
                container.viewWidth = visual.width;
            }
        }
        else {
            if (scaleToFit) {
                container.viewWidth = ViewSize.fill();
            }
            else {
                container.viewWidth = visual.width;
            }
        }

        return labeled != null ? labeled : container;

    }

    function createOrUpdateSelectField(view:View):View {

        var field:SelectFieldView = null;
        var labeled:LabeledView<SelectFieldView> = null;
        var justCreated = false;
        if (string2 != null) {
            labeled = (view != null ? cast view : null);
            if (labeled == null) {
                justCreated = true;
                field = new SelectFieldView();
                labeled = new LabeledView(field);
            }
            else {
                field = labeled.view;
            }
            labeled.label = string2;
            labeled.labelPosition = labelPosition;
            labeled.labelWidth = labelWidth;
            labeled.theme = theme;
            switch labeled.labelPosition {
                case LEFT: field.align = LEFT;
                case RIGHT: field.align = RIGHT;
            }
        }
        else {
            field = (view != null ? cast view : null);
            if (field == null) {
                justCreated = true;
                field = new SelectFieldView();
            }
        }
        field.data = this;
        field.list = stringArray0;
        field.nullValueText = string1;
        field.theme = theme;
        if (justCreated) {
            field.setValue = _selectSetIntValue;
        }
        var newValue = stringArray0[int0];
        if (newValue != field.value) {
            field.value = newValue;
        }

        if (labeled != null) {
            labeled.viewWidth = ViewSize.fill();
        }
        field.viewWidth = ViewSize.fill();

        return labeled != null ? labeled : field;

    }

    function createOrUpdateBooleanField(view:View):View {

        var field:BooleanFieldView = null;
        var labeled:LabeledView<BooleanFieldView> = null;
        var justCreated = false;
        if (string2 != null) {
            labeled = (view != null ? cast view : null);
            if (labeled == null) {
                justCreated = true;
                field = new BooleanFieldView();
                labeled = new LabeledView(field);
            }
            else {
                field = labeled.view;
            }
            field.viewWidth = ceramic.ViewSize.auto();
            labeled.label = string2;
            labeled.labelPosition = labelPosition;
            labeled.labelWidth = labelWidth;
            labeled.theme = theme;
        }
        else {
            field = (view != null ? cast view : null);
            if (field == null) {
                justCreated = true;
                field = new BooleanFieldView();
            }
        }
        field.data = this;
        field.theme = theme;
        var intValue = field.value ? 1 : 0;
        if (intValue != int0) {
            field.value = int0 != 0 ? true : false;
        }
        if (justCreated) {
            field.onValueChange(null, function(value, prevValue) {
                field.windowItem().int1 = value ? 1 : 0;
            });
        }

        field.disabled = disabled;

        if (labeled != null) {
            labeled.viewWidth = ViewSize.fill();
        }
        else {
            field.viewWidth = ViewSize.fill();
        }

        return labeled != null ? labeled : field;

    }

    static function _selectSetIntValue(field:SelectFieldView, value:String):Void {

        final item = field.windowItem();
        final index = field.list.indexOf(value);
        item.int1 = index;

    }

    function createOrUpdateColorField(view:View):View {

        var field:ColorFieldView = null;
        var labeled:LabeledView<ColorFieldView> = null;
        var justCreated = false;
        if (string2 != null) {
            labeled = (view != null ? cast view : null);
            if (labeled == null) {
                justCreated = true;
                field = new ColorFieldView();
                labeled = new LabeledView(field);
            }
            else {
                field = labeled.view;
            }
            labeled.label = string2;
            labeled.labelPosition = labelPosition;
            labeled.labelWidth = labelWidth;
            labeled.theme = theme;
        }
        else {
            field = (view != null ? cast view : null);
            if (field == null) {
                justCreated = true;
                field = new ColorFieldView();
            }
        }

        var previous = field.windowItem();
        field.data = this;
        field.theme = theme;

        if (justCreated) {
            field.setValue = _editColorSetValue;
        }
        if (justCreated || previous.int1 != int0) {
            field.value = int0;
        }

        field.disabled = disabled;

        if (labeled != null) {
            labeled.viewWidth = ViewSize.fill();
        }
        field.viewWidth = ViewSize.fill();

        return labeled != null ? labeled : field;

    }

    static function _editColorSetValue(field:ColorFieldView, value:Color):Void {

        field.value = value;
        field.windowItem().int1 = value;

    }

    function createOrUpdateEditTextField(view:View):View {

        var textFieldKind:TextFieldKind = switch kind {
            default: TEXT;
            case EDIT_INT | EDIT_FLOAT: TEXT;
            #if plugin_dialogs
            case EDIT_DIR: DIR(string3 != null ? string3 : string2);
            case EDIT_FILE: FILE(string3 != null ? string3 : string2, any0);
            #end
        }

        var field:TextFieldView = null;
        var labeled:LabeledView<TextFieldView> = null;
        var justCreated = false;
        if (string2 != null) {
            labeled = (view != null ? cast view : null);
            if (labeled == null) {
                justCreated = true;
                field = new TextFieldView(textFieldKind);
                labeled = new LabeledView(field);
            }
            else {
                field = labeled.view;
            }
            labeled.label = string2;
            labeled.labelPosition = labelPosition;
            labeled.labelWidth = labelWidth;
            labeled.theme = theme;
        }
        else {
            field = (view != null ? cast view : null);
            if (field == null) {
                justCreated = true;
                field = new TextFieldView(textFieldKind);
            }
        }

        var previous = field.windowItem();
        field.data = this;
        field.theme = theme;

        if (kind == EDIT_TEXT) {
            if (justCreated) {
                field.setValue = _editTextSetValue;
                field.submit = _editTextSubmit;
                field.onFocusedChange(null, (focused, prevFocused) -> {
                    if (prevFocused && !focused)
                        _editTextBlur(field);
                });
                if (bool2) {
                    Im._beginFrameCallbacks.push(() -> {
                        if (!field.destroyed)
                            field.focus();
                    });
                }
            }
            if (string0 != field.textValue) {
                field.textValue = string0;
            }
            field.multiline = bool0;
            field.placeholder = string3;
            field.autocompleteCandidates = stringArray0;
            field.autocompleteOnFocus = bool3;
        }
        else if (kind == EDIT_FLOAT) {
            if (justCreated) {
                field.setTextValue = _editFloatSetTextValue;
                field.setEmptyValue = _editFloatSetEmptyValue;
                field.setValue = _editFloatSetValue;
                field.onFocusedChange(null, (focused, _) -> {
                    if (!focused)
                        _editFloatFinishEditing(field);
                });
            }
            if (justCreated || previous.float1 != float0) {
                field.textValue = '' + float0;
            }
            field.placeholder = string3;
        }
        else if (kind == EDIT_INT) {
            if (justCreated) {
                field.setTextValue = _editIntSetTextValue;
                field.setEmptyValue = _editIntSetEmptyValue;
                field.setValue = _editIntSetValue;
                field.onFocusedChange(null, (focused, _) -> {
                    if (!focused)
                        _editIntFinishEditing(field);
                });
            }
            if (justCreated || previous.int1 != int0) {
                field.textValue = '' + int0;
            }
            field.placeholder = string3;
        }
        #if plugin_dialogs
        else if (kind == EDIT_DIR || kind == EDIT_FILE) {
            if (justCreated) {
                field.setValue = _editTextSetValue;
            }
            if (string0 != field.textValue) {
                field.textValue = string0;
            }
            field.multiline = bool0;
            field.placeholder = string3;
        }
        #end

        field.disabled = disabled;

        if (labeled != null) {
            labeled.viewWidth = ViewSize.fill();
        }
        field.viewWidth = ViewSize.fill();

        return labeled != null ? labeled : field;

    }

    static function _editTextSetValue(field:BaseTextFieldView, value:String):Void {

        field.windowItem().string1 = value;

    }

    static function _editTextSubmit(field:BaseTextFieldView):Void {

        field.windowItem().bool1 = true;

    }

    static function _editTextBlur(field:BaseTextFieldView):Void {

        field.windowItem().bool3 = true;

    }

    static function _editFloatSetTextValue(field:BaseTextFieldView, textValue:String):Void {

        if (!_editFloatOrIntOperations(field, textValue)) {
            var item = field.windowItem();
            var minValue = -999999999; // Allow lower value at this stage because we are typing
            var maxValue = item.float4;
            var round = item.int0;
            SanitizeTextField.setTextValueToFloat(field, textValue, minValue, maxValue, round, false);
        }

    }

    static function _editFloatSetEmptyValue(field:BaseTextFieldView):Void {

        final item = field.windowItem();
        var minValue = item.float3;
        var maxValue = item.float4;
        var round = item.int0;
        item.float1 = SanitizeTextField.setEmptyToFloat(field, minValue, maxValue, round);

    }

    static function _editFloatSetValue(field:BaseTextFieldView, value:Dynamic):Void {

        final item = field.windowItem();
        var minValue = item.float3;
        var maxValue = item.float4;
        var floatValue:Float = value;
        if (value >= minValue && value <= maxValue) {
            item.float1 = floatValue;
        }

    }

    static function _editFloatFinishEditing(field:BaseTextFieldView):Void {

        var item = field.windowItem();
        var minValue = item.float3;
        var maxValue = item.float4;
        var round = item.int0;
        if (!SanitizeTextField.applyFloatOrIntOperationsIfNeeded(field, field.textValue, minValue, maxValue, false, round)) {
            SanitizeTextField.setTextValueToFloat(field, field.textValue, minValue, maxValue, round, true);
        }

    }

    static function _editIntSetTextValue(field:BaseTextFieldView, textValue:String):Void {

        if (!_editFloatOrIntOperations(field, textValue)) {
            var item = field.windowItem();
            var minValue = -999999999; // Allow lower value at this stage because we are typing
            var maxValue = Std.int(item.float4);
            SanitizeTextField.setTextValueToInt(field, textValue, minValue, maxValue);
        }

    }

    static function _editIntSetEmptyValue(field:BaseTextFieldView):Void {

        final item = field.windowItem();
        var minValue = Std.int(item.float3);
        var maxValue = Std.int(item.float4);
        item.int1 = SanitizeTextField.setEmptyToInt(field, minValue, maxValue);

    }

    static function _editIntSetValue(field:BaseTextFieldView, value:Dynamic):Void {

        final item = field.windowItem();
        var minValue = item.float3;
        var maxValue = item.float4;
        var intValue:Int = value;
        if (value >= minValue && value <= maxValue) {
            item.int1 = intValue;
        }

    }

    static function _editIntFinishEditing(field:BaseTextFieldView):Void {

        var item = field.windowItem();
        var minValue = Std.int(item.float3);
        var maxValue = Std.int(item.float4);
        if (!SanitizeTextField.applyFloatOrIntOperationsIfNeeded(field, field.textValue, minValue, maxValue, true, 0)) {
            SanitizeTextField.setTextValueToInt(field, field.textValue, minValue, maxValue);
        }

    }

    static function _editFloatOrIntOperations(field:BaseTextFieldView, textValue:String):Bool {

        // TODO move this somewhere else?

        var addIndex = textValue.indexOf('+');
        var subtractIndex = textValue.indexOf('-');
        var multiplyIndex = textValue.indexOf('*');
        var divideIndex = textValue.indexOf('/');
        if (addIndex > 0 && !(subtractIndex > 0 || multiplyIndex > 0 || divideIndex > 0)) {
            field.textValue = textValue.trim();
            if (textValue != field.textValue)
                field.invalidateTextValue();
            return true;
        }
        if (subtractIndex > 0 && !(addIndex > 0 || multiplyIndex > 0 || divideIndex > 0)) {
            field.textValue = textValue.trim();
            if (textValue != field.textValue)
                field.invalidateTextValue();
            return true;
        }
        if (multiplyIndex > 0 && !(addIndex > 0 || subtractIndex > 0 || divideIndex > 0)) {
            field.textValue = textValue.trim();
            if (textValue != field.textValue)
                field.invalidateTextValue();
            return true;
        }
        if (divideIndex > 0 && !(addIndex > 0 || multiplyIndex > 0 || subtractIndex > 0)) {
            field.textValue = textValue.trim();
            if (textValue != field.textValue)
                field.invalidateTextValue();
            return true;
        }

        return false;

    }

    function createOrUpdateSliderField(view:View):View {

        var field:SliderFieldView = null;
        var labeled:LabeledView<SliderFieldView> = null;
        var justCreated = false;
        if (string2 != null) {
            labeled = (view != null ? cast view : null);
            if (labeled == null) {
                justCreated = true;
                field = new SliderFieldView();
                labeled = new LabeledView(field);
            }
            else {
                field = labeled.view;
            }
            labeled.label = string2;
            labeled.labelPosition = labelPosition;
            labeled.labelWidth = labelWidth;
            labeled.theme = theme;
        }
        else {
            field = (view != null ? cast view : null);
            if (field == null) {
                justCreated = true;
                field = new SliderFieldView();
            }
        }

        var previous = field.windowItem();
        field.data = this;
        field.theme = theme;

        if (kind == SLIDE_FLOAT) {

            field.minValue = float3;
            field.maxValue = float4;
            field.round = int0;

            if (justCreated) {
                field.setTextValue = _editFloatSetTextValue;
                field.setEmptyValue = _editFloatSetEmptyValue;
                field.setValue = _slideFloatSetValue;
                field.onFocusedChange(null, (focused, _) -> {
                    if (!focused)
                        _editFloatFinishEditing(field);
                });
            }
            if (justCreated || previous.float1 != float0) {
                field.value = float0;
            }
        }
        else if (kind == SLIDE_INT) {

            field.minValue = float3;
            field.maxValue = float4;
            field.round = 1;

            if (justCreated) {
                field.setTextValue = _editIntSetTextValue;
                field.setEmptyValue = _editIntSetEmptyValue;
                field.setValue = _slideIntSetValue;
                field.onFocusedChange(null, (focused, _) -> {
                    if (!focused)
                        _editIntFinishEditing(field);
                });
            }
            if (justCreated || previous.int1 != int0) {
                field.value = int0;
            }
        }

        field.disabled = disabled;

        if (labeled != null) {
            labeled.viewWidth = ViewSize.fill();
        }
        field.viewWidth = ViewSize.fill();

        return labeled != null ? labeled : field;

    }

    static function _slideFloatSetValue(field:BaseTextFieldView, value:Float):Void {

        final item = field.windowItem();
        var sliderField:SliderFieldView = cast field;
        var minValue = item.float3;
        var maxValue = item.float4;
        var floatValue:Float = value;
        if (value >= minValue && value <= maxValue) {
            item.float1 = floatValue;
            var valueDidChange = (sliderField.value != value);
            sliderField.value = value;
        }

    }

    static function _slideIntSetValue(field:BaseTextFieldView, value:Float):Void {

        final item = field.windowItem();
        var sliderField:SliderFieldView = cast field;
        var minValue = item.float3;
        var maxValue = item.float4;
        var floatValue:Float = Math.round(value);
        if (value >= minValue && value <= maxValue) {
            item.int1 = Std.int(floatValue);
            var valueDidChange = (sliderField.value != value);
            sliderField.value = value;
        }

    }

    function createOrUpdateText(view:View):View {

        var text:LabelView = (view != null ? cast view : null);
        if (text == null) {
            text = new LabelView();
        }
        if (text.content != string0) {
            text.content = string0;
        }
        text.align = switch int0 {
            default: LEFT;
            case 1: RIGHT;
            case 2: CENTER;
        };
        text.disabled = disabled;
        text.viewWidth = ViewSize.fill();
        text.theme = theme;
        text.bold = bool0;
        text.pointSize = int2;
        text.preRenderedSize = int3;
        return text;

    }

    function createOrUpdateButton(view:View):View {

        var button:Button = (view != null ? cast view : null);
        var justCreated = false;
        if (button == null) {
            justCreated = true;
            button = new Button();
        }
        if (button.content != string0) {
            button.content = string0;
        }
        if (button.enabled != bool0) {
            button.enabled = bool0;
        }
        button.data = this;
        if (justCreated) {
            button.onClick(null, function() {
                var windowItem:WindowItem = button.hasData ? button.data : null;
                if (windowItem != null) {
                    windowItem._buttonClick();
                }
            });
        }
        button.disabled = disabled;
        button.viewWidth = ViewSize.fill();
        button.theme = theme;
        return button;

    }

    function _buttonClick():Void {

        int1 = 1;

    }

    function createOrUpdateList(view:View):View {

        var list:ListView = (view != null ? cast view : null);
        var justCreated = false;
        if (list == null) {
            justCreated = true;
            list = new ListView(any0);
        }
        var flags:Flags = int2;
        list.sortable = flags.bool(0);
        list.lockable = flags.bool(1);
        list.trashable = flags.bool(2);
        list.duplicable = flags.bool(3);
        list.smallItems = flags.bool(4);
        list.items = any0;
        list.data = this;
        list.selectedIndex = int0;
        list.theme = theme;
        if (justCreated) {
            list.onSelectedIndexChange(null, (selectedIndex, _) -> {
                var windowItem:WindowItem = list.hasData ? list.data : null;
                if (windowItem != null) {
                    windowItem.int1 = selectedIndex;
                }
            });
            list.onMoveItemAboveItem(null, (itemIndex, otherItemIndex) -> {
                var items = list.items;
                var newItems = [];
                var selectedIndex = list.selectedIndex;
                var newSelectedIndex = selectedIndex;
                for (i in 0...items.length) {
                    if (i != itemIndex) {
                        if (selectedIndex == i) {
                            newSelectedIndex = newItems.length;
                        }
                        newItems.push(items[i]);
                        if (i == otherItemIndex) {
                            if (selectedIndex == itemIndex) {
                                newSelectedIndex = newItems.length;
                            }
                            newItems.push(items[itemIndex]);
                        }
                    }
                }
                list.selectedIndex = newSelectedIndex;
                list.items = newItems;
                var windowItem:WindowItem = list.hasData ? list.data : null;
                if (windowItem != null) {
                    windowItem.any1 = newItems;
                }
            });
            list.onMoveItemBelowItem(null, (itemIndex, otherItemIndex) -> {
                var items = list.items;
                var newItems = [];
                var selectedIndex = list.selectedIndex;
                var newSelectedIndex = selectedIndex;
                for (i in 0...items.length) {
                    if (i != itemIndex) {
                        if (i == otherItemIndex) {
                            if (selectedIndex == itemIndex) {
                                newSelectedIndex = newItems.length;
                            }
                            newItems.push(items[itemIndex]);
                        }
                        if (selectedIndex == i) {
                            newSelectedIndex = newItems.length;
                        }
                        newItems.push(items[i]);
                    }
                }
                list.selectedIndex = newSelectedIndex;
                list.items = newItems;
                var windowItem:WindowItem = list.hasData ? list.data : null;
                if (windowItem != null) {
                    windowItem.any1 = newItems;
                }
            });
            list.onTrashItem(null, itemIndex -> {
                var items = list.items;
                var trashed = items[itemIndex];
                var newItems = [];
                var selectedIndex = list.selectedIndex;
                var newSelectedIndex = selectedIndex;
                if (selectedIndex == itemIndex) {
                    newSelectedIndex = -1;
                }
                else if (selectedIndex > itemIndex) {
                    newSelectedIndex = newSelectedIndex - 1;
                }
                for (i in 0...items.length) {
                    if (i != itemIndex) {
                        newItems.push(items[i]);
                    }
                }
                list.selectedIndex = newSelectedIndex;
                list.items = newItems;
                var windowItem:WindowItem = list.hasData ? list.data : null;
                if (windowItem != null) {
                    windowItem.any1 = newItems;
                    var trashedList:Array<Dynamic> = windowItem.any2;
                    if (trashedList == null) {
                        trashedList = [];
                        windowItem.any2 = trashedList;
                    }
                    trashedList.push(trashed);
                }
            });
            list.onLockItem(null, itemIndex -> {
                var items = list.items;
                var locked = items[itemIndex];
                var newItems = [];
                for (i in 0...items.length) {
                    if (i != itemIndex) {
                        newItems.push(items[i]);
                    }
                }
                var windowItem:WindowItem = list.hasData ? list.data : null;
                if (windowItem != null) {
                    var justLockedList:Array<Dynamic> = windowItem.any3;
                    if (justLockedList == null) {
                        justLockedList = [];
                        windowItem.any3 = justLockedList;
                    }
                    justLockedList.push(locked);
                }
            });
            list.onUnlockItem(null, itemIndex -> {
                var items = list.items;
                var locked = items[itemIndex];
                var newItems = [];
                for (i in 0...items.length) {
                    if (i != itemIndex) {
                        newItems.push(items[i]);
                    }
                }
                var windowItem:WindowItem = list.hasData ? list.data : null;
                if (windowItem != null) {
                    var justUnlockedList:Array<Dynamic> = windowItem.any4;
                    if (justUnlockedList == null) {
                        justUnlockedList = [];
                        windowItem.any4 = justUnlockedList;
                    }
                    justUnlockedList.push(locked);
                }
            });
            list.onDuplicateItem(null, itemIndex -> {
                var items = list.items;
                var toDuplicate = items[itemIndex];
                var windowItem:WindowItem = list.hasData ? list.data : null;
                if (windowItem != null) {
                    var toDuplicateList:Array<Dynamic> = windowItem.any5;
                    if (toDuplicateList == null) {
                        toDuplicateList = [];
                        windowItem.any5 = toDuplicateList;
                    }
                    toDuplicateList.push(toDuplicate);
                }
            });
        }
        list.viewWidth = ViewSize.fill();
        if (float0 > 0) {
            list.viewHeight = float0;
            list.scrollEnabled = true;
        }
        else {
            final itemSize = list.smallItems ? ListView.CELL_HEIGHT_SMALL : ListView.CELL_HEIGHT_LARGE;
            list.viewHeight = list.items.length * itemSize;
            list.scrollEnabled = false;
        }
        return list;

    }

    function createOrUpdateTabs(view:View):View {

        var tabs:TabsLayout = (view != null ? cast view : null);
        var justCreated = false;
        if (tabs == null) {
            justCreated = true;
            tabs = new TabsLayout();
        }

        tabs.data = this;

        if (!Equal.equal(tabs.tabs, stringArray1)) {
            tabs.tabs = stringArray1;
        }
        if (!Equal.equal(tabs.tabStates, intArray0)) {
            tabs.tabStates = cast intArray0;
        }
        if (!Equal.equal(tabs.tabThemes, anyArray0)) {
            tabs.tabThemes = cast anyArray0;
        }
        tabs.selectedIndex = stringArray0.indexOf(string0);
        tabs.marginX = theme.formPadding;
        tabs.marginY = theme.tabsMarginY;

        if (justCreated) {

            tabs.onSelectedIndexChange(null, (index, prevIndex) -> {
                var windowItem:WindowItem = tabs.hasData ? tabs.data : null;
                if (windowItem != null) {
                    if (index >= 0) {
                        windowItem.string1 = windowItem.stringArray0[index];
                    }
                    else {
                        windowItem.string1 = null;
                    }
                }
            });
        }

        tabs.viewWidth = ViewSize.fill();
        tabs.theme = theme;

        return tabs;

    }

}

private class WindowItemExtensions {

    inline public static function windowItem(field:FieldView):WindowItem {
        return field.hasData ? field.data : null;
    }

}
