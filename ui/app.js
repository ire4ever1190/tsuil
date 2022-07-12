import React, {useState} from 'react'
import {
    Button,
    ButtonGroup,
    Card,
    CardActions,
    CardContent,
    Container,
    createTheme,
    CssBaseline,
    IconButton,
    ListItem,
    Stack,
    Tab,
    Tabs,
    TextField,
    ThemeProvider,
    Typography,
} from "@mui/material";
import SearchIcon from "@mui/icons-material/Search";
import UploadFileIcon from '@mui/icons-material/UploadFile';
import {Route, NavLink} from "react-router-dom";

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

/**
 * Handles upload for PDF files
 */
function FileUpload() {
    const [files, setFiles] = useState([])
    return (<form id="uploadForm" action="/pdf" method="post" encType="multipart/form-data">
        <ButtonGroup variant="contained">
            <label htmlFor="upload-file">
                <input
                    style={{display: 'none'}}
                    id="upload-file"
                    name="file"
                    type="file"
                    multiple
                    accept=".pdf"
                    onChange={(e) => {
                        // Convert files to a list so we can work with
                        // it easier
                        let res = []
                        let files = e.target.files
                        for (let i = 0; i < files.length; ++i) {
                            res.push(files.item(i))
                        }
                        setFiles(res)
                    }}
                />
                <Button color="secondary" variant="contained" component="span">
                    Upload button
                </Button>
            </label>

            <label htmlFor="submit-file">
                <Button
                    variant="contained"
                    component="span"
                    onClick={() => document.getElementById("uploadForm").submit()}

                >
                    <UploadFileIcon/>
                </Button>
            </label>

        </ButtonGroup>

        <ul>
            {files.map((f, i) => <li key={i}>{f.name}</li>)}
        </ul>
    </form>)
}


function SearchResults(props) {
    let pdfs = []
    const {results} = props;
    for (const id in results) {
        const pdf = results[id]
        pdfs.push(<ListItem key="{id}">
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
    return (<Stack>
        {pdfs}
    </Stack>)
}

function Title(props) {
    let {text} = props
    return (<Typography variant="h2" component="div" gutterBottom>
        {text}
    </Typography>)
}

function Upload() {
    return (
        <div>
            <FileUpload></FileUpload>
        </div>
    )
}

function Search() {
    const [results, setResults] = useState([])
    return (
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
            <SearchResults results={results}/></div>)
}

function LinkTab(props) {
    return (<Tab
        component="a"
        onClick={(event) => {
            event.preventDefault();
        }}
        {...props}
    />);
}

function App() {
    const [currTab, setTab] = React.useState(0);

    const handleChange = (event, newValue) => {
        setTab(newValue);
    };
    console.log(currTab)
    // I could not get React router working for the live of me
    // therefore I resort to this shit. To anyone screaming at their screen
    // that I should've used Router, I'm sorry...
    let currPage
    switch (currTab) {
        case 0:
            currPage = <Search></Search>
            break
        case 1:
            currPage = <Upload></Upload>
            break
    }
    return (<ThemeProvider theme={darkTheme}>
        <CssBaseline enableColorScheme/>
        <Container maxWidth="sm">
                <Tabs aria-label="nav bar" value={currTab} onChange={handleChange}>
                    <Tab label="Search" to="/"/>
                    <Tab label="Upload" to="/upload"/>
                    <Tab label="Edit PDFs" to="/edit"/>
                </Tabs>
            {currPage}
                    {/*<Routes>*/}
                    {/*    <Route exact path='/' element={<Search/>}/>*/}
                    {/*    <Route path='/upload' element={<Upload/>}/>*/}
                    {/*    /!*<Route path='/edit' element={<Edit/>}/>*!/*/}
                    {/*</Routes>*/}
        </Container>
    </ThemeProvider>);
}


export default App;
