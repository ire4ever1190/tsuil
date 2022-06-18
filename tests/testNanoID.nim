import nanoid
import std/[
  unittest,
  sets
]

test "No collision for 10K entries":
  var generated: HashSet[NanoID]
  for i in 0..<10_000:
    generated.incl genNanoID()
  check generated.len == 10_000
