
path = require 'path'
fs   = require 'fs'

##=======================================================================

exports.mkdir_p = (d, mode, cb) ->
  parts = path.split d
  cwd = [ ]
  err = null
  for p in parts when not err?
    cwd.push p
    d = path.join.apply null, cwd
    await fs.stat d, defer err, so
    if err?
      err = "In directory #{d}: #{err}"
    else
      await fs.mkdir d, mode, defer err
      if err
        err = "In mkdir #{d}: #{err}"
  cb err
  
