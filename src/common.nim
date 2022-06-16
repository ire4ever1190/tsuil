
const 
  timeFormat* = "yyyy-MM-dd'T'hh:mm:sszz" # ISO-8601

proc point(x: string, i: int) =
  echo x
  for i in 0..<i:
    stdout.write " "
  echo "^"

