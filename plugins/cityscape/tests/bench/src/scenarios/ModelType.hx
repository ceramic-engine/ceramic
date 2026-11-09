package scenarios;

import cityscape.Cityscape;
import cityscape.common.model.TextModel;

/**
 * Typing: 1000 single character edits per frame through
 * `pushEditOperations` (undo stack, events), a stack element closed every
 * 10 edits like word boundaries; the undo stack is cleared at the start of
 * each frame.
 */
class ModelType implements Scenario {

    public var name:String = 'model-type';

    var model:TextModel;

    final context = new Cityscape();

    final bench = new ModelBench();

    public function new() {}

    public function setup():Void {
        model = ModelBench.createModel(ModelBench.createText(), context);
    }

    public function step(frame:Int):Void {
        context.undoRedoService.removeElements(model.uri);
        for (i in 0...1000) {
            model.pushEditOperations([], [bench.randomEdit(model, i % 2 == 0)], _ -> null);
            if (i % 10 == 9) {
                model.pushStackElement();
            }
        }
    }

    public function teardown():Void {
        model.dispose();
    }

}
