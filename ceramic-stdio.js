
if (process.versions['electron'] != null) {

    const write = process.stdout.write.bind(process.stdout);

    process.stdout.write = function(input, encoding, fd) {

        write(new Buffer(input).toString('base64'), 'base64');

    }

}
