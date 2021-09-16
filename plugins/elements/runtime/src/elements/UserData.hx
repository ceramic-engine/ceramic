package elements;

import ceramic.Color;
import ceramic.ReadOnlyArray;
import ceramic.ReadOnlyMap;
import ceramic.Shortcuts.*;
import tracker.Model;

class UserData extends Model {

    public function new() {

        super();

    }

/// Windows data

    @serialize public var windowsData:ReadOnlyMap<String,WindowData> = new Map();

/// Colors

    @serialize public var colorPickerHsluv:Bool = false;

    @serialize public var paletteColors:ReadOnlyArray<Color> = [];

    public function addPaletteColor(color:Color, forbidDuplicate:Bool = true):Void {

        var prevPaletteColors = this.paletteColors;

        // Ensure the color is not already listed if needed
        if (forbidDuplicate) {
            for (i in 0...prevPaletteColors.length) {
                if (color == prevPaletteColors[i]) {
                    log.warning('Cannot add color $color in palette because it already exists. Ignoring.');
                    return;
                }
            }
        }

        // Add color
        var paletteColors = [].concat(prevPaletteColors.original);
        paletteColors.push(color);
        this.paletteColors = cast paletteColors;

    }

    public function movePaletteColor(fromIndex:Int, toIndex:Int):Void {

        var paletteColors = [].concat(this.paletteColors.original);

        var colorToMove = paletteColors[fromIndex];

        paletteColors.splice(fromIndex, 1);
        paletteColors.insert(toIndex, colorToMove);

        this.paletteColors = cast paletteColors;

    }

    public function removePaletteColor(index:Int):Void {

        var paletteColors = [].concat(this.paletteColors.original);

        paletteColors.splice(index, 1);

        this.paletteColors = cast paletteColors;

    }


}
