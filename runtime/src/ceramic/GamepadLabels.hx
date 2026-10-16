package ceramic;

/**
 * The labels printed on the buttons of a gamepad, to show the right ones to the player.
 *
 * `GamepadButton` is positional on every backend (`A` is the bottom face button), so the
 * same `GamepadButton` is printed differently depending on the gamepad: the bottom face
 * button is `A` on Xbox, Cross on PlayStation, and `B` on Nintendo.
 *
 * Resolved from the name of the gamepad when it is enabled, see `Input.gamepadLabels()`.
 */
enum abstract GamepadLabels(Int) from Int to Int {

    /**
     * A gamepad of no known family. Its labels are usually laid out like Xbox ones.
     */
    var GENERIC = 0;

    /**
     * Xbox labels: A at the bottom, B on the right, X on the left, Y at the top.
     */
    var XBOX = 1;

    /**
     * PlayStation symbols: Cross at the bottom, Circle on the right, Square on the left,
     * Triangle at the top.
     */
    var PLAYSTATION = 2;

    /**
     * Nintendo labels: B at the bottom, A on the right, Y on the left, X at the top
     * (also printed this way on Retroid Pocket handhelds).
     */
    var NINTENDO = 3;

    /**
     * Steam Deck: Xbox labels on Valve's own button shapes.
     */
    var STEAM_DECK = 4;

    /**
     * The labels of a gamepad from its name, as given by the backend: SDL name on native,
     * `Gamepad.id` (with its vendor id) on web, display name on Unity.
     */
    public static function fromGamepadName(name:String):GamepadLabels {

        if (name == null) return GENERIC;
        final lower = name.toLowerCase();
        inline function has(part:String):Bool {
            return lower.indexOf(part) != -1;
        }

        // Steam Deck first (Valve vendor id 28de), then Xbox and Nintendo: "Xbox Wireless
        // Controller" would otherwise match the generic "wireless controller" name of
        // PlayStation gamepads
        if (has('steam deck') || has('steamdeck') || has('28de')) {
            return STEAM_DECK;
        }
        if (has('xbox') || has('xinput') || has('045e')) {
            return XBOX;
        }
        if (has('nintendo') || has('switch') || has('pro controller') || has('joy-con') || has('057e')
            || has('retroid pocket')) {
            return NINTENDO;
        }
        if (has('playstation') || has('ps4') || has('ps5') || has('dualshock') || has('dualsense')
            || has('054c') || has('wireless controller')) {
            return PLAYSTATION;
        }
        return GENERIC;

    }

    inline function toString():String {

        return switch (cast this:GamepadLabels) {
            case GENERIC: 'GENERIC';
            case XBOX: 'XBOX';
            case PLAYSTATION: 'PLAYSTATION';
            case NINTENDO: 'NINTENDO';
            case STEAM_DECK: 'STEAM_DECK';
            case _: '$this';
        }

    }

}
