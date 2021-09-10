package elements;

import ceramic.EditText;
import ceramic.SelectText;
import ceramic.Shortcuts.*;
import ceramic.TextView;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;

class BaseTextFieldView extends FieldView {

/// Hooks

    public dynamic function setTextValue(field:BaseTextFieldView, textValue:String):Void {

        this.textValue = textValue;
        setValue(field, textValue);

    }

    public dynamic function setValue(field:BaseTextFieldView, value:Dynamic):Void {

        // Default implementation does nothing

    }

    public dynamic function setEmptyValue(field:BaseTextFieldView):Void {

        // Default implementation does nothing

    }

/// Public properties

    @observe public var textValue:String = '';

/// Internal properties

    var textView:TextView;

    var editText:EditText;

/// Internal

    function updateFromEditText(text:String) {

        var selectText:SelectText = cast textView.text.component('selectText');
        var prevText = this.textValue;
        var prevSelectionStart = selectText.selectionStart;
        var prevSelectionEnd = selectText.selectionEnd;

        setTextValue(this, text);

        var sanitizedText = this.textValue;

        var prevBefore = prevText.substring(0, prevSelectionStart - 1);
        var sanitizedBefore = sanitizedText.substring(0, prevSelectionStart - 1);

        if (prevSelectionStart == prevSelectionEnd
            && text.length == prevText.length + 1
            && sanitizedText.length > text.length
            && prevBefore == sanitizedBefore) {
            // Last character typed has been replaced by something longer
            // Update selection accordingly
            app.oncePostFlushImmediate(function() {
                if (destroyed)
                    return;
                var selectionStart = selectText.selectionStart;
                var diff = sanitizedText.length - prevText.length;
                var prevAfter = prevText.substring(selectionStart, prevText.length);
                var sanitizedAfter = sanitizedText.substring(selectionStart + diff, sanitizedText.length);
                if (prevAfter == sanitizedAfter) {
                    selectText.selectionStart = prevSelectionStart + diff;
                    selectText.selectionEnd = selectText.selectionStart;
                }
            });
        }

    }

    function updateFromTextValue() {

        var displayedText = textValue;

        unobserve();

        if (editText != null)
            editText.updateText(displayedText);

        textView.content = displayedText;

        reobserve();

    }

}
