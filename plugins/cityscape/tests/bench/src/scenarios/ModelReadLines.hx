package scenarios;

import cityscape.Cityscape;
import cityscape.common.model.TextModel;

/**
 * Reads every line of a 10 000 line model (`getLineContent`) each frame.
 * The model received 2000 random single character edits first, so that
 * its piece tree has many pieces like after an editing session.
 */
class ModelReadLines implements Scenario {

    public var name:String = 'model-read-lines';

    var model:TextModel;

    final bench = new ModelBench();

    public var checksum:Int = 0;

    public function new() {}

    public function setup():Void {
        model = ModelBench.createModel(ModelBench.createText(), new Cityscape());
        for (i in 0...2000) {
            model.applyEdits([bench.randomEdit(model, i % 2 == 0)]);
        }
    }

    public function step(frame:Int):Void {
        var total = 0;
        final lineCount = model.getLineCount();
        for (lineNumber in 1...lineCount + 1) {
            total += model.getLineContent(lineNumber).length;
        }
        checksum = total;
    }

    public function teardown():Void {
        model.dispose();
    }

}
