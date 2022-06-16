import mike
import common
import tables

proc process(file: sink string) {.gcsafe.} = 
  

const index = slurp("../public/index.html")



"/" -> get:
  ctx.addHeader("Content-Type", "text/html")
  ctx.send(index)

"/uploadfile" -> post:
  let form = ctx.multipartForm()
  let file = form["file"]
  file.filename.writeFile(file.value)
  ctx.send "done"
run()
