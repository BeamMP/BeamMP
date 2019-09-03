var fs      = require('fs'),
    msgpack = require("../lib/msgpack"),
    stub    = require("./fixtures/stub");

function _set_up(callback) {
  this.backup = {};
  callback();
}

function _tear_down(callback) {
  callback();
}

exports.regression = {
  setUp : _set_up,
  tearDown : _tear_down,
  'https://github.com/pgriess/node-msgpack/issues/15' : function (test) {
    var obj       = {a:123};
    var fileName  = './packed-data';
    var packedObj = msgpack.pack(obj);
    test.expect(2);
    fs.writeFileSync(fileName, packedObj);
    packedObj2 = fs.readFileSync(fileName);
    test.deepEqual(packedObj, packedObj2);
    var unpackedObj = msgpack.unpack(packedObj2); // crash
    test.deepEqual(obj, unpackedObj);
    fs.unlinkSync(fileName);
    test.done();
  },
  'https://github.com/msgpack/msgpack-node/issues/5' : function (test) {
    var originalArray = ['one', 'two'];
    var packedArray   = msgpack.pack(originalArray);
    var buffer        = new Buffer(packedArray.toString('binary'), 'binary');
    test.expect(3);
    unpackedArray = msgpack.unpack(buffer);
    test.isArray(originalArray);
    test.isArray(unpackedArray);
    test.deepEqual(originalArray, unpackedArray);
    test.done();
  }
};
