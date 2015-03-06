fs       = require 'co-fs-plus'
Compiler = require './compiler'
_        = require 'lodash'
util     = require 'util'

class module.exports

  @compile: (options) ->
    # Read in config
    config = JSON.parse yield fs.readFile 'easycompile.json', 'utf-8'

    # Run compiler
    results = yield Compiler.run config, options

    # Write out data
    yield fs.mkdirp '.easyc/'
    yield fs.writeFile '.easyc/data.json', JSON.stringify results, null, 2

  @load: ->
    unless @_cache
      try
        @_cache = JSON.parse yield fs.readFile '.easyc/data.json', 'utf-8'
      catch e
        @_cache = yield @compile()
    @_cache

  @setProduction: (@_production = true) ->

  @getEnv: ->
    if @_production then 'prod' else 'dev'

  @getJavascripts: (app, packs) ->
    config = yield @load()

    return [] unless config?[app]?.javascripts?

    unless util.isArray packs
      if typeof packs is 'string'
        packs = [packs]
      else
        packs = Object.keys config[app].javascripts

    _.flatten(config[app].javascripts[pack]?[@getEnv()] or [] for pack in packs)
    

  @getStylesheets: (app, packs) ->
    config = yield @load()

    return [] unless config?[app]?.stylesheets?

    unless util.isArray packs
      if typeof packs is 'string'
        packs = [packs]
      else
        packs = Object.keys config[app].stylesheets

    _.flatten(config[app].stylesheets[pack]?[@getEnv()] or [] for pack in packs)
