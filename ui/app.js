import React, {useState} from 'react'
import {
    Box,
    Button,
    Card,
    CardActions,
    CardContent,
    Container, createTheme, CssBaseline,
    IconButton,
    ListItem,
    Stack,
    TextField, ThemeProvider,
    Typography
} from "@mui/material";
import SearchIcon from "@mui/icons-material/Search";
import * as PropTypes from "prop-types";


const darkTheme = createTheme({
    palette: {
        mode: 'dark',
    },
});


async function doSearch() {
    let term = document.getElementById("query").value
    let results = await (await fetch("/search?query=" + term)).json()
    console.log(results)
    return results
}


function SearchResults(props) {
    let pdfs = []
    const {results} = props;
    for (const id in results) {
        const pdf = results[id]
        pdfs.push(
            <ListItem key="{id}">
                <Card>
                    <CardContent>
                        {pdf.title}
                    </CardContent>
                    <CardActions>
                        <details>
                            <summary>Pages</summary>
                            <ul>
                                {pdf.pages.map(page => {
                                    const url = "/pdf/" + id + "#page=" + page
                                    return <li key={page}>
                                        <a target="_blank" rel="noreferrer" href={url}>{page}</a>
                                    </li>
                                })}
                            </ul>
                        </details>
                    </CardActions>
                </Card>
            </ListItem>)
    }
    return (
        <Stack>
            {pdfs}
        </Stack>
    )
}

function pdfResults(pdf) {
    return (
        <div>
        </div>
    )
}


function RaisedButton(props) {
    return null;
}

RaisedButton.propTypes = {
    label: PropTypes.string,
    containerElement: PropTypes.string,
    children: PropTypes.node
};

function App() {
    const [results, setResults] = useState([])
    return (
        <ThemeProvider theme={darkTheme}>
            <CssBaseline enableColorScheme/>
            <Container maxWidth="sm">

                <Typography variant="h2" component="div" gutterBottom>
                    Search
                </Typography>
                <div id="searchFrom">
                    <TextField
                        id="query"
                        label="Search: "
                        variant="outlined"
                        InputProps={{
                            endAdornment: <IconButton onClick={() => doSearch().then(x => setResults(x))}>
                                <SearchIcon/>
                            </IconButton>
                        }}
                    />
                    <SearchResults results={results}/>
                </div>
                <Typography variant="h2" component="div" gutterBottom>
                    Upload
                </Typography>
                <form id="uploadForm" action="/uploadfile" method="post" encType="multipart/form-data">
                    <label htmlFor="upload-photo">
                        <input
                            style={{display: 'none'}}
                            id="upload-photo"
                            name="upload-photo"
                            type="file"
                            onChange={(f) => console.log(f)}
                        />

                        <Button color="secondary" variant="contained" component="span">
                            Upload button
                        </Button>
                    </label>
                </form>
            </Container>
        </ThemeProvider>
    );
}


export default App;
