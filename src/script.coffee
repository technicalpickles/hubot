Reflect        = require('harmony-reflect');
Path           = require 'path'
Fs             = require 'fs'
{inspect}      = require 'util'

HUBOT_DOCUMENTATION_SECTIONS = [
  'description'
  'dependencies'
  'configuration'
  'commands'
  'notes'
  'author'
  'authors'
  'examples'
  'tags'
  'urls'
]

class Script
  constructor: (@robot, @path) ->
    @listeners = []
    @documentation = {}
    @commands = []
    @logger = @robot?.logger
    @listeners = listeners = []
    @name = Path.basename(@path).replace /\.(coffee|js)$/, ''

    robotHandler =
      get: (target, key) ->
        if key in ['listen', 'hear', 'respond']
          listenerHandler =
            apply: (target, ctx, args) ->
              console.log "intercepted respond(#{inspect args})"
              listener = Reflect.apply(arguments...)
              listeners.push(listener)
              listener
          new Proxy(target[key], listenerHandler)
        else
          target[key]
    @robotProxy = new Proxy(@robot, robotHandler)

  load: () ->
    ext  = Path.extname @path
    path_without_ext = Path.join Path.dirname(@path), Path.basename(@path, ext)
    if require.extensions[ext]
      try
        script = require(path_without_ext)

        if typeof script is 'function'
          script @robotProxy
          @parseHelp @path
        else
          @logger.warning "Expected #{@path} to assign a function to module.exports, got #{typeof script}"

      catch error
        @logger.error "Unable to load #{@path}: #{error.stack}"
        # FIXME throw error instead of exit
        process.exit(1)

  parseHelp: () ->
    @logger.debug "Parsing help for #{@path}"
    body = Fs.readFileSync @path, 'utf-8'

    currentSection = null
    for line in body.split "\n"
      break unless line[0] is '#' or line.substr(0, 2) is '//'

      cleanedLine = line.replace(/^(#|\/\/)\s?/, "").trim()

      continue if cleanedLine.length is 0
      continue if cleanedLine.toLowerCase() is 'none'

      nextSection = cleanedLine.toLowerCase().replace(':', '')
      if nextSection in HUBOT_DOCUMENTATION_SECTIONS
        currentSection = nextSection
        @documentation[currentSection] = []
      else
        if currentSection
          @documentation[currentSection].push cleanedLine.trim()
          if currentSection is 'commands'
            @commands.push cleanedLine.trim()

    if currentSection is null
      @logger.info "#{@path} is using deprecated documentation syntax"
      @documentation.commands = []
      for line in body.split("\n")
        break    if not (line[0] is '#' or line.substr(0, 2) is '//')
        continue if not line.match('-')
        cleanedLine = line[2..line.length].replace(/^hubot/i, @name).trim()
        @documentation.commands.push cleanedLine
        @commands.push cleanedLine

    true

Script.load = (robot, path) ->
  script = new Script(robot, path)
  script.load()

  script

Script.parseHelp = (robot, path) ->
  script = new Script(robot, path)
  script.parseHelp()

  script

module.exports = Script
