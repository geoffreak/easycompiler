fs       = require 'co-fs-plus'
Compiler = require './compiler'
_        = require 'lodash'
util     = require 'util'

class module.exports

  @compile: ->
    # Read in config
    config = JSON.parse yield fs.readFile 'easycompile.json', 'utf-8'

    # Run compiler
    results = yield Compiler.run config

    # Write out data
    yield fs.mkdirp '.easyc/'
    yield fs.writeFile '.easyc/data.json', JSON.stringify results, null, 2

  @load: ->
    unless @_cache
      try
        @_cache = yield fs.readFile '.easyc/data.json'
      catch e
        @_cache = yield @compile()
    @_cache

  @getJavascripts: (app, packs) ->
    config = yield @load()

    packs = [packs] unless util.isArray packs

    if packs
      _.flatten(config?[app]?.javascripts.packs?[pack] or [] for pack in packs)
    else
      _.flatten config?[app]?.javascripts.packs or []

  @getStylesheets: (app, packs) ->
    config = yield @load()

    packs = [packs] unless util.isArray packs

    if packs
      _.flatten(config?[app]?.stylesheets.packs?[pack] or [] for pack in packs)
    else
      _.flatten config?[app]?.stylesheets.packs or []
