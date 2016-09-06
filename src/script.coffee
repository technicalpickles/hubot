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
    # FIXME assigning local scope so the robot handler can access is a little weird
    @listeners = listeners = []
    @documentation = documentation = {}
    @documentation.commands = []
    script = this
    # FIXME is this still used? prefer @documentation.commands
    @commands = []
    @logger = @robot?.logger
    @name = Path.basename(@path).replace /\.(coffee|js)$/, ''

    # local scope for the method below
    parseCommand = @parseCommand

    # TODO try not to rely on proxy objects here
    robotHandler =
      get: (target, key) ->
        # don't do respond, since it uses hear under the hood
        if key in ['listen', 'hear']
          listenerHandler =
            apply: (target, ctx, args) ->
              listener = Reflect.apply(arguments...)
              listeners.push(listener)
              listener.script = script

              help = listener?.options?.help
              if help?
                if Array.isArray(help)
                  documentation.commands.push parseCommand(command) for command in help
                else
                  documentation.commands.push parseCommand(help)
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

  parseCommand: (command) ->
    split = command.split(" - ")
    if split.length is 2
      {command: split[0], description: split[1], command_with_description: command}
    else
      @robot.logger.warning "Couldn't split '#{command}' into 2 strings for output"
      {command: command, command_with_description: command}

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
        if currentSection is 'commands'
          @documentation[currentSection] = []
        else
          @documentation[currentSection] = ""

      else
        if currentSection
          if currentSection is 'commands'
            @documentation[currentSection].push @parseCommand(cleanedLine)
          else
            if @documentation[currentSection].length > 0
              # TODO maybe sanity check description being more than one line?
              cleanedLine = "\n#{cleanedLine}"

            @documentation[currentSection] = @documentation[currentSection].concat(cleanedLine)

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
