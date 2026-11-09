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

        // Every rendered view line is checked against its rendering input:
        // a line the view events left valid must not have changed
        // (`RenderCacheCheckTest`, registered last, reads the count)
        cityscape.view.CityscapeView.checkRenderCache = true;

        final runner = new TestRunner();
        Tests.register(runner);
        runner.runAndExit();

    }

}
