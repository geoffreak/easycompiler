fs    = require 'co-fs-plus'
debug = require('debug')('compiler')
_     = require 'lodash'
path  = require 'path'
JS    = require './compilers/js'
CSS   = require './compilers/css'
Route = require './compilers/route'

class module.exports 

  @run: (config) ->

    results = {}

    # Iterate over each app
    for app, appConfig of config
      results[app] = yield @runApp app, appConfig

    results

  @runApp: (app, config) ->

    # Clear build roots
    yield fs.rimraf config.javascripts.buildRoot if config?.javascripts?.buildRoot?
    yield fs.rimraf config.stylesheets.buildRoot if config?.stylesheets?.buildRoot?

    # Compile JavaScript (and angular templates)
    if config?.javascripts?.packages
      
      # Iterate over each package
      for pack, packConfig of config.javascripts.packages

        # Setup options
        options = _.extend _.omit(config.javascripts, 'packages'), _.omit(packConfig, 'files', 'extensions')

        # Gather the files
        files = yield @loadFiles config.javascripts.root, packConfig.files, (packConfig.extensions or 'js')

        # Compile to CSS any non-CSS files
        files = yield @buildNonNativeFiles "#{app}.#{pack}", files, options, 'js'
        
        # Run the compiler
        config.javascripts.packages[pack] = yield JS.compile "#{app}.#{pack}", files, options
        # console.log config.javascripts.packages[pack]

    # Compile CSS
    if config?.stylesheets?.packages
      
      # Iterate over each package
      for pack, packConfig of config.stylesheets.packages

        # Setup options
        options = _.extend _.omit(config.stylesheets, 'packages'), _.omit(packConfig, 'files', 'extensions')

        # Gather the files
        files = yield @loadFiles config.stylesheets.root, packConfig.files, (packConfig.extensions or 'css')

        # Compile to CSS any non-CSS files
        files = yield @buildNonNativeFiles "#{app}.#{pack}", files, options, 'css'
        
        # Run the compiler
        config.stylesheets.packages[pack] = yield CSS.compile "#{app}.#{pack}", files, options

    # Gather angular routing
    if config?.routing
      config.routing = yield Route.compile config.routing

    # Return adjusted config
    config

  @loadFiles: (root, rules, extensions) ->
    return [] unless rules and root

    files = []
    extensions = extensions.split ' '

    # Get list of files
    files = yield fs.readdir root, null, []

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
      .filter (file) => path.extname(file).substr(1) in extensions # Verify extension
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
    
    filtered

  @buildNonNativeFiles: (pack, files, options, nativeType) ->

    builtFiles = []

    # Compile any files needing compiling
    for file, f in files 
      ext = path.extname(file).substr(1)
      if ext isnt nativeType
        try 
          compiler = require "./compilers/#{ext}"
          throw new Error() unless compiler.compilesTo is nativeType
        catch e then throw new Error "Unsupported file type #{ext}\n#{e.message}"

        builtFiles.push yield compiler.compile pack, file, options
      else
        builtFiles.push file

    builtFiles