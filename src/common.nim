import std/[
  jsonutils,
  times,
  json
]

import types

const timeFormat* = "yyyy-MM-dd'T'hh:mm:sszz" # ISO-8601

proc toJsonHook*(d: DateTime): JsonNode =
  result = %d.format(timeFormat)

proc fromJsonHook*(d: var DateTime, data: JsonNode) =
  d = data.str.parse(timeFormat)


when not defined(js):
  import std/sha1

  proc toJsonHook*(h: SecureHash): JsonNode =
    result = newJString($h)

  proc fromJsonHook*(h: var SecureHash, data: JsonNode) =
    h = data.str.parseSecureHash()

export jsonutils
export types
