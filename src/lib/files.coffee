Debug = require 'debug'
Fs = require 'fs'
Path = require 'path'

{ genToPromise, nodeCallbackToPromise } = require './promisify'

debug = Debug('easyc:files')


###
# Remove a file
# @param {string} file - Path to the file to remove
# @returns {Promise<boolean>} If the file was removed
###
module.exports.removeFile = removeFile = genToPromise (file) ->
  debug 'Removing %s', file
  unless (yield isAccessible(file, true))
    debug 'Aborting remove: File does not exist'
    return false
  yield nodeCallbackToPromise(Fs.unlink)(file)
  return true


###
# Rename a file (if we have access)
# @param {string} source - Path to the file
# @param {string} destination - Desired path to move to
# @returns {Promise<boolean>} If the file was renamed
###
module.exports.renameFile = renameFile = genToPromise (source, destination) ->
  debug 'Renaming %s to %s', source, destination
  unless (yield isAccessible(source, true)) #and not (yield isAccessible(destination))
    debug 'Aborting rename: Source does not exist'
    return false
  yield nodeCallbackToPromise(Fs.rename)(source, destination)
  return true


###
# Copy a file
# @param {string} source - Path to the file
# @param {string} destination - Destination file (that doesn't exist yet)
# @returns {Promise<boolean>} If the file was copied
###
module.exports.copyFile = copyFile = genToPromise (source, destination) ->
  debug 'Attempting to copy %s to %s', source, destination
  # Make sure the source exists and the destination doesn't
  unless (yield isAccessible(source, true)) #and not (yield isAccessible(destination))
    debug 'Aborting copy: Source does not exist'
    return false
  # Make sure the folder of the destination is writeable
  unless (yield isAccessible(Path.dirname(destination), true))
    debug 'Aborting copy: Destination directory not exist'
    return false
  # Actually copy the file
  return yield new Promise (resolve, reject) ->
    rd = Fs.createReadStream(source)
    rd.on 'error', (err) ->
      debug 'Aborting copy: Readstream has encountered an error'
      reject err
      return
    wr = Fs.createWriteStream(destination)
    wr.on 'error', (err) ->
      debug 'Aborting copy: Writestream has encountered an error'
      reject err
      return
    wr.on 'close', (ex) ->
      debug 'Copy has completed from %s to %s', source, destination
      resolve(true)
      return
    rd.pipe(wr)
    return



###
# Check if a file exists at a path
# @param {string} path - Path to the file
# @param {boolean} [writeable=false] - Check if file is also writeable
# @returns {Promise<boolean>} If the file is accessible
###
module.exports.isAccessible = isAccessible = genToPromise (path, writeable = false) ->
  debug 'Checking if %s is accessible (writeable=%s)', path, writeable
  if Fs.constants? # Node 6.x, 8.x
    flags = if writeable then Fs.constants.R_OK | Fs.constants.W_OK else Fs.constants.F_OK
  else # Node 4.x
    flags = if writeable then Fs.R_OK | Fs.W_OK else Fs.F_OK
  try
    yield nodeCallbackToPromise(Fs.access)(path, flags)
  catch err
    return false if err.code is 'ENOENT'
    throw err
  return true
