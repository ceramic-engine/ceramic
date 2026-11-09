package scenarios;

import cityscape.Cityscape;
import testing.BenchData;
import cityscape.common.model.TextModel;

/**
 * TextMate tokenization of JavaScript with the grammar bundled with Glaze
 * (`javascript.json`) and VS Code's Dark+ theme (the one of the unit tests'
 * TextMate truth), with the pure Haxe Oniguruma on every target (onig.wasm is
 * not loaded here).
 *
 * - `tokenize-js-full`, `tokenize-10k-full`: each frame tokenizes the whole
 *   document again (`resetTokenization` then `forceTokenization` of the last
 *   line), grammar already compiled.
 * - `tokenize-js-edit`, `tokenize-10k-edit`: the document is tokenized once;
 *   each frame types one character at column 8 of the longest line of the
 *   middle of the document, or removes it, and tokenizes until the last line
 *   again: what is retokenized is what Monaco's state store invalidates (the
 *   edited line, and following lines until the end state equals the stored
 *   one).
 *
 * The document is `data/runner-app.js` (a frozen copy of Ceramic's
 * runner/app.js, 541 lines of Node and Electron code); the 10 000 line one
 * repeats it. The model is the real `TextModel` (with its bracket pairs part,
 * like in an editor); `largeFileOptimizations` is on, the default (10 000
 * lines stay under its limits).
 */
class Tokenize implements Scenario {

    public var name:String;

    final lines:Int;

    final edit:Bool;

    var context:Cityscape;

    var model:TextModel;

    var editLine:Int;

    var inserted = false;

    public function new(name:String, lines:Int, edit:Bool) {
        this.name = name;
        this.lines = lines;
        this.edit = edit;
    }

    public static function javascriptContext():Cityscape {
        final context = new Cityscape();
        context.languageService.registerLanguage({id: 'javascript', extensions: ['.js']});
        context.textMate.registerGrammar({languageId: 'javascript', grammar: BenchData.loadGlazeGrammar('javascript.json'), path: 'javascript.json'});
        final truth:Dynamic = haxe.Json.parse(BenchData.load('monaco/textmate-tokens.json'));
        for (theme in (truth.themes : Array<Dynamic>)) {
            if (theme.id == 'dark-plus') {
                context.textMate.setTheme(theme.theme);
            }
        }
        return context;
    }

    public static function documentText(lineCount:Int):String {
        final source = StringTools.replace(BenchData.loadBench('runner-app.js'), '\r\n', '\n').split('\n');
        if (source[source.length - 1] == '') {
            source.pop();
        }
        if (lineCount <= 0) {
            return source.join('\n');
        }
        final result = [];
        var i = 0;
        while (result.length < lineCount) {
            result.push(source[i % source.length]);
            i++;
        }
        return result.join('\n');
    }

    public function setup():Void {
        context = javascriptContext();
        final start = haxe.Timer.stamp();
        model = new TextModel(documentText(lines), 'javascript', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
        model.tokenization.forceTokenization(model.getLineCount());
        final cold = (haxe.Timer.stamp() - start) * 1000;
        println('$name: ${model.getLineCount()} lines, first tokenization (grammar compiled on the way) ${Math.round(cold * 10) / 10} ms');
        // The longest line of the middle of the document
        final middle = Std.int(model.getLineCount() / 2);
        final window = documentText(0).split('\n').length;
        editLine = middle;
        for (line in middle...Std.int(Math.min(model.getLineCount(), middle + window))) {
            if (model.getLineLength(line) > model.getLineLength(editLine)) {
                editLine = line;
            }
        }
        println('$name: typing in line $editLine (${model.getLineLength(editLine)} characters)');
    }

    static function println(message:String):Void {
        #if js
        js.Syntax.code('console.log({0})', message);
        #else
        Sys.println(message);
        #end
    }

    public function step(frame:Int):Void {
        if (!edit) {
            model.tokenization.resetTokenization();
            model.tokenization.forceTokenization(model.getLineCount());
            return;
        }
        final column = 8;
        if (!inserted) {
            model.applyEdits([{range: new cityscape.common.core.Range(editLine, column, editLine, column), text: 'x'}]);
        }
        else {
            model.applyEdits([{range: new cityscape.common.core.Range(editLine, column, editLine, column + 1), text: ''}]);
        }
        inserted = !inserted;
        model.tokenization.forceTokenization(model.getLineCount());
    }

    public function teardown():Void {
        model.dispose();
        context.textMate.dispose();
    }

}
