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

    @config = JSON.parse yield cofs.readFile 'easycompile.json', 'utf-8'
    @_watchFilesInConfig()

    @_startCompile()

  @abort: (app, pack, part) ->
    for task in @_tasks
      kill = false

      # Determine if we need to elevate this kill because it would kill something at a higher level
      if app? and not task.app?
        return @_kill() # Elevate to global kill
      else if app? and pack? and not task.pack?
        return @_kill app
      else if app? and pack? and part? and not task.part?
        return @_kill app, pack

      # Determine if we need to kill this task because it's the same or a subset of our upcoming new task
      if (not app?) or (task.app is app)
        kill = true
      else if (app? and not pack?) or (task.app is app and task.pack is pack)
        kill = true
      else if (app? and pack? and not part?) or (task.app is app and task.pack is pack and task.part is part)
        kill = true
      try task.fork.kill() if kill
    return [app, pack, part] # Return the updated controls because we might have elevated

  @_watchingConfig: false
  @_watchConfig: ->
    return if @_watchingConfig
    fs.watch path.relative(process.cwd(), 'easycompile.json'), =>
      debug 'Config change'
      @abort()
      _.each @_configWatches, (watch) -> watch.unwatch()
      _.each @_fileWatches, (watch) -> watch.unwatch()
      do co => yield @watch()
    @_watchingConfig = true

  @_startCompile: (app, pack, part) ->
    app = pack = part = null # Temporary manual override until race condition with output json can get resolved
    [app, pack, part] = @abort app, pack, part
    debug "Compiling", app, pack, part
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

      do co => yield @_loadTemplateWatches app, pack

  @_loadTemplateWatches: (app, pack) ->
    debug 'Loading template watches for ', app, pack
    try results = JSON.parse yield cofs.readFile '.easyc/data.json', 'utf-8'
    for _app, appConfig of results when not app? or app is _app
      for _pack, packConfig of appConfig.javascripts when not pack? or pack is _pack
        @_watch _app, _pack, _.map(packConfig.templates, (file) => @config[_app]['javascripts'].webRoot + file) if packConfig.templates?.length

  @_fileWatches: []
  @_watch: (app, pack, files) ->
    debug 'template watching', app, pack
    _.each @_fileWatches, (watch) -> 
      watch.unwatch() if watch.app is app and watch.pack is pack
    fswatcher = chokidar.watch files
    ready = false
    fswatcher.on 'all', (event, file) => 
      return if event is 'add' and not ready
      @_startCompile app, pack, 'template'
    fswatcher.on 'ready', =>
      ready = true
    watch =
      unwatch: unwatch
      app:     app
      pack:    pack
    unwatch = => 
      @_fileWatches = _.without @_fileWatches, watch
      fswatcher.close()

  @_configWatches: []
  @_watchFilesInConfig: ->
    for app, appConfig of @config
      @_configWatches.push @_watchTree @config, app, appConfig, 'stylesheets'
      @_configWatches.push @_watchTree @config, app, appConfig, 'javascripts'

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
    fswatcher.on 'ready', ->
      ready = true
    unwatch = -> 
      @_configWatches = _.without @_configWatches, unwatch
      fswatcher.close()

process.on 'exit', ->
  Watch.abort()

module.exports = Watch