package ceramic;

class SpineColors {

    public static function extractColors(spine:Spine, slots:Array<String>, ?result:Array<Color>):Array<Color> {

        if (result == null) {
            result = [];
        }

        var funcs = [];

        for (i in 0...slots.length) {
            result[i] = Color.NONE;
            (i -> {

                funcs.push(info -> {
                    result[i] = Color.fromRGBFloat(
                        info.slot.color.r,
                        info.slot.color.g,
                        info.slot.color.b
                    );
                });

                var slot = slots[i];
                spine.onUpdateSlotWithName(null, slot, funcs[i]);

            })(i);
        }

        spine.forceRender();

        for (i in 0...funcs.length) {
            spine.offUpdateSlotWithName(slots[i], funcs[i]);
        }

        return result;

    }

    public static function extractDarkColors(spine:Spine, slots:Array<String>, ?result:Array<Color>):Array<Color> {

        if (result == null) {
            result = [];
        }

        var funcs = [];

        for (i in 0...slots.length) {
            result[i] = Color.NONE;
            (i -> {

                funcs.push(info -> {
                    result[i] = Color.fromRGBFloat(
                        info.slot.darkColor.r,
                        info.slot.darkColor.g,
                        info.slot.darkColor.b
                    );
                });

                var slot = slots[i];
                spine.onUpdateSlotWithName(null, slot, funcs[i]);

            })(i);
        }

        spine.forceRender();

        for (i in 0...funcs.length) {
            spine.offUpdateSlotWithName(slots[i], funcs[i]);
        }

        return result;

    }

}
