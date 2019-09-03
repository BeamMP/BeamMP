var fs      = require('fs'),
    msgpack = require("../../lib/msgpack"),
    stub    = require("../fixtures/stub");

var DATA_TEMPLATE = {'abcdef' : 1, 'qqq' : 13, '19' : [1, 2, 3, 4]};
var DATA = [];

for (var i = 0; i < 1000000; i++) {
    DATA.push(JSON.parse(JSON.stringify(DATA_TEMPLATE)));
}

function _set_up(callback) {
  this.backup = {};
  callback();
}

function _tear_down(callback) {
  callback();
}

exports.benchmark = {
  setUp : _set_up,
  tearDown : _tear_down,
  'JSON.stringify faster than msgpack.pack with array of 1m objects' : function (test) {
    console.log();
    var jsonStr;
    var now = Date.now();
    jsonStr = JSON.stringify(DATA);
    var stringifyTime = (Date.now() - now);

    var mpBuf;
    now = Date.now();
    mpBuf = msgpack.pack(DATA);
    var packTime = (Date.now() - now);

    console.log(
      "msgpack.pack: "+packTime+"ms, JSON.stringify: "+stringifyTime+"ms"
    );
    console.log(
      "ratio of JSON.stringify/msgpack.pack: " + stringifyTime/packTime
    );
    test.expect(1);
    test.ok(
      packTime > stringifyTime,
      "msgpack.pack: "+packTime+"ms, JSON.stringify: "+stringifyTime+"ms"
    );
    test.done();
  },
//  'JSON.parse faster than msgpack.unpack with array of 1m objects' : function (test) {
//    console.log();
//    var jsonStr;
//    jsonStr = JSON.stringify(DATA);
//
//    var mpBuf;
//    mpBuf = msgpack.pack(DATA);
//
//    var now = Date.now();
//    JSON.parse(jsonStr);
//    var parseTime = (Date.now() - now);
//
//    now = Date.now();
//    msgpack.unpack(mpBuf);
//    var unpackTime = (Date.now() - now);
//
//    console.log(
//      "msgpack.unpack: "+unpackTime+"ms, JSON.parse: "+parseTime+"ms"
//    );
//    console.log("ratio of parseTime/msgpack.unpack: " + parseTime/unpackTime);
//    test.expect(1);
//    test.ok(
//      unpackTime > parseTime,
//      "msgpack.unpack: "+unpackTime+"ms, JSON.parse: "+parseTime+"ms"
//    );
//    test.done();
//  },
  'JSON.stringify faster than msgpack.pack over 1m calls' : function (test) {
    console.log();

    var jsonStr;
    var now = Date.now();
    DATA.forEach(function(d) {
        jsonStr = JSON.stringify(d);
    });
    var stringifyTime = (Date.now() - now);

    var mpBuf;
    now = Date.now();
    DATA.forEach(function(d) {
        mpBuf = msgpack.pack(d);
    });
    var packTime = (Date.now() - now);

    console.log(
      "msgpack.pack: "+packTime+"ms, JSON.stringify: "+stringifyTime+"ms"
    );
    console.log(
      "ratio of msgpack.pack/JSON.stringify: " + packTime/stringifyTime
    );
    test.expect(1);
    test.ok(
      stringifyTime < packTime && packTime/stringifyTime < 6,
      "msgpack.pack: "+packTime+"ms, JSON.stringify: "+stringifyTime+"ms"
    );
    test.done();
  },
  'JSON.parse faster than msgpack.unpack over 1m calls' : function (test) {
    console.log();
    var jsonStr;

    DATA.forEach(function(d) {
        jsonStr = JSON.stringify(d);
    });

    var mpBuf;
    DATA.forEach(function(d) {
        mpBuf = msgpack.pack(d);
    });

    var now = Date.now();
    DATA.forEach(function(d) {
        JSON.parse(jsonStr);
    });
    var parseTime = (Date.now() - now);

    now = Date.now();
    DATA.forEach(function(d) {
        msgpack.unpack(mpBuf);
    });
    var unpackTime = (Date.now() - now);

    console.log(
      "msgpack.unpack: "+unpackTime+"ms, JSON.parse: "+parseTime+"ms"
    );
    console.log("ratio of JSON.parse/msgpack.unpack: " + unpackTime/parseTime);
    test.expect(1);
    test.ok(
      parseTime < unpackTime && unpackTime/parseTime < 5,
      "msgpack.unpack: "+unpackTime+"ms, JSON.parse: "+parseTime+"ms"
    );
    test.done();
  },
  'output above is from three runs on a 1m element array of objects' : function (test) {
    console.log();
    for (var i = 0; i < 3; i++) {
      var mpBuf;
      var now = Date.now();
      mpBuf = msgpack.pack(DATA);
      console.log('msgpack pack:   ' + (Date.now() - now) + ' ms');

      now = Date.now();
      msgpack.unpack(mpBuf);
      console.log('msgpack unpack: ' + (Date.now() - now) + ' ms');

      var jsonStr;
      now = Date.now();
      jsonStr = JSON.stringify(DATA);
      console.log('json    pack:   ' + (Date.now() - now) + ' ms');

      now = Date.now();
      JSON.parse(jsonStr);
      console.log('json    unpack: ' + (Date.now() - now) + ' ms');
      console.log();
    }

    test.expect(1);
    test.ok(1);
    test.done();
  },
  'output above is from three runs of 1m individual calls' : function (test) {
    console.log();
    for (var i = 0; i < 3; i++) {
      var mpBuf;
      var now = Date.now();
      DATA.forEach(function(d) {
        mpBuf = msgpack.pack(d);
      });
      console.log('msgpack pack:   ' + (Date.now() - now) + ' ms');

      now = Date.now();
      DATA.forEach(function(d) {
        msgpack.unpack(mpBuf);
      });
      console.log('msgpack unpack: ' + (Date.now() - now) + ' ms');

      var jsonStr;
      now = Date.now();
      DATA.forEach(function(d) {
        jsonStr = JSON.stringify(d);
      });
      console.log('json    pack:   ' + (Date.now() - now) + ' ms');

      now = Date.now();
      DATA.forEach(function(d) {
        JSON.parse(jsonStr);
      });
      console.log('json    unpack: ' + (Date.now() - now) + ' ms');
      console.log();
    }

    test.expect(1);
    test.ok(1);
    test.done();
  }
};
