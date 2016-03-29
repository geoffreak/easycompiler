fs    = require 'co-fs-plus'
debug = require('debug')('compiler')
_     = require 'lodash'
path  = require 'path'
JS    = require './compilers/js'
CSS   = require './compilers/css'
Route = require './compilers/route'
co    = require 'co'
Deps  = require './dependencies'

class module.exports 

  @run: (config, options, previousResults) ->

    if options?.clearBuildDirs
      debug 'Clearing build directories'
      # Iterate over each app to clear build roots
      for app, appConfig of config
        yield fs.rimraf config.javascripts.buildRoot if config?.javascripts?.buildRoot?
        yield fs.rimraf config.stylesheets.buildRoot if config?.stylesheets?.buildRoot?

    if options?.quickBuild
      debug 'Enabling quick build'
      # Disable minification for faster builds
      for app, appConfig of config
        if appConfig?.javascripts?.packages
          for pack, packConfig of appConfig.javascripts.packages
            packConfig.skipMinify = true
        if appConfig?.stylesheets?.packages            
          for pack, packConfig of appConfig.stylesheets.packages
            packConfig.skipMinify = true

    debug 'Running compiler'

    results = previousResults or {}

    # Iterate over each app to build
    for app, appConfig of config when not options?.onlyApp?.length or options.onlyApp.indexOf(app) isnt -1
      result = yield @runApp app, appConfig, options
      results[app] ?= {}
      results[app][key] = value for key, value of result when not _.isEmpty value
    running = false

    # Run compiler
    # results = yield @runApp config, options

    debug 'Compiler finished'

    yield results

  @runApp: (app, config, options) ->

    debug "Running app '#{app}'"

    result = 
      javascripts: {}
      stylesheets: {}

    yields = []
    yields.push @runAppJs app, config, result, options if not options?.onlyPart?.length or options.onlyPart.indexOf('javascripts') isnt -1
    yields.push @runAppCss app, config, result, options if not options?.onlyPart?.length or options.onlyPart.indexOf('stylesheets') isnt -1
    yields.push @runAppRouting app, config, result, options if not options?.onlyPart?.length or options.onlyPart.indexOf('routing') isnt -1

    yield yields

    # Return adjusted config
    result

  @runAppJs: (app, config, result) ->
    # Compile JavaScript (and angular templates)
    if config?.javascripts?.packages
      
      # Iterate over each package
      for pack, packConfig of config.javascripts.packages

        # Setup options
        options = _.extend _.omit(config.javascripts, 'packages'), _.omit(packConfig, 'files', 'extensions')

        # Gather the files
        files = yield @loadFiles config.javascripts.root, packConfig.files, (packConfig.extensions or 'js')

        # Compile to CSS any non-CSS files
        [files, deps] = yield @buildNonNativeFiles "#{app}/#{pack}", files, options, 'js'
        
        # Run the compiler
        result.javascripts[pack] = yield JS.compile "#{app}/#{pack}", files, options, deps
        # console.log config.javascripts.packages[pack]

  @runAppCss: (app, config, result) ->
    # Compile CSS
    if config?.stylesheets?.packages
      
      # Iterate over each package
      for pack, packConfig of config.stylesheets.packages

        # Setup options
        options = _.extend _.omit(config.stylesheets, 'packages'), _.omit(packConfig, 'files', 'extensions')

        # Gather the files
        files = yield @loadFiles config.stylesheets.root, packConfig.files, (packConfig.extensions or 'css')

        # Compile to CSS any non-CSS files
        [files, deps] = yield @buildNonNativeFiles "#{app}/#{pack}", files, options, 'css'
        
        # Run the compiler
        result.stylesheets[pack] = yield CSS.compile "#{app}/#{pack}", files, options, deps

  @runAppRouting: (app, config, result) ->
    # Gather angular routing
    if config?.routing
      result.routing = yield Route.compile config.routing

  @loadFiles: (root, rules, extensions, files) ->
    return [] unless rules and root

    extensions = extensions.split ' '

    # Get list of files
    files ?= yield fs.readdir root, null, []

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

    deps = new Deps()
    builtFiles = []

    # Compile any files needing compiling
    for file, f in files 
      ext = path.extname(file).substr(1)
      if ext isnt nativeType
        # Find the associated compiler or throw an error if unsupported
        try 
          compiler = require "./compilers/#{ext}"
          throw new Error() unless compiler.compilesTo is nativeType
        catch e then throw new Error "Unsupported file type #{ext}\n#{e.message}"

        # Build this file into js or css
        builtFiles.push yield compiler.compile pack, file, options, deps
      else
        builtFiles.push file

    [builtFiles, deps]