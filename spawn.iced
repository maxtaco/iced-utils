
{spawn, exec} = require 'child_process'

##-----------------------------------------------------------------------

exports.Child = class Child

  #-----------------------------------------

  constructor : (@args, @opts) ->
    @_startup = null
    @_exit_cb = null
    @_exit_code = null
    @_filter = null

  #-----------------------------------------

  _got_data : (buffer, which) ->
    s = buffer.toString()
    process[which].write s unless @opts?.quiet

    # Maybe the parent process asked to filter stdout or stderr
    @_filter? s, which
    
    if @_startup?.check_fn s, which
      cb = @_startup.cb
      cb true
      @_startup = null

  #-----------------------------------------

  filter : (f) ->
    @_filter = f
    @
    
  #-----------------------------------------

  run : () ->
    @proc = spawn 'iced', @args
    @proc.stderr.on 'data', (buffer) => @_got_data buffer, 'stderr'
    @proc.stdout.on 'data', (buffer) => @_got_data buffer, 'stdout'
    @proc.on 'exit', (status) => @_got_exit status
    @

  #-----------------------------------------

  kill : (sig) -> @proc.kill sig
   
  #-----------------------------------------

  startup_check : (check_fn, cb) ->
    @_startup = { check_fn, cb }
    @

  #-----------------------------------------

  _got_exit : (status) ->
    @_exit_code = status
    if @_startup?
      cb = @_startup.cb
      cb false
      @_startup = null
    @_exit_cb status if @_exit_cb

  #-----------------------------------------

  wait : (cb) ->
    if @_exit_code
      cb @_exit_code
    else
      @_exit_cb = cb

##-----------------------------------------------------------------------

exports.spawn = (args, cb) ->
  await (new Child args).run().wait defer status
  cb status

##-----------------------------------------------------------------------
