fs        = require 'co-fs-plus'
path      = require 'path'
_         = require 'lodash'
less      = require 'less'
Q         = require 'q'
CleanCSS  = require 'clean-css'
render    = Q.nbind less.render, less

class module.exports

  @compile: (pack, files, options) ->
    
    # Map all files to full system paths
    files = _.map files, (file) => path.resolve options.root, file

    # Combine JavaScript for prod
    minifiedFiles = []
    if files.length
      # Make paths
      output    = path.resolve options.buildRoot, "#{pack}.min.css"
      outputWeb = path.relative options.webRoot, output

      # Fetch CSS content in parallel
      yields = []
      for file in files
        yields.push fs.readFile file, "utf-8"
      cssDump = yield yields
      cssDump = cssDump.join '\n'

      if options.minify in ['false', false]
        # Don't minify CSS
        minimized = cssDump
      else
        # Minify CSS
        cleaner = new CleanCSS
          compatibility: 'ie8'
          keepSpecialComments: 0
        minimized = cleaner.minify cssDump

      # Write files
      yield fs.mkdirp path.dirname output
      yield fs.writeFile output, minimized
      
      minifiedFiles.push "/#{outputWeb}"

    # Fix URLs to be relative to root
    webFiles = _.map files, (file) => '/' + path.relative options.webRoot, file

    # Package results
    results =
      dev: webFiles
      prod: minifiedFiles