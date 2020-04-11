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

To configure emacs, we must use the package `edit-server`. However if we use the unmodified package, then
many browsers will raise a CORS error when jupyter attempts to trigger emacs. We can modify this by redefining
one of the functions used in `edit-server`, namely `edit-server-send-response`.

A [ticket](https://github.com/stsquad/emacs_chrome/issues/164) has been submitted to `edit-server` notifying them of this fix.

```elisp
(require 'edit-server)
(edit-server-start)

;; Redefine edit-server-send-response to allow CORS
(defun edit-server-send-response (proc &optional body progress)
  "send an HTTP 200 OK response back to process PROC.
Optional second argument BODY specifies the response content:
    - If nil, the HTTP response will have null content.
    - If a string, the string is sent as response content.
    - Any other value will cause the contents of the current
      buffer to be sent.
If optional third argument progress is non-nil, then the response
will include x-file and x-open headers to allow continuation of editing."
  (interactive)
  (edit-server-log proc "sending edit-server response")
  (if (processp proc)
      (let ((response-header (concat
			      "HTTP/1.0 200 OK\n"
			      (format "Server: Emacs/%s\n" emacs-version)
			      "Date: "
			      (format-time-string
			       "%a, %d %b %Y %H:%M:%S GMT\n"
			       (current-time))
                              "Access-Control-Allow-Origin: *\n"
                              "Access-Control-Allow-Headers: *\n"
			      (when progress
				(format "x-file: %s\nx-open: true\n" (buffer-name))))))
	(process-send-string proc response-header)
	(process-send-string proc "\n")
	(cond
	 ((stringp body)
	  (process-send-string proc (encode-coding-string body 'utf-8)))
	 ((not body) nil)
	 (t
	  (encode-coding-region (point-min) (point-max) 'utf-8)
	  (process-send-region proc (point-min) (point-max))))
	(process-send-eof proc)
	(edit-server-log proc "Editing done, sent HTTP OK response."))
    (message "edit-server-send-response: invalid proc (bug?)")))
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
