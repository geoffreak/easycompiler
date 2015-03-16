watcher  = require './watch'
easyc    = require './easyc'
minimist = require 'minimist'

class module.exports

  @run: ->
    argv = minimist process.argv.slice(2)
    
    if argv.watch
      yield watcher.watch()
    else
      options = {}
      options.quickBuild = true if argv.fast
      yield easyc.compile options