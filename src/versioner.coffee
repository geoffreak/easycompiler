hashFiles = require 'hash-files'
_ = require 'lodash'
path = require 'path'
Q = require 'q'

class Versioner

  constructor: () ->
    @store = {}

  version: (files, options) ->
    for file in files
      pathToFile = path.join options.webRoot, file
      continue if @store[pathToFile]?

      deferred = Q.defer()
      hashFiles { files: [pathToFile], noGlob: true }, deferred.makeNodeResolver()
      @store[pathToFile] = yield deferred.promise

    return _.map files, (file) =>
      pathToFile = path.join options.webRoot, file
      return file + '?h=' + @store[pathToFile]


module.exports = Versioner
