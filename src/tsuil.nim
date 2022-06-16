import mike
import common
import tables
proc process(file: string) = discard

const index = slurp("../public/index.html")

"/" -> get:
  ctx.addHeader("Content-Type", "text/html")
  ctx.send(index)

"/" -> post:
  let form = ctx.multipartForm()
  echo form["name"]
  for key in form.keys:
    echo "key here: ", key
  ctx.send "cum"
run()
