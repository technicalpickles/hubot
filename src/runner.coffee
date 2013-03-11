Path     = require 'path'
Fs       = require 'fs'
Robot    = require './robot'

run = (Options)->
  adapterPath = Path.join __dirname, "adapters"

  robot = new Robot adapterPath, Options.adapter, Options.enableHttpd, Options.name

  if Options.version
    console.log robot.version
    process.exit 0

  robot.alias = Options.alias

  robot.adapter.on 'connected', ->
    scriptsPath = Path.resolve ".", "scripts"
    robot.load scriptsPath

    srcScriptsPath = Path.resolve ".", "src", "scripts"
    robot.load srcScriptsPath

    hubotScripts = Path.resolve ".", "hubot-scripts.json"
    Fs.exists hubotScripts, (exists) ->
      if exists
        Fs.readFile hubotScripts, (err, data) ->
          if data.length > 0
            try
              scripts = JSON.parse data
              hubotScriptsPath = Path.resolve "node_modules", "hubot-scripts", "src", "scripts"
              robot.loadHubotScripts hubotScriptsPath, scripts
            catch err
              console.error "Error parsing JSON data from hubot-scripts.json: #{err}"
              process.exit(1)

    externalScripts = Path.resolve ".", "external-scripts.json"
    Fs.exists externalScripts, (exists) ->
      if exists
        Fs.readFile externalScripts, (err, data) ->
          if data.length > 0
            try
              scripts = JSON.parse data
            catch err
              console.error "Error parsing JSON data from external-scripts.json: #{err}"
              process.exit(1)
            robot.loadExternalScripts scripts

    for path in Options.scripts
      if path[0] == '/'
        scriptsPath = path
      else
        scriptsPath = Path.resolve ".", path
      robot.load scriptsPath

  robot.run()

module.exports =
  run: run
