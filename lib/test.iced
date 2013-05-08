
fs = require 'fs'
path = require 'path'
colors = require 'colors'
deep_equal = require 'deep-equal'
urlmod = require 'url'

CHECK = "\u2714"
BAD_X = "\u2716"

##-----------------------------------------------------------------------

exports.File = class File
  constructor : (@name) ->
  new_case : () -> return new Case @
  default_init : (cb) -> cb true
  default_destroy : (cb) -> cb true

##-----------------------------------------------------------------------

exports.Case = class Case

  ##-----------------------------------------
  
  constructor : (@file) ->
    @_ok = true

  ##-----------------------------------------
  
  search : (s, re, msg) ->
    @assert (s? and s.search(re) >= 0), msg

  ##-----------------------------------------
  
  assert : (f, what) ->
    if not f
      console.log "Assertion failed: #{what}"
      @_ok = false

  ##-----------------------------------------
  
  equal : (a,b,what) ->
    if not deep_equal a, b
      [ja, jb] = [JSON.stringify(a), JSON.stringify(b)]
      console.log "In #{what}: #{ja} != #{jb}".red
      @_ok = false

  ##-----------------------------------------
  
  error : (e) ->
    console.log e.red
    @_ok = false

  ##-----------------------------------------
  
  is_ok : () -> @_ok

##-----------------------------------------------------------------------

class Runner

  ##-----------------------------------------
  
  constructor : ->
    @_files = []
    @_launches = 0
    @_tests = 0
    @_successes = 0
    @_rc = 0
    @_n_files = 0
    @_n_good_files = 0
 
  ##-----------------------------------------
  
  run_files : (cb) ->
    for f in @_files
      await @run_file f, defer()
    cb()

  ##-----------------------------------------

  new_file_obj : (fn) -> new File fn
   
  ##-----------------------------------------
  
  run_code : (fn, code, cb) ->
    fo = @new_file_obj fn
    
    if code.init?
      await code.init fo, defer err
    else
      await fo.default_init defer ok
      err = "failed to run default init" unless ok
      
    destroy = code.destroy
    delete code["init"]
    delete code["destroy"]

    @_n_files++
    if err
      @err "Failed to initialize file #{fn}: #{err}"
    else
      @_n_good_files++
      for k,v of code
        @_tests++
        C = fo.new_case()
        await v C, defer err
        if err
          @err "In #{fn}/#{k}: #{err}"
        else if C.is_ok()
          @_successes++
          @report_good_outcome "#{CHECK} #{fn}: #{k}"
        else
          @report_bad_outcome "#{BAD_X} #{fn}: #{k}"
          
    if destroy?
      await destroy fo, defer()
    else
      await fo.default_destroy defer()
      
    cb()

  ##-----------------------------------------

  err : (e, opts = {}) ->
    opts.red = true
    @log e, opts
    @_rc = -1

  ##-----------------------------------------

  report_good_outcome : (txt) ->
    @log txt, { green : true }
  report_bad_outcome : (txt) ->
    @log txt, { red : true, bold : true }

  ##-----------------------------------------

  init : (cb) -> cb true
  finish : (cb) -> cb true
 
  ##-----------------------------------------
  
##-----------------------------------------------------------------------

exports.ServerRunner = class ServerRunner extends Runner

  ##-----------------------------------------

  constructor : () ->
    super()

  ##-----------------------------------------
  
  run_file : (f, cb) ->
    try
      dat = require path.join @_dir, f
      await @run_code f, dat, defer() unless dat.skip?
    catch e
      @err "In reading #{f}: #{e}\n#{e.stack}"
    cb()

  ##-----------------------------------------

  log : (msg, { green, red, bold })->
    msg = msg.green if green
    msg = msg.bold if bold
    msg = msg.red if red
    console.log msg

  ##-----------------------------------------
  
  load_files : (mainfile, whitelist, cb) ->
    
    wld = null
    if whitelist?
      wld = {}
      wld[k] = true for k in whitelist
    
    @_dir = path.dirname mainfile
    base = path.basename mainfile
    await fs.readdir @_dir, defer err, files
    if err?
      ok = false
      @err "In reading #{@_dir}: #{err}"
    else
      ok = true
      re = /.*\.(iced|coffee)$/
      for file in files when file.match(re) and (file isnt base) and (not wld? or wld[file])
        @_files.push file
      @_files.sort()
    cb ok
   
  ##-----------------------------------------

  report : () ->
    if @_rc < 0
      @err "#{BAD_X} Failure due to test configuration issues"
    @_rc = -1 unless @_tests is @_successes

    opts = if @_rc is 0 then { green : true } else { red : true }
    opts.bold = true

    @log "Tests: #{@_successes}/#{@_tests} passed", opts
    
    if @_n_files isnt @_n_good_files
      @err " -> Only #{@_n_good_files}/#{@_n_files} files ran properly", { bold : true }
    return @_rc

  #-------------------------------------

  report_good_outcome : (msg) -> console.log msg.green
  report_bad_outcome  : (msg) -> console.log msg.bold.red

  ##-----------------------------------------

  run : (mainfile, whitelist, cb) ->
    await @init defer ok
    await @load_files mainfile, whitelist, defer ok  if ok
    await @run_files defer() if ok
    @report()
    await @finish defer ok
    cb @_rc   

##-----------------------------------------------------------------------

$ = (m) -> window.document.getElementById(m)

##-----------------------------------------------------------------------

exports.BrowserRunner = class BrowserRunner extends Runner

  constructor : (@divs) ->
    super()

  ##-----------------------------------------

  log : (m, {red, green, bold}) ->
    style = 
      margin : "0px"
    style.color = "green" if green
    style.color = "red" if red
    style.weight = "bold" if bold
    style_tag = ("k: #{v}" for k,v of style).join "; "
    tag = "<p style=\"#{style_tag}\">#{m}</p>\n"
    $(@divs.log).innerHTML += tag

  ##-----------------------------------------

  run : (modules, cb) ->
    await @init defer ok
    for k,v of modules when not v.skip
      await @run_code k, v, defer ok
    @report()
    await @finish defer ok
    $(@divs.rc).innertHTML = @_rc
    cb @_rc

##-----------------------------------------------------------------------

exports.run = (mainfile, klass = ServerRunner, whitelist = null) ->
  runner = new klass()
  await runner.run mainfile, whitelist, defer rc
  process.exit rc

##-----------------------------------------------------------------------
