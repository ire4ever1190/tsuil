include karax/prelude
import std/[
  strutils,
  dom,
  asyncjs,
  jsfetch,
  jsonutils,
  json
]
import common
import pkg/anano
import karax/jdict

type
  Page = enum
    Search
    Edit
    Upload

var 
  page = Search 
  searchTimeout: Timeout # Used for debouncing search
  results: seq[tuple[pdf: PDFFileInfo, pages: seq[int]]]

proc doSearch(term: string) {.async.} =
  echo "Seaching for " & term
  let body = fetch(cstring "/search?query=" & term)
    .await()
    .text()
    .await().`$`
    .parseJson()
  results.setLen(0)
  for id in body.keys:
    var newResult: typeof(results[0])
    newResult.pdf   = body[id]["pdf"].jsonTo(PDFFileInfo, JOptions(allowExtraKeys: true))
    newResult.pages = body[id]["pages"].jsonTo(seq[int])
    results &= newResult
    
proc searchPage(): VNode =
  result = buildHtml(tdiv):
    tdiv(class="field"):
      input(class="input", placeHolder="Search term"):
        proc oninput(ev: Event, n: VNode) = 
          # Debounce the search
          if searchTimeout != nil:
            searchTimeout.clearTimeout()
          # Search for input, then redraw
          searchTimeout = setTimeout(proc() = 
            discard doSearch($n.value)
              .then(proc() = redraw())
          , 400)
    # Render any results
    let hideOverflow = block:
      var l = newJSeq[cstring](2)
      l[0] = "max-height: 30vh"
      l[1] = "overflow: scroll"
      l
      
    for (pdf, pages) in results:
      echo pdf
      tdiv(class="card"):
        `header`(class="card-header"):
          p(class="card-header-title"):
            text pdf.title
        tdiv(class="card-content"):
          tdiv(class="content", style = hideOverflow):
            ul:
              for page in pages:
                li:
                  a(href="/pdf/" & $pdf.id & "/#page=" & $page):
                    text $page
  
proc editPage(): VNode = 
  result = buildHtml(tdiv):
    text "Edit"

proc uploadpage(): VNode =
  result = buildHtml(tdiv):
    form(action="/pdf", `method`="post", encType="multipart/form-data"):
      tdiv(class="field has-addons"):
        tdiv(class="file has-name"):
          label(class="file-label"):
            input(`type`="file", class="file-input", name="file"):
              proc onChange(ev: Event, n: VNode) =
                # Change the name of selected file
                {.emit: "document.getElementById('fileName').innerText = `ev`.target.files[0].name;".}
            span(class="file-cta"):
              span(class="file-label"):
                text "Choose a PDF..."
            span(class="file-name", id="fileName")
        tdiv(class="control"):
          input(`type`="submit", value="Submit", class="button is-primary")


proc createDom(data: RouterData): VNode =
  page = (case $data.hashPart
    of "#/": Search
    of "#/edit": Edit
    of "#/upload": Upload
    else: Search)
  result = buildHtml(tdiv(class="columns")):
    tdiv(class="column")
    tdiv(class="column container is-fluid"):
      # Render navbar
      tdiv(class="tabs is-centered"):
        ul:
          for tab in Page:
            li(class=(if page == tab: "is-active" else: "")):
              a(href="#/" & toLowerAscii $tab):
                text $tab
      # Render current page
      case page
      of Search: searchPage()
      of Edit: editPage()
      of Upload: uploadPage()
    tdiv(class="column")

setRenderer createDom
