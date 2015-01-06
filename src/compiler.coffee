fs    = require 'fs-plus'
debug = require('debug')('compiler')
async = require 'async'
JS    = require './compilers/js'
CSS   = require './compilers/css'
Route = require './compilers/route'
_     = require 'lodash'

# Magic async object mapper override
async.objectMap = (obj, func, cb) ->
  arr = []
  keys = Object.keys(obj)
  i = 0
  while i < keys.length
    wrapper = {}
    wrapper[keys[i]] = obj[keys[i]]
    arr[i] = wrapper
    i += 1
  @map arr, (item, callback) =>
    return func key, value, callback for key, value of item
  , (err, data) =>
    return cb(err)  if err
    res = {}
    i = 0
    while i < data.length
      res[keys[i]] = data[i]
      i += 1
    cb err, res


class module.exports 

  @run: (config, runCallback) ->

    async.waterfall [
      
      # # Read any existing config
      # read = (callback) =>
      #   fs.readFile 'easycompile.json', JSON.stringify(data), callback

      # Run 
      compile = (callback) =>

        # Iterate over each application
        async.objectMap config, (app, config, callback) =>

          # Run each application through the compiler
          @runApp app, config, callback

        , (err, config) =>
          callback err, config
        
      # # Write output
      # write = (config, callback) =>
      #   fs.writeFile '.easyc/output.json', JSON.stringify(config), callback

    ], (err, result) =>
      console.error err if err
      console.log result

  @runApp: (app, config, callback) ->
    async.parallel

      # Compile JavaScript (and angular templates)
      js: (callback) =>
        return callback() unless config?.javascripts?.packages

        # Iterate over each package
        async.objectMap config.javascripts.packages, (pack, packConfig, callback) =>
          
          async.waterfall [

            # Load the requested files
            loadFiles = (callback) =>
              @loadFiles config.root, packConfig.javascripts, (pack.extensions or 'js'), callback

            # Run the JS compiler
            runCompiler = (files, callback) =>
              packConfig.files = files
              JS.compile packConfig, callback

          ], (err, data) =>
            callback err, data

        , (err, packages) =>
          callback err, packages

      # Compile CSS
      css: (callback) =>
        return callback() unless config?.stylesheets?.packages

        # Iterate over each package
        async.objectMap config.stylesheets.packages, (pack, packConfig, callback) =>
          
          async.waterfall [

            # Load the requested files
            loadFiles = (callback) =>
              @loadFiles config.root, packConfig.stylesheets, (pack.extensions or 'css'), callback

            # Run the CSS compiler
            runCompiler = (files, callback) =>
              packConfig.files = files
              CSS.compile packConfig, callback

          ], (err, data) =>
            callback err, data

        , (err, packages) =>
          callback err, packages

      # Gather angular routing
      routes: (callback) =>
        return callback() unless config.routing
        Route.compile config.routing, callback

    , (err, results) =>
      # Forward results to next step
      callback err, results

  @loadFiles: (root, rules, extensions, callback) ->
    return callback null, [] unless rules and root

    files = []
    extensions = extensions.split ' '

    # Get list of files
    fs.traverseTree root, (file) => 
      files.push file # Push the file into the list of files
    , (dir) => 
      true # Continue on directories
    , (err) =>
      return callback err if err

      # Translate rules to regex
      includes = []
      excludes = []
      for rule in rules
        isExclude = false
        if rule.indexOf('-') is 0
          isExclude = true
          rule = rule.substr(1)

        rule = rule.replace /\*/g, '.*?'
        rule = new RegExp "^#{rule}$", 'i'

        if isExclude
          excludes.push rule
        else
          includes.push rule

      # Filter files
      files = _.chain files
        .filter (file) => path.extname(file) in extensions # Verify extension
        .map (file) => path.relative root, file # Turn into relative path
        .filter (file) => # Filter out unwanted files
          for exclude in excludes
            return false if exclude.test file
          true
        .value()

      # Filter and order includes
      filtered = []
      for include in includes
        _.each files, (file) => 
          if include.test(file) and not _.contains filtered, file
            filtered.push file
      
      callback null, filtered