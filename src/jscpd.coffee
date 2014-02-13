_ = require "underscore"
logger = require 'winston'
path = require "path"
glob = require "glob"
yaml = require 'js-yaml'
fs   = require 'fs'

TokenizerFactory = require './tokenizer/TokenizerFactory'

{Detector} = require './detector'
{Strategy} = require './strategy'
{Report} = require './report'

class jscpd

  LANGUAGES: Object.keys TokenizerFactory::LANGUAGES

  readConfig: (file) ->
    file = file.replace '//', '/'
    doc = {}
    try
      doc = yaml.safeLoad(fs.readFileSync(file, 'utf8'));
      logger.info "Used config from #{file}"
    catch e
      logger.warn "File #{file} not found in current directory"
    doc

  run: (options)->
    cwd = options.path
    config = @readConfig("#{cwd}/.cpd.yaml")

    options = _.extend
      'min-lines': 5
      'min-tokens': 70
      files: null
      exclude: null
      languages: jscpd::LANGUAGES
      coffee: false
      output: null
      path: null
      ignore: null
      verbose: off
      verify: off
    , options

    options = _.extend options, config

    if config.path
      options.path = "#{cwd}/#{config.path}"
      cwd = options.path

    options.languages = ['coffeescript'] if options.coffee

    options.extensions = TokenizerFactory::getExtensionsByLanguages(options.languages)

    excludes = []
    if options.files is null
      patterns = ["**/*.+(#{options.extensions.join '|'})"]
    else
      unless Array.isArray(options.files)
        patterns = [options.files]
      else
        patterns = options.files
    if options.exclude is null
      excludes = ["**/#{options.ignore}/**"] if options.ignore
    else
      unless Array.isArray(options.exclude)
        excludes = [options.exclude]
      else
        excludes = options.exclude

    logger.info("options", options) if options.verify

    files = []
    excluded_files = []

    _.forEach patterns, (pattern) ->
      files = _.union files, glob.sync(pattern, cwd: cwd)

    if excludes.length > 0
      _.forEach excludes, (pattern) ->
        excluded_files = _.union excluded_files, glob.sync(pattern, cwd: cwd)

    files = _.difference files, excluded_files
    files = _.map files, (file) -> "#{cwd}/#{file}"

    if options.verify
      logger.info("Files", files) if options.verify
    else
      logger.info "Scaning #{files.length} files for copies..." if files.length

      strategy = new Strategy options.languages
      detector = new Detector strategy

      report = new Report
        verbose: options.verbose
        output: options.output

      codeMap = detector.start files, options['min-lines'], options['min-tokens']
      logger.info 'Scaning... done!\n'

      logger.info 'Start report generation...\n'
      report.generate codeMap

module.exports = jscpd