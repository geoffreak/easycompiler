fs     = require 'co-fs-plus'
path   = require 'path'
coffee = require 'coffee-script'

class module.exports

  @compilesTo: 'js'

  @compile: (input, options) ->

    # Make paths
    output    = path.resolve(options.buildRoot, input) + '.js'
    input     = path.resolve options.root, input
    outputWeb = path.relative options.webRoot, output
    inputWeb  = path.relative options.webRoot, input

    # Get content from coffee file
    content = yield fs.readFile input, "utf-8"

    # Compile coffee
    try
      compiled = coffee.compile content,
        header: false
        bare: true
        sourceMap: true
        sourceFiles: [ "/#{inputWeb}" ]
        filename: input
    catch e
      console.error e.stack
      process.exit 1

    compiled.js += "\n//# sourceMappingURL=#{path.basename outputWeb}.map"

    # Adjust sourcemap
    map = JSON.parse compiled.v3SourceMap
    map.file = path.basename output

    # Ensure directory exists and write files
    yield fs.mkdirp path.dirname output
    yield fs.writeFile output, compiled.js
    yield fs.writeFile "#{output}.map", JSON.stringify map

    # Format paths in the same fashion as getFiles (based from root)
    path.relative options.root, output
