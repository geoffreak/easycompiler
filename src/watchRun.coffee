easyc = require '../lib/easyc'
co    = require 'co'

do co ->
  try
    yield easyc.compile 
      quickBuild: true
      onlyApp:    if process.env.app then process.env.app?.split(',') else []
      onlyPack:   if process.env.pack then process.env.pack?.split(',') else []
      onlyPart:   if process.env.part then process.env.part?.split(',') else []
  catch e
    console.error e.stack
