// Generated by CoffeeScript 1.9.1
var co, easyc;

easyc = require('../lib/easyc');

co = require('co');

co(function*() {
  var e;
  try {
    return (yield easyc.compile({
      quickBuild: true
    }));
  } catch (_error) {
    e = _error;
    return console.error(e.stack);
  }
})();