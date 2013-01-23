
path = require 'path'
fs   = require 'fs'

##=======================================================================

exports.mkdir_p = (d, mode, cb) ->
  console.log d
  console.log mode
  console.log cb.toString()
  parts = d.split path.sep
  cwd = [ ]
  err = null
  for p in parts when not err?
    cwd.push p
    d = path.join.apply null, cwd
    await fs.stat d, defer err, so
    if err? and err.code isnt 'ENOENT'
      err = "In directory #{d}: #{err.toString()}"
    else if so?
      err = "Path component #{d} isn't a directory" unless so.isDirectory()
    else
      await fs.mkdir d, mode, defer err
      if err
        err = "In mkdir #{d}: #{err}"
  cb err
  
