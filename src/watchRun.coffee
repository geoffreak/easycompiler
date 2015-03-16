easyc = require '../lib/easyc'
co    = require 'co'

do co ->
  try
    yield easyc.compile quickBuild: true
  catch e
    console.error e.stack
