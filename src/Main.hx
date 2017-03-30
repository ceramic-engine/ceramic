package;

import ceramic.App;
import ceramic.Quad;
import ceramic.Color;

class Main extends ceramic.Main implements ceramic.Shortcuts {

    public static function main() {

        App.init({
            antialiasing: true,
            background: ceramic.Color.CYAN,
            width: 320,
            height: 568,
            scaling: FILL
        },
        function(app) {

            trace("APP READY");

            var quad1 = new Quad();
            quad1.color = Color.RED;
            quad1.depth = 2;
            quad1.size(50, 50);
            quad1.anchor(0.5, 0.5);
            quad1.pos(320 * 0.5, 568 * 0.5);
            quad1.rotation = 30;
            quad1.scale(2.0, 0.5);

            var quad2 = new Quad();
            quad2.depth = 1;
            quad2.color = Color.YELLOW;
            quad2.size(50, 50);
            quad2.anchor(0.5, 0.5);
            quad2.pos(320 * 0.5, 568 * 0.5 + 20);
            quad2.rotation = 30;
            quad2.scale(2.0, 0.5);

            screen.onUpdate(function(delta) {

                quad1.rotation = (quad1.rotation + delta * 100) % 360;
                quad2.rotation = (quad2.rotation + delta * 100) % 360;

            });

        });

    } //main

} //Main
