package;

import ceramic.Entity;
import ceramic.InitSettings;

/**
 * The smallest possible project: no plugin, no `import.hx` and no import of
 * `ceramic.App` or `ceramic.Shortcuts`, so nothing in the project code decides
 * in which order the core classes are typed. See `check.sh`.
 */
class Project extends Entity {

    function new(settings:InitSettings) {

        super();

        settings.targetWidth = 320;
        settings.targetHeight = 240;

        ceramic.App.app.onceReady(this, ready);

    }

    function ready() {

        ceramic.App.app.logger.info('bare project ready');

        #if (headless && nodejs)
        js.Node.process.exit(0);
        #end

    }

}
