fs     = require 'co-fs-plus'
path   = require 'path'
minify = require('html-minifier').minify
debug  = require('debug')('compiler:template')

regex  = /templateUrl:[\s]*?("([^"\\]*(\\.[^"\\]*)*)"|\'([^\'\\]*(\\.[^\'\\]*)*)\')/i
regexg = /templateUrl:[\s]*?("([^"\\]*(\\.[^"\\]*)*)"|\'([^\'\\]*(\\.[^\'\\]*)*)\')/gi

class module.exports

  constructor: (@pack, @config) ->
    @cache = {}
    @templateCount = 0

  parseAndAddFromFile: (file) ->
    content = yield fs.readFile file, 'utf-8'
    matches = content.match regexg
    return unless matches?.length
    for match in matches
      continue if @cache[match]?
      try
        match = match.match(regex)
        match = match[2] or match[4]
        file = match
        file = match.substr 1 if match.charAt(0) is '/'
        file = path.resolve(@config.webRoot, file)
        template = yield fs.readFile file, 'utf-8'
        @addTemplateToCache match, template

  addTemplateToCache: (file, template) ->
    # debug "Adding template to cache: #{file}"
    @cache[file] = minify template,
      removeComments:     true
      collapseWhitespace: true
    @templateCount++

  hasTemplates: -> @templateCount > 0

  getTemplatesList: ->
    list = []
    for file of @cache
      list.push file
    list
    
  writeCache: ->
    debug "Writing template cache"
    output = path.resolve @config.buildRoot, "#{@pack}.cache.js"

    content = """
      angular.module(#{JSON.stringify @config.angularTemplates}, []).run(['$templateCache', function($templateCache){
        #{("$templateCache.put(#{JSON.stringify(file)}, #{JSON.stringify(template)});" for file, template of @cache).join("\n  ")}
      }]);
    """

    yield fs.mkdirp path.dirname output
    yield fs.writeFile output, content

    output
