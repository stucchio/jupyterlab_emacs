# jupyterlab_emacs

A JupyterLab extension allowing one to edit individual cell contents in jupyter. This is dependent on
the [edit-server](https://github.com/stsquad/emacs_chrome/blob/master/servers/edit-server.el) package
for Emacs, which also allows you to do similar things from Chrome/Firefox (but crucially, not from fancy
textareas like those in Jupyter).

## JupterLab Version
The extension has been tested up to JupyterLab version 2.0.0.

## Installation

This will eventually work (but currently does not):

```bash
jupyter labextension install @stucchio/jupyterlab_emacs
```

### Setting up emacs

To configure emacs, we must use the package `edit-server`. We also need to customize this package slightly,
so after installing it you must place the file `edit_server_jupyterlab.el` someplace that emacs can find it.

Next up, put the following into your `.emacs.d/init.el` file:

```elisp
(require 'edit-server)
(edit-server-start)
(load-file "path_to_edit_server_jupyterlab.el")
```


### Configuring keyboard shortcuts in Jupyter

Edit-with-emacs is something you probably want to do frequently. Accessing it via the command palette is too slow.

This can be configured in Jupyterlab by going to Settings -> Advanced Settings Editor -> Keyboard Shortcuts, and
adding the following under "User Preferences".

This will bind the `E` key to `edit-in-emacs`, for example.


```json
{
    "shortcuts": [
        {
            "command": "externaleditor:edit-in-emacs",
            "keys": [
                "E"
            ],
            "selector": ".jp-Notebook:focus"
        }
    ]
}
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

## Credits

Written by [Chris Stucchio](mailto:hi@chrisstucchio.com), and based on code from [Jupyterlab Spellchecker](https://github.com/ijmbarr/jupyterlab_spellchecker) which I took as a template.
