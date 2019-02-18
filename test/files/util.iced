{bufeq_secure} = require('../../lib/main').util

exports.test_bufeq_secure = (T,cb) ->
  a = Buffer.from [0xde, 0xad, 0xbe, 0xef]
  b = Buffer.from [222, 173, 190, 239]

  T.assert bufeq_secure a, b

  bad_1 = Buffer.from [221, 173, 190, 239]
  bad_2 = Buffer.from [222, 173, 190, 238]
  bad_3 = Buffer.from [222, 173, 190]
  bad_4 = Buffer.from [222, 173, 190, 239, 150]
  bad_5 = Buffer.from [222, 173, 190, 239, 0]
  bad_6 = Buffer.from []
  for bad in [bad_1, bad_2, bad_3, bad_4, bad_5, bad_6]
    T.assert not (bufeq_secure a, bad)
  cb()
