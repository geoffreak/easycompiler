fs    = require 'fs'
debug = require('debug')('compiler')
async = require 'async'
JS    = require './compilers/js'
CSS   = require './compilers/css'
Route = require './compilers/route'
_     = require 'lodash'

class module.exports 

  @run: (runCallback) ->

    async.waterfall [
      
      # Read any existing config
      read = (callback) =>
        fs.readFile 'easycompile.json', JSON.stringify(data), callback

      # Run 
      compile = (config, callback) =>

        # Turn config into an array
        config = _.map config, (value, key) =>
          app: key
          data: value

        # Iterate over each application
        async.map config, (appConfig, callback) =>

          # Run each application through the compiler
          @runApp appConfig.app, appConfig.data, callback

        , (err, results) =>
          
          # Remap results back from an array to an object
          if results
            temp = {}
            for result in results
              temp[result.app] = result.data
            results = temp

          # Continue on
          callback null, results
        

      # Write output
      write = (data, callback) =>
        fs.writeFile '.easyc/output.json', JSON.stringify(data), callback

    ], (err, result) =>
      console.error err if err
      console.log result


  @runApp: (app, config, callback) ->
    async.parallel

      # Compile JavaScript (and angular templates)
      js: (callback) ->
        return callback() unless config.javascripts
        JS.compile config.javascripts, callback

      # Compile CSS
      css: (callback) ->
        return callback() unless config.javascripts
        CSS.compile config.javascripts, callback

      # Gather angular routing
      routes: (callback) ->
        return callback() unless config.routing
        Route.compile config.routing, callback

    , (err, results) ->
      # Forward results to next step
      callback err, results