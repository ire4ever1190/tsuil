import std/[
  jsonutils,
  times,
  json
]

const timeFormat* = "yyyy-MM-dd'T'hh:mm:sszz" # ISO-8601

proc toJsonHook*(a: DateTime): JsonNode =
  result = %a.format(timeFormat)

export jsonutils
