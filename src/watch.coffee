path     = require 'path'
fs       = require 'fs'
cofs     = require 'co-fs-plus'
child    = require 'child_process'
_        = require 'lodash'
debug    = require('debug')('compiler:watch')
co       = require 'co'
compiler = require './compiler'
chokidar = require 'chokidar'

class Watch

  @_tasks: []

  @watch: ->
    debug 'Starting watch process'
    @_watchConfig()

    config = JSON.parse yield cofs.readFile 'easycompile.json', 'utf-8'
    @_watchFiles config

    @_startCompile()

  @abort: (app, pack, part) ->
    _.each @_tasks, (task) ->
      if (not app? or task.app is app) or (not pack? or task.pack is pack) or (not part? or task.part is part)
        try task.fork.kill()

  @_watchingConfig: false
  @_watchConfig: ->
    return if @_watchingConfig
    fs.watch path.relative(process.cwd(), 'easycompile.json'), (args...) =>
      debug 'Config change'
      @abort()
      _.each @_unwatches, (unwatch) -> unwatch()
      @_unwatches = []
      do co => yield @watch()
    @_watchingConfig = true

  @_startCompile: (app, pack, part) ->
    debug "Compiling #{app} #{pack} #{part}"
    args = []
    if app?
      args.push app 
      if pack?
        args.push pack
        if part?
          args.push part
    fork = child.fork path.resolve(__dirname, 'watchRun.js'), args, env: process.env
    task =
      fork: fork
      app:  app
      pack: pack
      part: part
    @_tasks.push task
    fork.on 'error', (e) =>
      console.error e.toString()
    fork.on 'exit', =>
      @_tasks = _.without @_tasks, task

  @_unwatches: []
  @_watchFiles: (config) ->
    for app, appConfig of config
      @_unwatches.push @_watchTree config, app, appConfig, 'stylesheets'
      @_unwatches.push @_watchTree config, app, appConfig, 'javascripts'

  @_watchTree: (config, app, appConfig, type) ->
    root = path.resolve process.cwd(), appConfig[type].root
    watchFn = (filename) => 
      fn = =>
        try
          return unless typeof filename is 'string'
          filename = path.relative process.cwd(), filename
          contained = false
          for pack, packConfig of appConfig[type].packages
            files = yield compiler.loadFiles appConfig[type].root, packConfig.files, (packConfig.extensions or (if type is 'stylesheets' then 'css' else 'js')), [filename]
            if -1 isnt _.indexOf files, path.relative appConfig[type].root, filename
              contained = pack 
              break
          return unless contained
          debug "File change: #{filename}"
          @_startCompile app, contained, type
        catch e
          console.error e.stack
      co(fn)()
    fswatcher = chokidar.watch root
    ready = false
    fswatcher.on 'all', (event, file) -> 
      return if event is 'add' and not ready
      watchFn file
    fswatcher.on 'ready', (args...) ->
      ready = true
    unwatch = -> 
      fswatcher.close()

process.on 'exit', ->
  Watch.abort()

module.exports = Watch