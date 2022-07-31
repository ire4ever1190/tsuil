include karax/prelude
import std/[
  strutils,
  dom,
  asyncjs,
  jsfetch,
  jsonutils,
  json,
  sugar,
  httpcore
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
  pdfs: seq[PDFFileInfo]
  subjects: seq[string]

proc toJson(resp: Future[Response] | Response): Future[JsonNode] {.async.} =
  ## Gets Json (nims version) from a response
  let re = when resp is Future[Response]: await resp else: resp
  result = re
    .text()
    .await().`$`
    .parseJson()

proc loadPDFS() {.async.} =
  pdfs = fetch(cstring"/pdfs")
      .toJson()
      .await()
      .jsonTo(seq[PDFFileInfo], JOptions(allowExtraKeys: true))
  # Could probably get subjects from list of PDFs but this saves having to change
  # once I implement paginatino
  subjects = fetch(cstring"/subjects")
    .toJson()
    .await()
    .to(seq[string])
  redraw()

discard loadPDFs()

proc doSearch(term: string) {.async.} =
  echo "Seaching for " & term
  let body = await fetch(cstring "/search?query=" & term).toJson()
  results.setLen(0)
  for id in body.keys:
    var newResult: typeof(results[0])
    newResult.pdf   = body[id]["pdf"].jsonTo(PDFFileInfo, JOptions(allowExtraKeys: true))
    newResult.pages = body[id]["pages"].jsonTo(seq[int])
    results &= newResult
    
proc searchPage(): VNode =
  ## Page to search through PDFs
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
                  a(href=cstring("/pdf/" & $pdf.id & "/#page=" & $page)):
                    text $page
      br()
  
proc editPage(): VNode = 
  ## Page for editing PDFs metadata
  proc textInput(value, field: string, pdf: PDFFileInfo, list: string = ""): VNode =
    let id = cstring($pdf.id & field)
    result = buildHtml(tdiv(class="panel-block")):
      tdiv(class="field"):
        label(class="label"):
          text field
        tdiv(class="control"):
          input(class="input", `type`="text", value=value, id = id, list=list)
              
  result = buildHtml(tdiv):
    # Have list of subjects so the subjects field has autocomplete
    datalist(id="autocompleteSubjects"):
      for option in subjects:
        option(value=cstring(option))
    for pdf in pdfs:
      nav(class="panel"):
        p(class="panel-heading"):
          text pdf.title
        a(class="panel-block is-active", href=cstring("/pdf/" & $pdf.id)):
          span(class="panel-icon"):
            text "📁"
          text pdf.filename
        # Have inputs for the different properties
        textInput(pdf.title, "Title", pdf)
        textInput(pdf.subject, "Subject", pdf, "autocompleteSubjects")
        
        tdiv(class="panel-block"):
          button(class="button is-primary", id = cstring $pdf.id):
            text "Update"
            proc onClick(ev: Event, n: VNode) =
              # Find the PDF and update the values (need to refind it cause of issues with closures)
              let pdfID = parseNanoID($n.id)
              let newValues = PDFUpdate(
                title: $document.getElementById(n.id & "Title").value,
                subject: $document.getElementById(n.id & "Subject").value 
              )
              # Send patch request to update PDF
              let opts = newFetchOptions(
                HttpPut,
                cstring($newValues.toJson()),
                fmCors,
                fcInclude,
                fchDefault,
                frpNoReferrer,
                false
              )
              discard fetch(cstring("/pdf/" & $pdfID), opts)
              
proc uploadpage(): VNode =
  ## Page to upload new PDFs
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
            li(class=cstring(if page == tab: "is-active" else: "")):
              a(href=cstring("#/" & toLowerAscii $tab)):
                text $tab
      # Render current page
      case page
      of Search: searchPage()
      of Edit: editPage()
      of Upload: uploadPage()
    tdiv(class="column")

setRenderer createDom
