
fs = require 'fs'
{prng} = require 'crypto'
{a_json_parse} = require './util'
{athrow,make_esc} = require 'iced-error'

#==========================================================================

_all = []

#==========================================================================

get_id = () -> prng(16).toString('hex')

#==========================================================================

read_all = (fd, cb) ->
  err = null
  eof = false
  bufs = []
  l = 0x1000
  until err? or eof
    b = new Buffer l
    await fs.read fd, b, 0, l, null, defer err, nbytes
    if not err? then # noop
    else if nbytes = 0
    else
      b = b[0...nbytes]
      bufs.push b
  cb err,  Buffer.concat(b)

#==========================================================================

class Lockfile

  #--------------------

  constructor : ({@filename, wait_limit, poke_timeout, poke_interval, retry_interval, mode, @log}) ->
    @retry_interval = retry_interval or 100                 # Retry every interval ms
    @poke_interval  = poke_interval or 100                  # poke the file every 100ms
    @poke_timeout   = poke_timeout or (@poke_interval * 20) # after 20 missed pokes, declare failure
    @wait_limit     = 10*1000                               # give up the wait after 10s
    @mode           = mode or 0o644                         # prefered file mode 
    @id             = get_id()
    @_locked        = false
    @_maintain_cb   = null

  #--------------------

  _log : (level, s) ->
    if @log?
      s = "#{@filename}: #{s}"
      @log[level] s

  #--------------------

  @warn : (s) -> @_log 'warn', s
  @info : (s) -> @_log 'info', s

  #--------------------

  _acquire_1 : (cb) ->
    res = false
    await fs.open @filename, 'wx', @mode, defer err, @fd
    if not err? then res = true
    else
      await @_acquire_1_fallback defer err
      @warn err.message if err?
    cb res

  #--------------------

  _lock_dat : () -> JSON.stringify [ Date.now(), @id, process.pid ]

  #--------------------

  _acquire_1_fallback : (cb) ->
    esc = make_esc cb, "_acquire_1_fallback"
    err = null
    await fs.open @filename, 'r', esc defer rfd
    await read_all rfd, esc defer buf
    await a_json_parse buf, esc defer jso
    if not Array.isArray(jso) or jso.length < 2
      err = new Error "Bad lock file; expected an array with 2 values"
    else if (Date.now() - jso[0]) < @poke_timeout then # noop, still locked?
    else if jso[1] is @id
      await @fs.unlink @filename, esc defer()
      obj = @_lock_dat() 
      await fs.writeFile @filename, obj, { encoding : 'utf8', @mode}, esc defer()
    cb null

  #--------------------

  acquire : (cb) ->
    acquired = false
    start = Date.now()
    loop
      await @_acquire_1 defer acquired
      break if acquired
      break if @wait_limit and (Date.now() - start) > @wait_limit
      await setTimeout defer(), @retry_interval
    if acquired
      @maintain_lock_loop()
    cb acquired

  #--------------------

  unlock : () ->
    if @_locked
      @_locked = false
      @_maintain_cb?()
    else
      @warn "tried to unlock file that wasn't locked"

  #--------------------

  maintain_wait : (cb) ->
    rv = new iced.Rendezvous()
    @_maintain_cb = rv.defer()
    setTimeout rv.defer(), @poke_interval
    await rv.wait defer()
    cb()

  #--------------------

  maintain_lock_loop : () ->
    @_locked = true
    while @_locked
      b = @_lock_dat()
      await fs.write @fd, b, 0, b.length, 0, defer err
      if err?
        @warn "error in maintain_lock_loop: #{err}"
      await @maintain_wait defer()
    await fs.unlink @filename, defer err
    if err?
      @warn "error deleting lock file: #{err}"

#==========================================================================

exports.Lockfile = Lockfile

#==========================================================================

