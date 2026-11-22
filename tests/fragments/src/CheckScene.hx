package;

import ceramic.Fragment;
import ceramic.Scene;

/**
 * A scene that takes its content from `assets/checks.fragments`.
 */
class CheckScene extends Scene {

    public var menu:Fragment = null;

    public var menuWasReady:Bool = false;

    public var card:Fragment = null;

    public var missing:Fragment = null;

    override function preload() {

        preloadFragment('checks', 'menu');

    }

    override function create() {

        menu = loadFragment('menu');
        menuWasReady = menu != null && menu.ready;
        card = loadFragment('card', 'checks');
        missing = loadFragment('card', 'nope');

    }

}
