import std/[
  jsonutils,
  times,
  json
]

const timeFormat* = "yyyy-MM-dd'T'hh:mm:sszz" # ISO-8601

proc toJsonHook*(d: DateTime): JsonNode =
  result = %d.format(timeFormat)

proc fromJsonHook*(d: var DateTime, data: JsonNode) =
  d = data.str.parse(timeFormat)

export jsonutils
