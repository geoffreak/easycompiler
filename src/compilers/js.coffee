fs       = require 'co-fs-plus'
path     = require 'path'
_        = require 'lodash'
Template = require './template'
uglify   = require 'uglify-js'
debug    = require('debug')('compiler:js')


class module.exports

  @compile: (pack, files, options) ->
    debug "Compiling JavaScript for '#{pack}'"
    
    # Map all files to full system paths
    files = _.map files, (file) => path.resolve options.root, file

    # Angular template caching
    if options.angularTemplates?
      debug "Finding Angular Templates for '#{pack}'"
      # Parse files to grab angular templates
      yields = []
      tc = new Template pack, options
      for file in files
        yields.push tc.parseAndAddFromFile file
      yield yields

      if tc.hasTemplates()
        files.push yield tc.writeCache()

    # Combine JavaScript for prod
    minifiedFiles = []
    unless options.skipMinify
      debug "Minifying JavaScript for '#{pack}' (#{files.length} files)"
      if files.length
        # Create common paths
        output    = path.resolve options.buildRoot, "#{pack}.min.js"
        outputWeb = path.relative options.webRoot, output

        # Use uglify to concat and minify (optional)
        minified = uglify.minify files, 
          outSourceMap: "#{path.basename outputWeb}.map"
          compress: if options.minify in ['false', false] then false else {}
        
        # Fix source map
        map = JSON.parse minified.map
        map.file = outputWeb # Fixing filename that Uglify does wrong
        for source, s in map.sources # Fixing source urls that Uglify does wrong
          map.sources[s] = '/' + path.relative options.webRoot, source
        
        # Write files
        yield fs.mkdirp path.dirname output
        yield fs.writeFile output, minified.code
        yield fs.writeFile "#{output}.map", JSON.stringify map

        minifiedFiles.push "/#{outputWeb}"

    # Fix URLs to be relative to root
    webFiles = _.map files, (file) => '/' + path.relative options.webRoot, file

    # Package results
    results =
      dev:  webFiles
      prod: minifiedFiles