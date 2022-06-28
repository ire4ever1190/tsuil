import React from 'react'

async function doSearch() {
  let term = document.getElementById("queryInput").value
  let results = await (await fetch("/search?query=" + term)).json()
  console.log(results)
}

function searchResults(results) {
  return (
    <ul>
    {
        results.map((result, index) => {
          <li key={index}>{result.pdf}: {result.page}</li>
        })
    }
    </ul>
  )
}

class App extends React.Component {
  constructor() {
    super()
    this.cacheResults = []
  }
  render() {
    return (
      <div className="App">
        <h1>Search</h1>
        <div id="searchFrom">
          <label htmlFor="query">Search: </label>
          <input type="text" id="queryInput" name="query"></input>
          <button onClick={doSearch}>Search</button>
          <searchResults results={this.cachedResults}/>
        </div>
        <h1>Upload</h1>
        <form id="uploadForm" action="/uploadfile" method="post" encType="multipart/form-data">
          <label htmlFor="file">File: </label>
          <input type="file" name="file" accept=".pdf,application/pdf"></input>
          <input type="submit"></input>
        </form>
      </div>
    );
  }
}

export default App;
