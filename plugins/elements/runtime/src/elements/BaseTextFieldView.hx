package elements;

import ceramic.EditText;
import ceramic.Equal;
import ceramic.Key;
import ceramic.KeyBindings;
import ceramic.KeyCode;
import ceramic.Point;
import ceramic.ScanCode;
import ceramic.SelectText;
import ceramic.Shortcuts.*;
import ceramic.TextView;
import ceramic.Timer;
import ceramic.View;
import elements.Context.context;
import fuzzaldrin.Fuzzaldrin;
import tracker.Autorun.reobserve;
import tracker.Autorun.unobserve;

using StringTools;
using ceramic.Extensions;

class BaseTextFieldView extends FieldView {

    static var _point = new Point(0, 0);

    static final MAX_LIST_HEIGHT = 200;

    static final ITEM_HEIGHT = SelectListView.ITEM_HEIGHT;

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

    public var autocompleteCandidates(default, set):Array<String> = null;

    function set_autocompleteCandidates(autocompleteCandidates:Array<String>):Array<String> {
        if (this.autocompleteCandidates != autocompleteCandidates) {
            this.autocompleteCandidates = autocompleteCandidates;
            if (autocompleteCandidates != null) {
                var processedAutocompleteCandidates = [];
                for (i in 0...autocompleteCandidates.length) {
                    var candidate = autocompleteCandidates.unsafeGet(i);
                    processedAutocompleteCandidates.push({
                        search: transformTextForCompletion(candidate),
                        original: candidate
                    });
                }
                this.processedAutocompleteCandidates = processedAutocompleteCandidates;
            }
            else {
                this.processedAutocompleteCandidates = null;
            }
        }
        return autocompleteCandidates;
    }

    public var autocompleteDelay:Float = 0.01;

    public var autocompleteMaxResults:Int = 10;

    public var clipSuggestions:Bool = false;

/// Lifecycle

    function new() {

        super();

        app.onUpdate(this, _ -> updateSuggestionsVisibility());
        app.onPostUpdate(this, _ -> updateSuggestionsPosition());

        // If the field is put inside a scrolling layout right after being initialized,
        // check its scroll transform to update position instantly (without loosing a frame)
        app.onceUpdate(this, function(_) {
            var scrollingLayout = getScrollingLayout();
            if (scrollingLayout != null) {
                scrollingLayout.scroller.scrollTransform.onChange(this, updateSuggestionsPosition);
            }
        });

    }

    override function didLostFocus() {

        super.didLostFocus();

    }

    override function destroy() {

        super.destroy();

        clearSuggestions();

    }

/// Internal properties

    @component var keyBindings:KeyBindings;

    var textView:TextView;

    var editText:EditText;

    var cancelAutoComplete:Void->Void = null;

    var processedAutocompleteCandidates:Array<{search:String, original:String}> = null;

    var suggestionsView:SelectListView = null;

    var suggestionsContainer:View = null;

    var suggestions:Array<String> = null;

/// Internal

    function updateFromEditText(text:String) {

        if (cancelAutoComplete != null) {
            cancelAutoComplete();
            cancelAutoComplete = null;
        }

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

        if (prevText != text && autocompleteCandidates != null && autocompleteCandidates.length > 0) {
            cancelAutoComplete = Timer.delay(this, autocompleteDelay, () -> {
                updateAutocompleteSuggestions();
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

/// Auto-completion

    function updateAutocompleteSuggestions(force:Bool = false) {

        var textValue = textView.content;

        if (textValue.trim().length > 0) {
            textValue = transformTextForCompletion(textValue);
            var rawSuggestions = Fuzzaldrin.filter(
                processedAutocompleteCandidates, textValue, {
                    maxResults: autocompleteMaxResults,
                    key: 'search'
                }
            );
            suggestions = [];
            for (i in 0...rawSuggestions.length) {
                suggestions.push(rawSuggestions.unsafeGet(i).original);
            }
        }
        else if (force) {
            suggestions = [];
            for (i in 0...processedAutocompleteCandidates.length) {
                suggestions.push(processedAutocompleteCandidates.unsafeGet(i).original);
            }
        }
        else {
            suggestions = null;
        }

        if (suggestions == null || suggestions.length == 0) {
            clearSuggestions();
        }
        else {
            if (suggestionsContainer == null) {
                suggestionsContainer = new View();
                suggestionsContainer.onLayout(this, layoutSuggestionsContainer);
                suggestionsContainer.transparent = true;
                suggestionsContainer.viewSize(0, 0);
                suggestionsContainer.active = true;
                suggestionsContainer.depth = 100;
                context.view.add(suggestionsContainer);
            }
            if (suggestionsView == null) {
                suggestionsView = new SelectListView();

                suggestionsView.autoScrollToValue = true;

                // Update value from suggestions if a new value is selected
                suggestionsView.onValueChange(this, suggestionsValueChange);
                suggestionsView.onValueClick(this, suggestionsValueClick);

                input.onKeyDown(suggestionsView, suggestionsKeyDown);

                suggestionsContainer.add(suggestionsView);
            }

            if (!Equal.equal(suggestionsView.list, suggestions)) {
                suggestionsView.list = suggestions;
            }
        }

    }

    function suggestionsKeyDown(key:Key) {

        if (suggestionsView == null || suggestions == null || suggestions.length == 0)
            return;

        if (key.scanCode == ScanCode.ESCAPE) {
            clearSuggestions();
            focus();
        }
        else if (focused && key.scanCode == ScanCode.DOWN) {
            var list = suggestionsView.list;
            if (list != null) {
                if (suggestionsView.value == null) {
                    if (list.length > 0) {
                        suggestionsView.value = list[0];
                    }
                }
                else if (list.indexOf(suggestionsView.value) < list.length - 1) {
                    suggestionsView.value = list[list.indexOf(suggestionsView.value) + 1];
                }
            }
        }
        else if (focused && key.scanCode == ScanCode.UP) {
            var list = suggestionsView.list;
            if (list != null) {
                if (suggestionsView.value != null && list.indexOf(suggestionsView.value) > 0) {
                    suggestionsView.value = list[list.indexOf(suggestionsView.value) - 1];
                }
            }
        }
        else if (focused && key.scanCode == ScanCode.ENTER) {
            if (suggestionsView.value == null) {
                suggestionsView.value = suggestions[0];
            }
            app.oncePostFlushImmediate(function() {
                clearSuggestions();
                app.oncePostFlushImmediate(function() {
                    focus();
                });
            });
        }

    }

    function suggestionsValueChange(value:String, prevValue:String):Void {

        if (editText != null) {
            editText.updateText(value);
            editText.selectText.selectionStart = value.length;
            editText.selectText.selectionEnd = value.length;
        }
        textView.content = value;
        setTextValue(this, value);
        focus();

    }

    function suggestionsValueClick(value:String):Void {

        clearSuggestions();
        focus();

    }

    function layoutSuggestionsContainer() {

        if (suggestionsView != null) {

            suggestionsView.size(
                this.width,
                suggestionsHeight()
            );
        }

    }

    function suggestionsHeight() {

        return Math.min(ITEM_HEIGHT * (suggestions != null ? suggestions.length : 0), MAX_LIST_HEIGHT);

    }

    function updateSuggestionsPosition() {

        if (suggestionsContainer == null || !suggestionsContainer.active)
            return;

        var scrollingLayout = getScrollingLayout();
        var container = this;

        container.visualToScreen(
            0,
            container.height,
            _point
        );

        var x = _point.x;
        var y = _point.y;

        context.view.screenToVisual(x, y, _point);
        x = _point.x;
        y = _point.y;

        var listIsAbove = false;

        if (context.view.height - y <= suggestionsHeight()) {
            listIsAbove = true;
            container.visualToScreen(
                0,
                0 - suggestionsHeight(),
                _point
            );

            x = _point.x;
            y = _point.y;

            context.view.screenToVisual(x, y, _point);
            x = _point.x;
            y = _point.y;
        }
        else {
            listIsAbove = false;
        }

        // Clip if needed
        if (clipSuggestions) {
            if (scrollingLayout != null) {
                scrollingLayout.screenToVisual(0, 0, _point);
                context.view.screenToVisual(_point.x, _point.y, _point);
                if (y + _point.y < 0) {
                    suggestionsContainer.clip = scrollingLayout;
                }
                else {
                    suggestionsContainer.clip = null;
                }
            }
            else {
                suggestionsContainer.clip = null;
            }
        }
        else {
            suggestionsContainer.clip = null;
        }

        if (x != suggestionsContainer.x || y != suggestionsContainer.y)
            suggestionsContainer.layoutDirty = true;

        suggestionsContainer.pos(x, y);

    }

    function updateSuggestionsVisibility() {

        if (suggestionsView == null)
            return;

        if (FieldSystem.shared.focusedField == this)
            return;

        var parent = screen.focusedVisual;
        var keepFocus = false;
        while (parent != null) {
            if (parent == suggestionsView) {
                keepFocus = true;
                break;
            }
            parent = parent.parent;
        }

        if (!keepFocus) {
            clearSuggestions();
        }

    }

    function clearSuggestions() {

        if (suggestionsView != null) {
            suggestionsView.destroy();
            suggestionsView = null;
        }
        if (suggestionsContainer != null) {
            suggestionsContainer.destroy();
            suggestionsContainer = null;
        }

    }

    inline static function transformTextForCompletion(text:String):String {

        return text.replace(' ', '_');

    }

/// Key bindings

    function bindKeyBindings() {

        keyBindings = new KeyBindings();

        keyBindings.bind([CMD_OR_CTRL, KEY(KeyCode.KEY_A)], function() {
            if (focused) {
                var selectText:SelectText = cast textView.text.component('selectText');
                selectText.selectionStart = 0;
                selectText.selectionEnd = textView.text.content.length;
            }
        });

        keyBindings.bind([CMD_OR_CTRL, KEY(KeyCode.SPACE)], function() {
            if (focused && autocompleteCandidates != null && autocompleteCandidates.length > 0) {
                trace('autocomplete');
                updateAutocompleteSuggestions(true);
            }
        });

    }

    override function hitsSelfOrDerived(x:Float, y:Float):Bool {

        return hits(x, y) || (suggestionsView != null && suggestionsView.computedVisible && suggestionsView.hits(x, y));

    }

    override function usesScanCode(scanCode:ScanCode):Bool {

        if (super.usesScanCode(scanCode))
            return true;

        if (suggestionsView == null || suggestions == null || suggestions.length == 0)
            return false;

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

        return false;

    }

}
