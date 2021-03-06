// Generated by CoffeeScript 1.9.3
var _, debug, fs, htmlRegex, htmlRegexg, jsRegex, jsRegexg, minify, path;

fs = require('co-fs-plus');

path = require('path');

_ = require('lodash');

minify = require('html-minifier').minify;

debug = require('debug')('compiler:template');

jsRegex = /templateUrl:[\s]*?("([^"\\]*(\\.[^"\\]*)*)"|\'([^\'\\]*(\\.[^\'\\]*)*)\')/i;

jsRegexg = /templateUrl:[\s]*?("([^"\\]*(\\.[^"\\]*)*)"|\'([^\'\\]*(\\.[^\'\\]*)*)\')/gi;

htmlRegex = /ng-include=[\s]*?("([^"\\]*(\\.[^"\\]*)*)"|\'([^\'\\]*(\\.[^\'\\]*)*)\')/i;

htmlRegexg = /ng-include=[\s]*?("([^"\\]*(\\.[^"\\]*)*)"|\'([^\'\\]*(\\.[^\'\\]*)*)\')/gi;

module.exports = (function() {
  function exports(pack, config) {
    this.pack = pack;
    this.config = config;
    this.cache = {};
    this.templateCount = 0;
  }

  exports.prototype.parseAndAddFromFile = function*(file, html) {
    var content, err, i, len, match, matches, results, template;
    if (html == null) {
      html = false;
    }
    content = file;
    if (!html) {
      content = (yield fs.readFile(file, 'utf-8'));
    }
    matches = content.match(html ? htmlRegexg : jsRegexg);
    if (!(matches != null ? matches.length : void 0)) {
      return;
    }
    results = [];
    for (i = 0, len = matches.length; i < len; i++) {
      match = matches[i];
      if (this.cache[match] == null) {
        try {
          match = match.match(html ? htmlRegex : jsRegex);
          match = match[2] || match[4];
          match = match.replace(/^[\s'"]+|[\s'"]+$/gm, '');
          file = match;
          if (file.charAt(0) === '/') {
            file = file.substr(1);
          }
          file = path.resolve(this.config.webRoot, file);
          template = (yield fs.readFile(file, 'utf-8'));
          this.addTemplateToCache(match, template);
          try {
            results.push((yield this.parseAndAddFromFile(template, true)));
          } catch (_error) {}
        } catch (_error) {
          err = _error;
          if ((err != null ? err.type : void 0) === 'minify') {
            throw err;
          } else {
            results.push(void 0);
          }
        }
      }
    }
    return results;
  };

  exports.prototype.addTemplateToCache = function(file, template) {
    var err, message;
    try {
      this.cache[file] = minify(template, {
        removeComments: true,
        collapseWhitespace: true
      });
    } catch (_error) {
      message = _error;
      err = new Error(message);
      err.type = 'minify';
      throw err;
    }
    return this.templateCount++;
  };

  exports.prototype.hasTemplates = function() {
    return this.templateCount > 0;
  };

  exports.prototype.getTemplatesList = function() {
    var file, list;
    list = [];
    for (file in this.cache) {
      list.push(file);
    }
    return list;
  };

  exports.prototype.writeCache = function*() {
    var content, file, output, ref, s, sortedCache, template;
    debug("Writing template cache");
    output = path.resolve(this.config.buildRoot, this.pack + ".cache.js");
    sortedCache = [];
    ref = this.cache;
    for (file in ref) {
      template = ref[file];
      sortedCache.push({
        file: file,
        template: template
      });
    }
    sortedCache = _.sortBy(sortedCache, 'file');
    content = "angular.module(" + (JSON.stringify(this.config.angularTemplates)) + ", []).run(['$templateCache', function($templateCache){\n  " + (((function() {
      var i, len, results;
      results = [];
      for (i = 0, len = sortedCache.length; i < len; i++) {
        s = sortedCache[i];
        results.push("$templateCache.put(" + (JSON.stringify(s.file)) + ", " + (JSON.stringify(s.template)) + ");");
      }
      return results;
    })()).join("\n  ")) + "\n}]);";
    (yield fs.mkdirp(path.dirname(output)));
    (yield fs.writeFile(output, content));
    return output;
  };

  return exports;

})();
