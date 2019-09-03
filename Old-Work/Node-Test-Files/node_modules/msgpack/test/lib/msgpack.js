var msgpack = require("../../lib/msgpack"),
    stub    = require("../fixtures/stub");

function _set_up(callback) {
  this.backup = {};

  this.testCircular = function(data, test) {
      try {
        msgpack.pack(data);
        test.ok(false, 'expected exception');
      } catch (e) {
        test.equal(
          e.message,
          'Cowardly refusing to pack object with circular reference'
        );
      }
  };

  callback();
}

function _tear_down(callback) {
  callback();
}

exports.msgpack = {
  setUp : _set_up,
  tearDown : _tear_down,
  'should be object' : function (test) {
    test.expect(2);
    test.isNotNull(msgpack);
    test.isObject(msgpack);
    test.done();
  },
  'pack should return a Buffer object' : function (test) {
    test.expect(2);
    var buf = msgpack.pack('abcdef');
    test.isNotNull(buf);
    test.isBuffer(buf);
    test.done();
  },
  'test for string equality' : function (test) {
    test.expect(1);
    test.deepEqual('abcdef', msgpack.unpack(msgpack.pack('abcdef')));
    test.done();
  },
//  'test unpacking a buffer' : function (test) {
//    test.expect(1);
//    var testBuffer = new Buffer([0x00, 0x01, 0x02]);
//    test.deepEqual(testBuffer, msgpack.unpack(msgpack.pack(testBuffer), true));
//    test.done();
//  },
  'test for numeric equality' : function (test) {
    test.expect(2);
    test.deepEqual(123, msgpack.unpack(msgpack.pack(123)));
    test.isNumber(msgpack.unpack(msgpack.pack(123)));
    test.done();
  },
  'test for null' : function (test) {
    test.expect(2);
    test.deepEqual(null, msgpack.unpack(msgpack.pack(null)));
    test.isNull(msgpack.unpack(msgpack.pack(null)));
    test.done();
  },
  'test for negative decimal number' : function (test) {
    test.expect(2);
    test.deepEqual(-1243.111, msgpack.unpack(msgpack.pack(-1243.111)));
    test.isNumber(msgpack.unpack(msgpack.pack(-1243.111)));
    test.done();
  },
  'test for negative number' : function (test) {
    test.expect(2);
    test.deepEqual(-123, msgpack.unpack(msgpack.pack(-123)));
    test.isNumber(msgpack.unpack(msgpack.pack(-123)));
    test.done();
  },
  'test for true' : function (test) {
    test.expect(2);
    test.deepEqual(true, msgpack.unpack(msgpack.pack(true)));
    test.isBoolean(msgpack.unpack(msgpack.pack(true)));
    test.done();
  },
  'test for false' : function (test) {
    test.expect(2);
    test.deepEqual(false, msgpack.unpack(msgpack.pack(false)));
    test.isBoolean(msgpack.unpack(msgpack.pack(false)));
    test.done();
  },
  'test for numeric array' : function (test) {
    test.expect(2);
    test.deepEqual([1,2,3], msgpack.unpack(msgpack.pack([1,2,3])));
    test.isArray(msgpack.unpack(msgpack.pack([1,2,3])));
    test.done();
  },
  'test for mixed type array' : function (test) {
    test.expect(2);
    test.deepEqual(
      [1, 'abc', false, null],
      msgpack.unpack(msgpack.pack([1, 'abc', false, null]))
    );
    test.isArray(msgpack.unpack(msgpack.pack([1,2,3])));
    test.done();
  },
  'test for object' : function (test) {
    test.expect(2);
    var object = {'a' : [1, 2, 3], 'b' : 'cdef', 'c' : {'nuts' : 'qqq'}};
    test.deepEqual(object, msgpack.unpack(msgpack.pack(object)));
    test.isObject(msgpack.unpack(msgpack.pack(object)));
    test.done();
  },
  'test for 2^31 negative' : function (test) {
    test.expect(2);
    test.deepEqual(
      0 - Math.pow(2,31) - 1,
      msgpack.unpack(msgpack.pack(0 - Math.pow(2,31) - 1))
    );
    test.isNumber(msgpack.unpack(msgpack.pack(0 - Math.pow(2,31) - 1)));
    test.done();
  },
  'test for 2^40 negative' : function (test) {
    test.expect(2);
    test.deepEqual(
      0 - Math.pow(2,40) - 1,
      msgpack.unpack(msgpack.pack(0 - Math.pow(2,40) - 1))
    );
    test.isNumber(msgpack.unpack(msgpack.pack(0 - Math.pow(2,40) - 1)));
    test.done();
  },
  'test for 2^31' : function (test) {
    test.expect(2);
    test.deepEqual(
      Math.pow(2,31) + 1,
      msgpack.unpack(msgpack.pack(Math.pow(2,31) + 1))
    );
    test.isNumber(msgpack.unpack(msgpack.pack(Math.pow(2,31) + 1)));
    test.done();
  },
  'test for 2^40' : function (test) {
    test.expect(2);
    test.deepEqual(
      Math.pow(2,40) + 1,
      msgpack.unpack(msgpack.pack(Math.pow(2,40) + 1))
    );
    test.isNumber(msgpack.unpack(msgpack.pack(Math.pow(2,40) + 1)));
    test.done();
  },
  'test number approaching 2^64' : function (test) {
    test.expect(2);
    test.deepEqual(
      123456782345245,
      msgpack.unpack(msgpack.pack(123456782345245))
    );
    test.isNumber(msgpack.unpack(msgpack.pack(123456782345245)));
    test.done();
  },
  'make sure dates are handled properly' : function (test) {
    test.expect(2);
    var date = new Date();
    var dateObj = { d : date };
    test.deepEqual(
      { d : date.toISOString() },
      msgpack.unpack(msgpack.pack(dateObj))
    );
    test.isObject(msgpack.unpack(msgpack.pack(dateObj)));
    test.done();
  },
  'test for circular reference' : function (test) {
    test.expect(1);
    var a = [1, 2, 3, 4];
    a.push(a);
    this.testCircular(a, test);
    test.done();
  },
  'test for circular reference in objects' : function (test) {
    test.expect(1);
    var d = {};
    d.qqq = d;
    this.testCircular(d, test);
    test.done();
  },
  'test for not catching multiple non-circular references' : function (test) {
    test.expect(2);
    var e = {};
    test.deepEqual(
      { a : e, b : e },
      msgpack.unpack(msgpack.pack({ a : e, b : e }))
    );
    test.isObject(msgpack.unpack(msgpack.pack({ a : e, b : e })));
    test.done();
  },
  'unpacking a buffer with extra data doesn\'t lose the extra data' : function (test) {
    test.expect(4);
    // Object to test with
    var o = [1, 2, 3];

    // Create two buffers full of packed data, 'b' and 'bb', with the latter
    // containing 3 extra bytes
    var b = msgpack.pack(o);
    var bb = new Buffer(b.length + 3);
    b.copy(bb, 0, 0, b.length);

    // Expect no remaining bytes when unpacking 'b'
    test.deepEqual(msgpack.unpack(b), o);
    test.deepEqual(msgpack.unpack.bytes_remaining, 0);

    // Expect 3 remaining bytes when unpacking 'bb'
    test.deepEqual(msgpack.unpack(bb), o);
    test.equal(msgpack.unpack.bytes_remaining, 3);

    test.done();
  },
  'circular reference marking algorithm doesn\'t false positive' : function (test) {
    test.expect(1);
    try {
      var d = {};
      for (var i = 0; i < 10; i++) {
        msgpack.pack(d);
      }
      test.ok(true, 'all clear');
    } catch (e) {
      test.ok(false, e.message);
    }
    test.done();
  },
  'test toJSON compatibility' : function (test) {
    var expect = { msg: 'hello world' };
    var subject = { toJSON: function() { return expect; }};
    test.expect(1);
    test.deepEqual(expect, msgpack.unpack(msgpack.pack(subject)));
    test.done();
  },
  'test toJSON compatibility for multiple args' : function (test) {
    var expect = { msg: 'hello world' };
    var subject = { toJSON: function() { return expect; }};
    var subject1 = { toJSON: function() { msg: 'goodbye world' }};
    test.expect(1);
    test.deepEqual(expect, msgpack.unpack(msgpack.pack(subject, subject1)));
    test.done();
  },
  'test toJSON compatibility for nested toJSON' : function (test) {
    var expect = { msg: 'hello world' };
    var subject = {
      toJSON: function() {
        return [
          expect,
          {
            toJSON: function() {
              return expect;
            }
          }
        ];
      }
    };
    test.expect(1);
    test.deepEqual([expect, expect], msgpack.unpack(msgpack.pack(subject)));
    test.done();
  },
  'test toJSON compatibility with prototype' : function (test) {
    var expect = { msg: 'hello world' };
    var subject = { __proto__: { toJSON: function() { return expect; }}};
    test.expect(1);
    test.deepEqual(expect, msgpack.unpack(msgpack.pack(subject)));
    test.done();
  }
};
