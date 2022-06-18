## Implementation based on https://github.com/icyphox/nanoid.nim/blob/master/src/nanoid.nim
import std/[
  hashes,
  math,
  sysrand
]


const 
  alphabet {.strdefine.} = "_-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
  nanoIDSize* {.intdefine.} = 21
    ## The size to use for nano IDs

  mask = 63
  step = int(ceil(1.6 * mask * nanoIDSize / alphabet.len))

type
  NanoID* = array[nanoIDSize, byte]

proc genNanoID*(): NanoID =
  ## Generates a random ID
  var i = 0
  block topLevel:
    while true:
      let randomBytes = urandom(step)
      for j in 0 .. step - 1:
        var randByte = randomBytes[j] and mask
        if randByte < alphabet.len:
          result[i] = byte(alphabet[randByte])
          inc i
          if i == nanoIDSize: 
            break topLevel
