// Ported from vscode src/vs/editor/contrib/snippet/browser/snippetVariables.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.snippet.view;

import cityscape.base.common.Strings;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Selection;
import cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;
import cityscape.contrib.snippet.view.SnippetParser;
import cityscape.contrib.suggest.view.SuggestOvertypingCapturer;

/*
 * The variables of snippets. Not ported: the workspace variables
 * (`WORKSPACE_NAME`, `WORKSPACE_FOLDER`: no workspace service), and the
 * label service of the file variables (`TM_DIRECTORY`, `TM_FILEPATH` and
 * `RELATIVE_FILEPATH` give the file system path of the model's uri).
 */

class CompositeSnippetVariableResolver implements VariableResolver {

    final _delegates:Array<VariableResolver>;

    public function new(delegates:Array<VariableResolver>) {
        this._delegates = delegates;
    }

    public function resolve(variable:Variable):Null<String> {
        for (delegate in this._delegates) {
            final value = delegate.resolve(variable);
            if (value != null) {
                return value;
            }
        }
        return null;
    }
}

class SelectionBasedVariableResolver implements VariableResolver {

    final _model:ITextModel;
    final _selection:Selection;
    final _selectionIdx:Int;
    final _overtypingCapturer:Null<OvertypingCapturer>;

    public function new(model:ITextModel, selection:Selection, selectionIdx:Int, overtypingCapturer:Null<OvertypingCapturer>) {
        this._model = model;
        this._selection = selection;
        this._selectionIdx = selectionIdx;
        this._overtypingCapturer = overtypingCapturer;
    }

    public function resolve(variable:Variable):Null<String> {

        final name = variable.name;

        if (name == 'SELECTION' || name == 'TM_SELECTED_TEXT') {
            var value:Null<String> = this._model.getValueInRange(this._selection);
            if (value == '') {
                value = null;
            }
            var isMultiline = this._selection.startLineNumber != this._selection.endLineNumber;

            // If there was no selected text, try to get last overtyped text
            if (value == null && this._overtypingCapturer != null) {
                final info = this._overtypingCapturer.getLastOvertypedInfo(this._selectionIdx);
                if (info != null) {
                    value = info.value;
                    isMultiline = info.multiline;
                }
            }

            final snippet = variable.snippet;
            if (value != null && value.length > 0 && isMultiline && snippet != null) {
                // Selection is a multiline string which we indentation we now
                // need to adjust. We compare the indentation of this variable
                // with the indentation at the editor position and add potential
                // extra indentation to the value

                final line = this._model.getLineContent(this._selection.startLineNumber);
                final lineLeadingWhitespace = Strings.getLeadingWhitespace(line, 0, this._selection.startColumn - 1);

                var varLeadingWhitespace = lineLeadingWhitespace;
                snippet.walk(marker -> {
                    if (marker == variable) {
                        return false;
                    }
                    if (Std.isOfType(marker, Text)) {
                        final lines = Strings.splitLines((cast marker : Text).value);
                        varLeadingWhitespace = Strings.getLeadingWhitespace(lines[lines.length - 1]);
                    }
                    return true;
                });
                final whitespaceCommonLength = Strings.commonPrefixLength(varLeadingWhitespace, lineLeadingWhitespace);
                final extra = varLeadingWhitespace.substr(whitespaceCommonLength);

                // value.replace(/(\r\n|\r|\n)(.*)/g, (m, newline, rest) => newline + extra + rest)
                final v:String = value;
                final buf = new StringBuf();
                var i = 0;
                while (i < v.length) {
                    final c = StringTools.fastCodeAt(v, i);
                    if (c == '\r'.code && i + 1 < v.length && StringTools.fastCodeAt(v, i + 1) == '\n'.code) {
                        buf.add('\r\n');
                        buf.add(extra);
                        i += 2;
                    }
                    else if (c == '\r'.code || c == '\n'.code) {
                        buf.addChar(c);
                        buf.add(extra);
                        i++;
                    }
                    else {
                        buf.addChar(c);
                        i++;
                    }
                }
                value = buf.toString();
            }
            return value;

        }
        else if (name == 'TM_CURRENT_LINE') {
            return this._model.getLineContent(this._selection.positionLineNumber);

        }
        else if (name == 'TM_CURRENT_WORD') {
            final info = this._model.getWordAtPosition({
                lineNumber: this._selection.positionLineNumber,
                column: this._selection.positionColumn
            });
            return info != null && info.word.length > 0 ? info.word : null;

        }
        else if (name == 'TM_LINE_INDEX') {
            return Std.string(this._selection.positionLineNumber - 1);

        }
        else if (name == 'TM_LINE_NUMBER') {
            return Std.string(this._selection.positionLineNumber);

        }
        else if (name == 'CURSOR_INDEX') {
            return Std.string(this._selectionIdx);

        }
        else if (name == 'CURSOR_NUMBER') {
            return Std.string(this._selectionIdx + 1);
        }
        return null;
    }
}

class ModelBasedVariableResolver implements VariableResolver {

    final _model:ITextModel;

    public function new(model:ITextModel) {
        this._model = model;
    }

    static function basename(path:String):String {
        var end = path.length;
        while (end > 1 && StringTools.fastCodeAt(path, end - 1) == '/'.code) {
            end--;
        }
        final idx = path.lastIndexOf('/', end - 1);
        return path.substring(idx + 1, end);
    }

    static function dirname(path:String):String {
        final idx = path.lastIndexOf('/');
        if (idx < 0) {
            return '.';
        }
        return idx == 0 ? '/' : path.substring(0, idx);
    }

    public function resolve(variable:Variable):Null<String> {

        final name = variable.name;
        final fsPath = this._model.uri.fsPath;

        if (name == 'TM_FILENAME') {
            return basename(fsPath);

        }
        else if (name == 'TM_FILENAME_BASE') {
            final name = basename(fsPath);
            final idx = name.lastIndexOf('.');
            if (idx <= 0) {
                return name;
            }
            else {
                return name.substr(0, idx);
            }

        }
        else if (name == 'TM_DIRECTORY') {
            if (dirname(fsPath) == '.') {
                return '';
            }
            return dirname(fsPath);

        }
        else if (name == 'TM_FILEPATH') {
            return fsPath;
        }
        else if (name == 'RELATIVE_FILEPATH') {
            return fsPath;
        }

        return null;
    }
}

class ClipboardBasedVariableResolver implements VariableResolver {

    final _readClipboardText:() -> Null<String>;
    final _selectionIdx:Int;
    final _selectionCount:Int;
    final _spread:Bool;

    public function new(readClipboardText:() -> Null<String>, selectionIdx:Int, selectionCount:Int, spread:Bool) {
        this._readClipboardText = readClipboardText;
        this._selectionIdx = selectionIdx;
        this._selectionCount = selectionCount;
        this._spread = spread;
    }

    public function resolve(variable:Variable):Null<String> {
        if (variable.name != 'CLIPBOARD') {
            return null;
        }

        final clipboardText = this._readClipboardText();
        if (clipboardText == null || clipboardText.length == 0) {
            return null;
        }

        // `spread` is assigning each cursor a line of the clipboard
        // text whenever there the line count equals the cursor count
        // and when enabled
        if (this._spread) {
            final lines = [for (s in Strings.splitLines(clipboardText)) if (StringTools.trim(s).length > 0) s];
            if (lines.length == this._selectionCount) {
                return lines[this._selectionIdx];
            }
        }
        return clipboardText;
    }
}

class CommentBasedVariableResolver implements VariableResolver {

    final _model:ITextModel;
    final _selection:Selection;
    final _languageConfigurationService:ILanguageConfigurationService;

    public function new(model:ITextModel, selection:Selection, languageConfigurationService:ILanguageConfigurationService) {
        this._model = model;
        this._selection = selection;
        this._languageConfigurationService = languageConfigurationService;
    }

    public function resolve(variable:Variable):Null<String> {
        final name = variable.name;
        final langId = this._model.getLanguageIdAtPosition(this._selection.selectionStartLineNumber, this._selection.selectionStartColumn);
        final config = this._languageConfigurationService.getLanguageConfiguration(langId).comments;
        if (config == null) {
            return null;
        }
        inline function orNull(s:Null<String>):Null<String> {
            return s != null && s.length > 0 ? s : null;
        }
        if (name == 'LINE_COMMENT') {
            return orNull(config.lineCommentToken);
        }
        else if (name == 'BLOCK_COMMENT_START') {
            return orNull(config.blockCommentStartToken);
        }
        else if (name == 'BLOCK_COMMENT_END') {
            return orNull(config.blockCommentEndToken);
        }
        return null;
    }
}

class TimeBasedVariableResolver implements VariableResolver {

    static final dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    static final dayNamesShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    static final monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    static final monthNamesShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    final _date = Date.now();

    public function new() {}

    static function pad2(n:Int):String {
        return n < 10 ? '0' + n : Std.string(n);
    }

    public function resolve(variable:Variable):Null<String> {
        final name = variable.name;

        if (name == 'CURRENT_YEAR') {
            return Std.string(this._date.getFullYear());
        }
        else if (name == 'CURRENT_YEAR_SHORT') {
            final s = Std.string(this._date.getFullYear());
            return s.substr(s.length - 2);
        }
        else if (name == 'CURRENT_MONTH') {
            return pad2(this._date.getMonth() + 1);
        }
        else if (name == 'CURRENT_DATE') {
            return pad2(this._date.getDate());
        }
        else if (name == 'CURRENT_HOUR') {
            return pad2(this._date.getHours());
        }
        else if (name == 'CURRENT_MINUTE') {
            return pad2(this._date.getMinutes());
        }
        else if (name == 'CURRENT_SECOND') {
            return pad2(this._date.getSeconds());
        }
        else if (name == 'CURRENT_DAY_NAME') {
            return dayNames[this._date.getDay()];
        }
        else if (name == 'CURRENT_DAY_NAME_SHORT') {
            return dayNamesShort[this._date.getDay()];
        }
        else if (name == 'CURRENT_MONTH_NAME') {
            return monthNames[this._date.getMonth()];
        }
        else if (name == 'CURRENT_MONTH_NAME_SHORT') {
            return monthNamesShort[this._date.getMonth()];
        }
        else if (name == 'CURRENT_SECONDS_UNIX') {
            return Std.string(Math.floor(this._date.getTime() / 1000));
        }
        else if (name == 'CURRENT_TIMEZONE_OFFSET') {
            // minutes behind UTC, like JavaScript's getTimezoneOffset
            final rawTimeOffset = Math.round((Date.fromString(DateTools.format(this._date, '%Y-%m-%d %H:%M:%S')).getTime() - utcAsLocal(this._date).getTime()) / 60000);
            final sign = rawTimeOffset > 0 ? '-' : '+';
            final hours = Std.int(Math.abs(rawTimeOffset / 60));
            final minutes = Std.int(Math.abs(rawTimeOffset) - hours * 60);
            return sign + pad2(hours) + ':' + pad2(minutes);
        }

        return null;
    }

    static function utcAsLocal(date:Date):Date {
        return new Date(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate(), date.getUTCHours(), date.getUTCMinutes(), date.getUTCSeconds());
    }
}

class RandomBasedVariableResolver implements VariableResolver {

    public function new() {}

    static function randomDigits(radix:Int, count:Int):String {
        final chars = '0123456789abcdef';
        final buf = new StringBuf();
        for (_ in 0...count) {
            buf.addChar(StringTools.fastCodeAt(chars, Std.random(radix)));
        }
        return buf.toString();
    }

    public function resolve(variable:Variable):Null<String> {
        final name = variable.name;

        if (name == 'RANDOM') {
            return randomDigits(10, 6);
        }
        else if (name == 'RANDOM_HEX') {
            return randomDigits(16, 6);
        }
        else if (name == 'UUID') {
            // generateUuid: a version 4 UUID
            final hex = randomDigits(16, 32);
            final variant = '89ab'.charAt(Std.random(4));
            return hex.substr(0, 8) + '-' + hex.substr(8, 4) + '-4' + hex.substr(13, 3) + '-' + variant + hex.substr(17, 3) + '-' + hex.substr(20, 12);
        }

        return null;
    }
}
