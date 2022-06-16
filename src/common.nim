import mike
import std/strtabs
import std/parseutils
import std/tables
import strutils
import std/strtabs

const 
  timeFormat* = "yyyy-MM-dd'T'hh:mm:sszz" # ISO-8601

type
  MultipartValue = object
    name, value: string
    params: StringTableRef

{.push inline.}
proc filename*(mv: MultipartValue): string =
  result = mv.params["filename"]

proc contentType*(mv: MultipartValue): string =
  result = mv.params["Content-Type"]
  
{.pop.}

type State = enum
  Sep
  Head
  Body

proc point(x: string, i: int) =
  echo x
  for i in 0..<i:
    stdout.write " "
  echo "^"

proc multipartForm*(ctx: Context): Table[string, MultipartValue] =
  ## Got multipart data from context
  let contentHeader = ctx.getHeader("Content-Type")
  let boundary = "\c\L--" & contentHeader[contentHeader.rfind("boundary=") + 9 .. ^1]
  let body = ctx.body
  var inBody = false

  var i = 0
  var state = Sep
  var currVal = MultipartValue(params: newStringTable())
  
  # echo body.mapIt(ord it)
  while i < body.len:
    var line: string
    case state
    of Sep:
      i += body.parseUntil(line, "\c\L", i) + 2
      # Add the current value to the result if needed
      # then just start parsing head
      if currVal.name != "":
        echo "currval: ", currVal
        result[currVal.name] = currVal
        currVal = MultipartValue(params: newStringTable())
      state = Head
    of Head:
      i += body.parseUntil(line, "\c\L", i) + 2
      if line == "":
        echo ord body[i - 2]
        echo ord body[i - 3]
      if line == "" and body[i - 4] == '\c' and body[i - 3] == '\L':
        echo "el body"
        
        state = Body
      else:
        var key: string
        var lineI = line.parseUntil(key, ':') 
        if key == "Content-Disposition":
          # Parse the Content-Dispotition which has some special values
          # We don't care about the disposition type so we just skip to the params
          var value: string
          while lineI < line.len:
            value.setLen 0
            key.setLen 0
            # Skip past unneeded stuff
            lineI += line.skipUntil(';', lineI)
            lineI += line.skipWhile({';', ' '}, lineI)
            # Get key
            lineI += line.parseUntil(key, '=', lineI) + 1
            # Accoring to the RFC, short values that aren't special don't need to be
            # quoted so the quotes might be optional
            if line[lineI] == '"': 
              inc lineI
            lineI += line.parseUntil(value, {'"', ';'}, lineI) + 1
            # Name is special
            if key == "name":
              currVal.name = value
            else:
              currVal.params[key] = value
        else:
          lineI += line.skipWhile({':', ' '}, lineI)
          currVal.params[key] = line[lineI .. ^1] 
    of Body:
      i += body.parseUntil(currVal.value, boundary, i) + 2
      state = Sep
  if currVal.name != "":
    result[currVal.name] = currVal
