# jupyterlab_emacs

A JupyterLab extension allowing one to edit an individual cell contents in jupyter.

## JupterLab Version
The extension has been tested up to JupyterLab version 2.0.0.

## Installation

```bash
jupyter labextension install @stucchio/jupyterlab_emacs
```

## Development

For a development installation (requires npm version 4 or later), do the following in the repository directory:

```bash
npm install
npm run build
jupyter labextension link .
```

To rebuild the package and the JupyterLab app:

```bash
npm run build
jupyter lab build
```
