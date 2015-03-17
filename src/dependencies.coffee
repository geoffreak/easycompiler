_ = require 'lodash'

class Dependencies

  constructor: ->
    @store = []

  add: (files) ->
    files = [files] unless _.isArray files
    @store.push file for file in files

  getAll: ->
    _.uniq @store

  toJSON: ->
    @getAll()


module.exports = Dependencies