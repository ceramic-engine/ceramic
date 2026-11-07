package;

import ceramic.Entity;
import ceramic.InitSettings;
import testing.TestRunner;

class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.targetWidth = 640;
        settings.targetHeight = 480;

        app.onceReady(this, ready);

    }

    function ready() {

        final runner = new TestRunner();
        Tests.register(runner);
        runner.runAndExit();

    }

}
