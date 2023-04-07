package elements;

#if plugin_dialogs
import ceramic.Dialogs;
import ceramic.DialogsFileFilter;
#end

import ceramic.Color;
import ceramic.EditText;
import ceramic.KeyBinding;
import ceramic.KeyBindings;
import ceramic.KeyCode;
import ceramic.LayersLayout;
import ceramic.SelectText;
import ceramic.Shortcuts.*;
import ceramic.TextAlign;
import ceramic.TextView;
import elements.Context.context;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;
import tracker.Observable;

using StringTools;

class TextFieldView extends BaseTextFieldView {

    @observe public var theme:Theme = null;

/// Overrides

    override function didLostFocus() {

        super.didLostFocus();

        if (textValue == '' || (kind == NUMERIC && textValue == '-')) {
            setEmptyValue(this);
        }

    }

/// Public properties

    public var multiline(default,set):Bool = false;
    function set_multiline(multiline:Bool):Bool {
        this.multiline = multiline;
        if (editText != null)
            editText.multiline = multiline;
        return multiline;
    }

    @observe public var placeholder:String = '';

    @observe public var inputStyle:InputStyle = DEFAULT;

    @observe public var textAlign:TextAlign = LEFT;

    @observe public var disabled:Bool = false;

/// Internal properties

    var layers:LayersLayout;

    var placeholderView:TextView;

    public var kind(default, null):TextFieldKind;

    public function new(kind:TextFieldKind = TEXT) {

        super();

        this.kind = kind != null ? kind : TEXT;

        padding(6, 6, 6, 6);

        layers = new LayersLayout();
        layers.viewSize(fill(), auto());
        add(layers);

        textView = new TextView();
        textView.minHeight = 15;
        textView.viewSize(fill(), auto());
        textView.verticalAlign = CENTER;
        textView.onResize(this, clipText);
        autorun(() -> {
            textView.align = textAlign;
        });
        textView.pointSize = 12;
        textView.preRenderedSize = 20;
        textView.maxLineDiff = -1;
        layers.add(textView);

        placeholderView = new TextView();
        placeholderView.minHeight = 15;
        placeholderView.viewSize(fill(), auto());
        placeholderView.verticalAlign = CENTER;
        placeholderView.skewX = 10;
        placeholderView.offsetX = 1;
        autorun(() -> {
            placeholderView.align = textAlign;
        });
        placeholderView.pointSize = 12;
        placeholderView.preRenderedSize = 20;
        placeholderView.maxLineDiff = -1;
        layers.add(placeholderView);

        switch kind {
            case TEXT | NUMERIC:
                var theme = this.theme;
                if (theme == null)
                    theme = context.theme;
                editText = new EditText(theme.focusedFieldSelectionColor, theme.lightTextColor);
                editText.container = this;
                textView.text.component('editText', editText);
                editText.onUpdate(this, updateFromEditText);
                editText.onStop(this, handleStopEditText);
                editText.onSubmit(this, handleEditTextSubmit);
            #if plugin_dialogs
            case DIR(title):
                editText = null;
                onPointerDown(this, _ -> {
                    focus();
                    app.onceUpdate(this, _ -> {
                        app.onceUpdate(this, _ -> {
                            Dialogs.openDirectory(title != null ? title : 'Select directory', path -> {
                                trace('Selected directory: $path');
                                if (path != null) {
                                    setTextValue(this, path);
                                }
                            });
                        });
                    });
                });
            case FILE(title, filters):
                editText = null;
                onPointerDown(this, _ -> {
                    focus();
                    app.onceUpdate(this, _ -> {
                        app.onceUpdate(this, _ -> {
                            Dialogs.openFile(title != null ? title : 'Select file', filters, path -> {
                                trace('Selected file: $path');
                                if (path != null) {
                                    setTextValue(this, path);
                                }
                            });
                        });
                    });
                });
            #end
        }

        autorun(updateStyle);
        autorun(updateFromTextValue);
        autorun(updatePlaceholder);

        if (editText != null) {
            onDisabledChange(this, (disabled, _) -> {
                editText.disabled = disabled;
            });
        }

        bindKeyBindings();

    }

/// Public API

    override function focus() {

        super.focus();

        if (!disabled) {
            if (editText != null) {
                editText.focus();
            }
        }

    }

/// Layout

    override function layout() {

        super.layout();

    }

    function clipText(width:Float, height:Float) {

        var text = textView.text;
        text.clipTextX = 0;
        text.clipTextY = 0;
        text.clipTextWidth = width + 2;
        text.clipTextHeight = this.height;

    }

/// Internal

    function handleStopEditText() {

        // Release focus when stopping edition
        if (focused && (suggestions == null || suggestions.length == 0)) {
            screen.focusedVisual = null;
        }

    }

    function updatePlaceholder() {

        var displayedText = textValue;
        var placeholder = this.placeholder;
        var focused = this.focused;

        unobserve();

        placeholderView.content = placeholder != null ? placeholder : '';
        placeholderView.visible = (displayedText == '' && !focused);

        reobserve();

    }

    function updateStyle() {

        var theme = this.theme;
        if (theme == null)
            theme = context.theme;

        if (editText != null) {
            editText.selectionColor = theme.focusedFieldSelectionColor;
            editText.textCursorColor = theme.lightTextColor;
        }

        if (inputStyle == OVERLAY) {
            color = Color.WHITE;
            alpha = 0.1;

            borderSize = 0;
            borderPosition = INSIDE;
            transparent = false;

            textView.textColor = theme.fieldTextColor;
            textView.font = theme.mediumFont;

            placeholderView.textColor = theme.fieldPlaceholderColor;
            placeholderView.font = theme.mediumFont;
        }
        else {
            color = theme.darkBackgroundColor;
            alpha = 1;

            borderSize = 1;
            borderPosition = INSIDE;
            transparent = false;

            textView.textColor = theme.fieldTextColor;
            textView.font = theme.mediumFont;

            placeholderView.textColor = theme.fieldPlaceholderColor;
            placeholderView.font = theme.mediumFont;

            if (disabled) {
                borderColor = theme.mediumBorderColor;
                textView.text.alpha = 0.5;
            }
            else {
                textView.text.alpha = 1;
                if (focused) {
                    borderColor = theme.focusedFieldBorderColor;
                }
                else {
                    borderColor = theme.lightBorderColor;
                }
            }
        }

    }

}

enum TextFieldKind {

    TEXT;

    NUMERIC;

    #if plugin_dialogs

    DIR(?title:String);

    FILE(?title:String, ?filters:Array<DialogsFileFilter>);

    #end

}
