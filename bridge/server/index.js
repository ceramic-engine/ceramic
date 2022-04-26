
const WebSocket = require('ws');
var port = 49113;

console.log('CREATE WS SERVER (port: ' + port + ')');

const wss = new WebSocket.Server({
    port: port,
    perMessageDeflate: false
});

wss.on('connection', function(ws) {

    console.log('RECEIVE CONNECTION WS');

    ws.on('message', function(raw) {

        console.log('RECEIVE %s', raw);

    });

    ws.on('error', function(err) {
        console.log('error! ' + err);
    });

    ws.on('close', function() {
        console.log('Closed!');
    });

});

wss.on('error', function(err) {

    console.log('ERROR WS ' + error);

});