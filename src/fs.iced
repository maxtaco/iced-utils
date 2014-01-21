
path = require 'path'
fs   = require 'fs'

##=======================================================================

exports.mkdir_p = mkdir_p = (d, mode = 0o755, cb) ->
  parts = d.split path.sep
  cwd = [ ]
  if (parts.length and (parts[0].length is 0)) then cwd.push path.sep
  err = null
  made = 0

  for p in parts when not err?
    cwd.push p
    d = path.join.apply null, cwd
    await fs.stat d, defer err, so
    if err? and (err.code is 'ENOENT')
      await fs.mkdir d, mode, defer err
      made++ unless err?
    else if not err? and so? and not so.isDirectory()
      err = new Error "Path component #{d} isn't a directory"
  cb err, made
  
##=======================================================================
