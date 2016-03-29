easyc = require '../lib/easyc'
co    = require 'co'
args  = process.argv.slice(2)

do co ->
  try
    yield easyc.compile 
      quickBuild: true
      onlyApp:    args[0]
      onlyPack:   args[1]
      onlyPart:   args[2]
  catch e
    console.error e.stack
