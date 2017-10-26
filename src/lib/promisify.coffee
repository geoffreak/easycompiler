co = require 'co'


###
# Convert generator function into one that returns a promise
# @param {Function*<T>|Function<T>} generator - The generator function (or regular one)
# @returns {Function<Promise<T>>} - Returns a function that returns the same value as the generator, but via a promise
###
module.exports.genToPromise = genToPromise = (generator) ->
  return (args...) ->
    context = @
    return new Promise (resolve, reject) ->
      do co ->
        try
          # Check if function is generator
          if generator.constructor.name is 'GeneratorFunction'
            resolve(yield generator.apply(context, args))
          else # Not actually a generator
            resolve(generator.apply(context, args))
        catch err
          reject(err)
        return
      return


###
# Convert a function that uses a node style callback into a promise
# @param {Function<T>([args...,] cb)} fn - The function that takes a node-styled callback (last parameter callback)
# @param {boolean} [resolveAllArgs=false] - Resolve more than one argument from the callback, but as an array
# @returns {Function<Promise<T>>([args...])} - Returns a function that returns the same value as the function, but via a promise
###
module.exports.nodeCallbackToPromise = nodeCallbackToPromise = (fn, resolveAllArgs = false) ->
  return (args...) ->
    context = @
    return new Promise (resolve, reject) ->
      cb = (err, result...) ->
        if err
          reject(err)
        else
          resolve(if resolveAllArgs then result else result[0])
        return
      fn.apply(context, args.concat([cb]))
      return
