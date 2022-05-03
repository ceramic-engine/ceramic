package ceramic;

#if (clay && web && ceramic_native_bridge)
import backend.ElectronRunner;
#end

class Bridge extends Entity {

    @lazy public static var shared = new Bridge();

    @event function receive(event:String, ?data:String);

    private function new() {

        super();

        bindReceive();

    }

    function bindReceive() {

        #if (clay && web && ceramic_native_bridge)
        if (ElectronRunner.electronRunner != null) {
            var electron:Dynamic = untyped js.Syntax.code("require('electron')");

            electron.ipcRenderer.on('ceramic-native-bridge', function(e, message:String) {

                if (message != null) {
                    var index = message.indexOf(' ');
                    if (index != -1) {
                        var event = message.substring(0, index);
                        var data = message.substring(index + 1);
                        emitReceive(event, data);
                    }
                    else {
                        emitReceive(message);
                    }
                }

            });
        }
        #end

    }

    public function send(event:String, ?data:String):Void {

        #if (clay && web && ceramic_native_bridge)
        if (ElectronRunner.electronRunner != null) {
            var message = event;
            if (data != null) {
                message += ' ' + data;
            }
            ElectronRunner.electronRunner.ceramicNativeBridgeSend(message);
        }
        #end

    }

}
