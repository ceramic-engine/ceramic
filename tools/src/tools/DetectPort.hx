package tools;

import sys.net.Socket;

class DetectPort {

    public static function detect(startPort:Int = 1024, endPort:Int = 65535):Int {
        var socket = new Socket();

        for (port in startPort...endPort) {
            try {
                socket.bind(new sys.net.Host("localhost"), port);
                socket.close();
                return port;
            } catch (e:Dynamic) {
                continue;
            }
        }

        throw "No free ports found in range";
    }

}
