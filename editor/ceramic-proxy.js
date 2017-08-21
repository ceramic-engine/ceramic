
require('colors');

if (process.platform != 'win32') {
    console.error('Ceramic proxy is only supported/required on Windows.'.red);
    return;
}

const spawn = require('child_process').spawn;
const splitter = require('stream-splitter');
const path = require('path');

const dev = false;
const nodeCeramic = false;

let proc = spawn(
    dev ?
        path.normalize(path.join(__dirname, 'dist/win-unpacked/Ceramic.exe'))
    :
        path.normalize(path.join(__dirname, '../../Ceramic.exe')),
    ['ceramic'].concat(process.argv.slice(2)).concat('--electron-proxy')
);

var ignoreOut = true;
var out = splitter("\n");
proc.stdout.pipe(out);
var ctxOut = {};
out.on('token', function(input) {
    input = ('' + input).split("\r").join('');
    if (ignoreOut) {
        if (input.endsWith('[|ceramic:begin|]')) {
            ignoreOut = false;
        }
    }
    else {
        process.stdout.write(decode(input, ctxOut) + "\n");
    }
});

var err = splitter("\n");
proc.stderr.pipe(err);
var ctxErr = {};
err.on('token', function(input) {
    process.stderr.write(decode(input, ctxErr) + "\n");
});

function decode(input, ctx) {

    var text = new Buffer(''+input, 'base64').toString();
    
    text = decodeColors(text, ctx);

    return text;
}

function decodeColors(text, ctx) {

    var colored = '';
    var i = 0;
    var after;
    var current = '';

    while (i < text.length) {

        after = text.slice(i);

        if (after.startsWith('[|color:')) {
            i += 8;
            var color = '';
            while (text.charAt(i) != '|') {
                color += text.charAt(i);
                i++;
            }
            i += 2;
            for (key in ctx) {
                if (ctx.hasOwnProperty(key)) {
                    current = current[key];
                }
            }
            colored += current;
            current = '';
            ctx[color] = true;
        }
        else if (after.startsWith('[|/color:')) {
            i += 9;
            var color = '';
            while (text.charAt(i) != '|') {
                color += text.charAt(i);
                i++;
            }
            i += 2;
            for (key in ctx) {
                if (ctx.hasOwnProperty(key)) {
                    current = current[key];
                }
            }
            colored += current;
            current = '';
            delete ctx[color];
        }
        else {
            current += text.charAt(i);
            i++;
        }

    }

    if (current.length > 0) {
        
        for (key in ctx) {
            if (ctx.hasOwnProperty(key)) {
                current = current[key];
            }
        }
        colored += current;
    
    }

    return colored;
}
