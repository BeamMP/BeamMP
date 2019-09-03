// Wrap a nicer JavaScript API that wraps the direct MessagePack bindings.

var buffer = require('buffer');
var events = require('events');
var mpBindings;
mpBindings = require(__dirname + "/../build/Release/msgpackBinding");

var sys;
try {
    sys = require('util');
} catch (e) {
    sys = require('sys');
}

var bpack = mpBindings.pack;
var unpack = mpBindings.unpack;

exports.pack = pack;
exports.unpack = unpack;

function pack() {
    var args = arguments, that, i;
    for (i = 0; i < arguments.length; i++) {
        that = args[i];
        if (that && typeof that === 'object' &&
            typeof that.toJSON === 'function') {
            args[i] = that.toJSON();
        }
    }
    return bpack.apply(null, args);
}

var Stream = function(s) {
    var self = this;

    events.EventEmitter.call(self);

    // Buffer of incomplete stream data
    self.buf = null;

    // Send a message down the stream
    //
    // Allows the caller to pass additional arguments, which are passed
    // faithfully down to the write() method of the underlying stream.
    self.send = function(m) {
        // Sigh, no arguments.slice() method
        var args = [pack(m)];
        for (i = 1; i < arguments.length; i++) {
            args.push(arguments[i]);
        }

        return s.write.apply(s, args);
    };

    // Listen for data from the underlying stream, consuming it and emitting
    // 'msg' events as we find whole messages.
    s.addListener('data', function(d) {
        // Make sure that self.buf reflects the entirety of the unread stream
        // of bytes; it needs to be a single buffer
        if (self.buf) {
            var b = new buffer.Buffer(self.buf.length + d.length);
            self.buf.copy(b, 0, 0, self.buf.length);
            d.copy(b, self.buf.length, 0, d.length);

            self.buf = b;
        } else {
            self.buf = d;
        }

        // Consume messages from the stream, one by one
        while (self.buf && self.buf.length > 0) {
            var msg = unpack(self.buf);
            if (!msg) {
                break;
            }

            self.emit('msg', msg);
            if (unpack.bytes_remaining > 0) {
                self.buf = self.buf.slice(
                    self.buf.length - unpack.bytes_remaining,
                    self.buf.length
                );
            } else {
                self.buf = null;
            }
        }
    });
};

sys.inherits(Stream, events.EventEmitter);
exports.Stream = Stream;
