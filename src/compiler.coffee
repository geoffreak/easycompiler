fs    = require 'co-fs-plus'
debug = require('debug')('compiler')
_     = require 'lodash'
path  = require 'path'
JS    = require './compilers/js'
CSS   = require './compilers/css'
Route = require './compilers/route'
watch = require 'watch'
co    = require 'co'

class module.exports 

  @run: (config, options) ->

    results = {}
    running = false

    run = (config) =>
      return if running
      debug 'Running compiler'

      running = true
      # Iterate over each app to build
      for app, appConfig of config
        results[app] = yield @runApp app, appConfig
      running = false

      debug 'Compiler finished'

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

    yield run config

    if options?.watch
      debug 'Starting watch process'
      for app, appConfig of config
        watch.watchTree (path.resolve process.cwd(), appConfig.javascripts.root), (filename) => 
          do co =>
            return unless typeof filename is 'string'
            filename = path.relative process.cwd(), filename
            contained = false
            for pack, packConfig of appConfig.javascripts.packages
              files = yield @loadFiles appConfig.javascripts.root, packConfig.files, (packConfig.extensions or 'js')
              if -1 isnt _.indexOf files, path.relative appConfig.javascripts.root, filename
                contained = true 
                break
            return unless contained
            debug "File change: #{filename}"
            mapped = _.mapValues config, (value, key) -> _.pick value, 'javascripts'
            yield run mapped
        watch.watchTree (path.resolve process.cwd(), appConfig.stylesheets.root), (filename) => 
          do co =>
            return unless typeof filename is 'string'
            filename = path.relative process.cwd(), filename
            contained = false
            for pack, packConfig of appConfig.stylesheets.packages
              files = yield @loadFiles appConfig.stylesheets.root, packConfig.files, (packConfig.extensions or 'css')
              if -1 isnt _.indexOf files, path.relative appConfig.stylesheets.root, filename
                contained = true 
                break
            return unless contained
            debug "File change: #{filename}"
            mapped = _.mapValues config, (value, key) -> _.pick value, 'stylesheets'
            yield run mapped

    results

  @runApp: (app, config) ->

    debug "Running app '#{app}'"

    result = 
      javascripts: {}
      stylesheets: {}

    yield [
      @runAppJs app, config, result
      @runAppCss app, config, result
      @runAppRouting app, config, result
    ]

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
        files = yield @buildNonNativeFiles "#{app}/#{pack}", files, options, 'js'
        
        # Run the compiler
        result.javascripts[pack] = yield JS.compile "#{app}/#{pack}", files, options
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
        files = yield @buildNonNativeFiles "#{app}/#{pack}", files, options, 'css'
        
        # Run the compiler
        result.stylesheets[pack] = yield CSS.compile "#{app}/#{pack}", files, options

  @runAppRouting: (app, config, result) ->
    # Gather angular routing
    if config?.routing
      result.routing = yield Route.compile config.routing

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
        # Find the associated compiler or throw an error if unsupported
        try 
          compiler = require "./compilers/#{ext}"
          throw new Error() unless compiler.compilesTo is nativeType
        catch e then throw new Error "Unsupported file type #{ext}\n#{e.message}"

        # Build this file into js or css
        builtFiles.push yield compiler.compile pack, file, options
      else
        builtFiles.push file

    builtFiles