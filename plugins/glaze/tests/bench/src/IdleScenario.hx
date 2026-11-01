package;

/**
 * A scenario that, instead of stepping frames, checks that nothing happens
 * while the app is idle: the window is drawn once, its renderable added to
 * the screen, then `idleFrames` ticks of the real update loop must draw
 * nothing and allocate nothing. Only `cachedModes` of `[true]` makes sense.
 */
interface IdleScenario extends Scenario {

    /**
     * Number of update ticks measured (120 in the original bench).
     */
    var idleFrames:Int;

}
