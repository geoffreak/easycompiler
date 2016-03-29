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

  @abort: (app = [], pack = [], part = []) ->
    app  = [app]  if app?  and not _.isArray app
    pack = [pack] if pack? and not _.isArray pack
    part = [part] if part? and not _.isArray part

    for task in @_tasks

      if not app.length or task.app.join(',') isnt app.join(',')
        app = _.uniq app.concat task.app
      if not pack.length or task.pack.join(',') isnt pack.join(',')
        pack = _.uniq pack.concat task.pack
      if not part.length or task.part.join(',') isnt part.join(',')
        part = _.uniq part.concat task.part

      debug 'Killing task', task.app, task.pack, task.part
      try task.fork.kill()
      task.killed = true

    return [app, pack, part] # Return the updated controls because we might have elevated

  @_watchingConfig: false
  @_watchConfig: ->
    return if @_watchingConfig
    fs.watch path.relative(process.cwd(), 'easycompile.json'), =>
      debug 'Config change'
      @abort()
      _.each @_configWatches, (unwatch) -> unwatch()
      _.each @_fileWatches, (watch) -> watch.unwatch()
      do co => yield @watch()
    @_watchingConfig = true

  @_startCompile: (app, pack, part) ->
    # app = pack = part = null # Temporary manual override until race condition with output json can get resolved
    [app, pack, part] = @abort app, pack, part
    debug "Compiling", app, pack, part
    fork = child.fork path.resolve(__dirname, 'watchRun.js'), [], 
      env: _.defaults
        app:  app?.join(',')  or ''
        pack: pack?.join(',') or ''
        part: part?.join(',') or ''
      , process.env
    task =
      fork: fork
      app:  app
      pack: pack
      part: part
    @_tasks.push task
    fork.on 'error', (e) =>
      console.error e.toString()
    fork.on 'exit', (args...) =>
      @_tasks = _.without @_tasks, task
      return if task.killed
      do co => yield @_loadTemplateWatches app, pack

  @_loadTemplateWatches: (app, pack) ->
    debug 'Loading watches for ', app, pack
    try results = JSON.parse yield cofs.readFile '.easyc/data.json', 'utf-8'
    for _app, appConfig of results when not app?.length or app.indexOf(_app) isnt -1
      for _pack, packConfig of appConfig.javascripts when not pack?.length or pack.indexOf(_pack) isnt -1
        @_watch _app, _pack, 'javascripts', packConfig.deps if packConfig.deps?
      for _pack, packConfig of appConfig.stylesheets when not pack?.length or pack.indexOf(_pack) isnt -1
        @_watch _app, _pack, 'stylesheets', packConfig.deps if packConfig.deps?

  @_fileWatches: []
  @_watch: (app, pack, type, files) ->
    debug "#{type} dependency watching", app, pack
    _.each @_fileWatches, (watch) -> 
      watch.unwatch() if watch.app is app and watch.pack is pack and watch.type is type
    fswatcher = chokidar.watch files
    ready = false
    fswatcher.on 'all', (event, file) =>
      return if event is 'add' and not ready
      debug "File change: #{file}"
      @_startCompile app, pack, type
    fswatcher.on 'ready', =>
      ready = true
    unwatch = => 
      @_fileWatches = _.without @_fileWatches, watch
      fswatcher.close()
    watch =
      unwatch: unwatch
      app:     app
      pack:    pack
      type:    type
    @_fileWatches.push watch

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
          contained = []
          for pack, packConfig of appConfig[type].packages
            files = yield compiler.loadFiles appConfig[type].root, packConfig.files, (packConfig.extensions or (if type is 'stylesheets' then 'css' else 'js')), [filename]
            if -1 isnt _.indexOf files, path.relative appConfig[type].root, filename
              contained.push pack 
              break
          return unless contained.length
          debug "File change: #{filename}"
          @_startCompile app, (if contained.length is 1 then contained[0] else null), type
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