-- Basic Information about a PDF
CREATE TABLE IF NOT EXISTS PDF (
  ID BLOB NOT NULL PRIMARY KEY,
  title TEXT,
  lastModified TEXT, -- Date is stored as ISO8601 string
  pages INT,
  author TEXT,
  keywords TEXT,
  subject TEXT,
  filename TEXT,
  hash BLOB UNIQUE
);

-- Store pages in seperate rows so that we can direct the user directly to the page with the text
CREATE TABLE IF NOT EXISTS PAGE (
  ID INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  num INTEGER, --What page number it is
  body TEXT
);

-- Make virtual table for full text search, allows better searching
CREATE VIRTUAL TABLE IF NOT EXISTS PAGE_fts USING fts5(
  id,
  num, 
  body 
);

-- Drop pages if the original PDF is deleted
-- CREATE TRIGGER delete_pages AFTER delete on PDF
-- BEGIN
  -- DELETE PAGE WHERE id = old.ID
-- END;

