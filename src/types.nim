import std/[
  times
]

when not defined(js):
  from std/sha1 import SecureHash

import anano

type
  PDFFileInfo* = object
    ## Metadata associated with the PDF
    id*: NanoID
    title*: string
    lastModified*: DateTime
    pages*: int
    author*: string
    keywords*: string
    subject*: string 
    filename*: string
    when not defined(js):
      hash*: SecureHash # Hash of the file contents

  PDFUpdate* = object
    ## Values to overwrite PDF with
    title*: string
    subject*: string
    
  SearchResult* = object
    ## Search result from database
    page*: int
    pdf*: NanoID
