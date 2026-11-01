package;

import gpui.App;
import gpui.Window;

/**
 * The idle check of the original bench: the cards window (view caching on)
 * is drawn once, then 120 frames of the real update loop must not draw and
 * must not allocate anything (gpui or the renderable). The run fails when
 * they do.
 */
class IdleCardsScenario extends BaseScenario implements IdleScenario {

    public var idleFrames:Int = 120;

    final cards:CardsScenario = new CardsScenario();

    public function new() {
        super('idle');
        cachedModes = [true];
    }

    override function setup(app:App, caching:Bool):Window {
        return cards.setup(app, caching);
    }

}
