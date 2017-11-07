fs     = require 'co-fs-plus'
path   = require 'path'
_      = require 'lodash'
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
      catch err
        throw err if err?.type is 'minify'
        

  addTemplateToCache: (file, template) ->
    # debug "Adding template to cache: #{file}"
    try
      @cache[file] = minify template,
        removeComments:     true
        collapseWhitespace: true
    catch message
      err = new Error(message)
      err.type = 'minify'
      throw err
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

    sortedCache = []
    for file, template of @cache
      sortedCache.push { file, template }
    sortedCache = _.sortBy sortedCache, 'file'

    content = """
      angular.module(#{JSON.stringify @config.angularTemplates}, []).run(['$templateCache', function($templateCache){
        #{("$templateCache.put(#{JSON.stringify(s.file)}, #{JSON.stringify(s.template)});" for s in sortedCache).join("\n  ")}
      }]);
    """

    yield fs.mkdirp path.dirname output
    yield fs.writeFile output, content

    output
