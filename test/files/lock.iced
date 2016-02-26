
{Table,Lock} = require('../..').lock

exports.test_lock_simple = (T,cb) ->
  l = new Lock()
  await l.acquire defer()
  l.release()
  await l.acquire defer()
  l.release()
  cb()

exports.test_lock_table_simple = (T,cb) ->
  tab = new Table()
  await tab.acquire "foo", defer foo
  await tab.acquire "bar", defer bar
  foo.release()
  bar.release()
  cb()