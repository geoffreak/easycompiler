fs     = require 'co-fs-plus'
path   = require 'path'
less   = require 'less'
Q      = require 'q'
debug  = require('debug')('compiler:less')
render = Q.nbind less.render, less
co     = require 'co'
_      = require 'lodash'

class module.exports

  @compilesTo: 'css'

  @compile: (pack, input, options, deps) ->
    # debug "Compiling LESS for '#{pack}': #{input}"

    # Make paths
    output    = path.resolve(options.buildRoot, pack, input) + '.css'
    input     = path.resolve options.root, input
    outputWeb = path.relative options.webRoot, output
    inputWeb  = path.relative options.webRoot, input

    # Get content from coffee file
    content = yield fs.readFile input, "utf-8"

    # Ensure output exists
    yield fs.mkdirp path.dirname output

    sourceMapDefer = Q.defer()

    # Compile less
    try
      compiled = yield render content,
        compress: true
        filename: inputWeb
        paths: [ path.join options.webRoot, path.relative options.webRoot, path.dirname input ]
        relativeUrls: true
        rootpath: "/#{path.relative options.webRoot, path.dirname output}"
        outputFilename: path.basename output
        sourceMap: true
        sourceMapURL: "#{path.basename output}.map"
        sourceMapFilename: "#{path.join options.webRoot, path.relative options.webRoot, output}.map"
        sourceMapBasepath: "#{options.webRoot}/"
        sourceMapRootpath: "/"
        writeSourceMap: (map) -> 
          # Write map
          map = JSON.parse map
          sources = _.pull map.sources, '/' + inputWeb
          deps.add _.map sources, (file) -> options.webRoot + file
          do co ->
            try
              yield fs.writeFile "#{output}.map", JSON.stringify map
              sourceMapDefer.resolve()
            catch e
              sourceMapDefer.reject e
    catch e
      throw new Error """
        LESS Compile Error
        #{e.message}
        File: #{e.filename} [line #{e.line}]
        #{e.extract.join '\n'}
      """
    
    # Write compiled file
    yield fs.writeFile output, compiled

    # Wait on written sourcemap
    yield sourceMapDefer.promise
    
    # Format paths in the same fashion as getFiles (based from root)
    path.relative options.root, output
