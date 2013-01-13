
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

  new_case : () ->
    return new Case @

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

exports.Runner = class Runner

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
  
  err : (e) ->
    console.log e.red
    @_rc = -1

  ##-----------------------------------------
  
  load_files : (cb) ->
    @_dir = path.dirname __filename
    base = path.basename __filename
    await fs.readdir @_dir, defer err, files
    if err?
      ok = false
      @err "In reading #{@_dir}: #{err}"
    else
      ok = true
      re = /.*\.(iced|coffee)$/
      for file in files when file.match(re) and file isnt base
        @_files.push file
      @_files.sort()
    cb ok
  
  ##-----------------------------------------
  
  run_files : (cb) ->
    for f in @_files
      await @run_file f, defer()
    cb()

  ##-----------------------------------------

  new_file_obj : (fn) -> new File fn
  default_init : (cb) -> cb true
  default_destroy : (cb) -> cb true
   
  ##-----------------------------------------
  
  run_code : (fn, code, cb) ->
    fo = @new_file_obj fn
    
    if code.init?
      await code.init fo, defer err
    else
      await @default_init defer ok
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
          console.log "#{CHECK} #{fn}: #{k}".green
        else
          console.log "#{BAD_X} #{fn}: #{k}".bold.red
          
    if destroy?
      await destroy fo, defer()
    else
      await @default_destroy defer()
      
    cb()

  ##-----------------------------------------
  
  run_file : (f, cb) ->
    try
      dat = require path.join @_dir, f
      await @run_code f, dat, defer()
    catch e
      @err "In reading #{f}: #{e}\n#{e.stack}"
    cb()

  ##-----------------------------------------

  run : (cb) ->
    await @load_files defer ok
    await @run_files defer() if ok
    @report()
    cb @_rc
   
  ##-----------------------------------------

  report : () ->
    if @_rc < 0
      console.log "#{BAD_X} Failure due to test configuration issues".red
    @_rc = -1 unless @_tests is @_successes
    f = if @_rc is 0 then colors.green else colors.red
    
    console.log f "Tests: #{@_successes}/#{@_tests} passed".bold
    
    if @_n_files isnt @_n_good_files
      console.log (" -> Only #{@_n_good_files}/#{@_n_files}" + 
         " files ran properly").red.bold
    return @_rc
    
  ##-----------------------------------------
  
##-----------------------------------------------------------------------

exports.run = (klass) ->
  runner = new klass()
  await runner.run defer rc
  process.exit rc

##-----------------------------------------------------------------------
