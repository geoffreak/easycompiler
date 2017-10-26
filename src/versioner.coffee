fs = require 'co-fs-plus'
hashFiles = require 'hash-files'
_ = require 'lodash'
path = require 'path'

{ renameFile, copyFile } = require './lib/files'
{ genToPromise, nodeCallbackToPromise } = require './lib/promisify'


class Versioner

  constructor: ->
    @store = {}

  version: genToPromise (pack, files, options) ->
    for file in files
      # Determine real path to file
      pathToFile = path.join(options.webRoot, file)
      continue if @store[pathToFile]?

      # Determine if it is already in a build directory
      relativePath = path.relative(pathToFile, options.buildRoot)
      inBuildDirectory = not relativePath.match(/[^\.\/]/)?

      # Determine a few other variables
      filename = path.basename(pathToFile)
      directory = path.resolve(options.webRoot, path.dirname(file).substr(1))
      sourceFile = path.resolve(directory, filename)

      # Calculate the file hash
      hash = yield nodeCallbackToPromise(hashFiles)({ files: [sourceFile], noGlob: true })

      if inBuildDirectory
        newPath = path.resolve(directory, "#{hash}.#{filename}")
        success = yield renameFile(sourceFile, newPath)
        throw new Error('Unable to move files') unless success
      else
        newPath = path.resolve(options.buildRoot, pack, "#{hash}.#{filename}")
        yield fs.mkdirp(path.dirname(newPath))
        success = yield copyFile(sourceFile, newPath)
        throw new Error('Unable to copy files') unless success

      @store[pathToFile] = '/' + path.relative(options.webRoot, newPath)

    return _.map files, (file) =>
      pathToFile = path.join(options.webRoot, file)
      return @store[pathToFile]


module.exports = Versioner
