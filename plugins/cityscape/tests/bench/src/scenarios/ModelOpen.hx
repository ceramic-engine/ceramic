package scenarios;

import cityscape.Cityscape;

/**
 * Builds a 10 000 line model (piece tree builder, text buffer, options)
 * each frame, then disposes it.
 */
class ModelOpen implements Scenario {

    public var name:String = 'model-open';

    var text:String;

    final context = new Cityscape();

    public function new() {}

    public function setup():Void {
        text = ModelBench.createText();
    }

    public function step(frame:Int):Void {
        final model = ModelBench.createModel(text, context);
        if (model.getLineCount() != ModelBench.LINE_COUNT) {
            throw 'unexpected line count';
        }
        model.dispose();
    }

    public function teardown():Void {}

}
