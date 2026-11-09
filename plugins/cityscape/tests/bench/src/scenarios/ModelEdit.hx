package scenarios;

import cityscape.Cityscape;
import cityscape.common.model.TextModel;

/**
 * 1000 single character edits per frame (`applyEdits`, no undo) at pseudo
 * random positions of a 10 000 line model, insertions and deletions
 * alternating so that the size stays stable.
 */
class ModelEdit implements Scenario {

    public var name:String = 'model-edit';

    var model:TextModel;

    final bench = new ModelBench();

    public function new() {}

    public function setup():Void {
        model = ModelBench.createModel(ModelBench.createText(), new Cityscape());
    }

    public function step(frame:Int):Void {
        for (i in 0...1000) {
            model.applyEdits([bench.randomEdit(model, i % 2 == 0)]);
        }
    }

    public function teardown():Void {
        model.dispose();
    }

}
