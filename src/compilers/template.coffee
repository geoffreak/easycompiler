fs     = require 'co-fs-plus'
path   = require 'path'
minify = require('html-minifier').minify
debug  = require('debug')('compiler:template')

jsRegex  = /templateUrl:[\s]*?("([^"\\]*(\\.[^"\\]*)*)"|\'([^\'\\]*(\\.[^\'\\]*)*)\')/i
jsRegexg = /templateUrl:[\s]*?("([^"\\]*(\\.[^"\\]*)*)"|\'([^\'\\]*(\\.[^\'\\]*)*)\')/gi

htmlRegex  = /ng-include=[\s]*?("([^"\\]*(\\.[^"\\]*)*)"|\'([^\'\\]*(\\.[^\'\\]*)*)\')/i
htmlRegexg = /ng-include=[\s]*?("([^"\\]*(\\.[^"\\]*)*)"|\'([^\'\\]*(\\.[^\'\\]*)*)\')/gi

class module.exports

  constructor: (@pack, @config) ->
    @cache = {}
    @templateCount = 0

  parseAndAddFromFile: (file, html = false) ->
    content = file
    content = yield fs.readFile file, 'utf-8' unless html
    matches = content.match if html then htmlRegexg else jsRegexg
    return unless matches?.length
    for match in matches when not @cache[match]?
      try
        match = match.match if html then htmlRegex else jsRegex
        match = match[2] or match[4]
        match = match.replace /^[\s'"]+|[\s'"]+$/gm, ''

        file = match
        file = file.substr 1 if file.charAt(0) is '/'
        file = path.resolve @config.webRoot, file
        template = yield fs.readFile file, 'utf-8'

        @addTemplateToCache match, template

        try yield @parseAndAddFromFile template, true
        

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
