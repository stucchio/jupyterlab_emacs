import {
    JupyterFrontEnd, JupyterFrontEndPlugin
} from '@jupyterlab/application';

import {
    IEditorTracker
} from '@jupyterlab/fileeditor';

import {
    INotebookTracker
} from '@jupyterlab/notebook';


import {
  ICommandPalette
} from '@jupyterlab/apputils';


const http = require('http');

declare function require(name:string): any;

/**
 * EditWithEmacs
 */
class EditWithEmacs {
    dictionary: any;
    dict_promise: any;
    app: JupyterFrontEnd;
    tracker: INotebookTracker;
    palette: ICommandPalette;
    editor_tracker: IEditorTracker;

    // Default Options
    accepted_types = [
        'text/plain',
        'text/x-ipythongfm',   // IPython GFM = GitHub Flavored Markdown, applies to all .md files
    ];

    constructor(app: JupyterFrontEnd, notebook_tracker: INotebookTracker, palette: ICommandPalette, editor_tracker: IEditorTracker){
        this.app = app;
        this.tracker = notebook_tracker;
        this.editor_tracker = editor_tracker;
        this.palette = palette;
        this.setup_button();

    }


    extract_editor(cell_or_editor: any): any {
        let editor_temp: any = cell_or_editor.editor;
        return editor_temp._editor;
    }

    trigger_emacs(editor: any, cell_type: string) {
        let cell_text = editor.getValue();
        console.log("sending " + cell_text + " to emacs");
        let http_options = {
            'host': '127.0.0.1',
            'port': 9292,
            'path': '/edit',
            'method': 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': cell_text.length,
                'x-file': 'jupyterhub:' + cell_type
            }
        };

        let request = http.request(http_options, (res: any) => {
            var body = '';
            res.on('data', (chunk: string) => {
                body += chunk;
            });
            res.on('end', () => {
                console.log("request finished");
                console.log(body);
                editor.setValue(body);
            });
        }).on('error', (e: any) => {
            console.log("Got error: " + e.message);
            console.log(e)
        });
        request.write(cell_text);
        request.end();
    }

    setup_button(){
        const command = "externaleditor:edit-in-emacs";
        this.app.commands.addCommand(command,{
            label: "Edit in emacs",
            execute: () => {
                console.log("Clicked button")
                let active_cell = this.tracker.activeCell;
                let editor = this.extract_editor(active_cell);
                this.trigger_emacs(editor, active_cell.model.type);
            }
        });
        this.palette.addItem( {command, category: "External editor"} );
    }
}


/**
 * Activate extension
 */
function activate(app: JupyterFrontEnd, tracker: INotebookTracker, palette: ICommandPalette, editor_tracker: IEditorTracker) {
    console.log('Attempting to load EditWithEmacs');
    const sp = new EditWithEmacs(app, tracker, palette, editor_tracker);
    console.log("EditWithEmacs Loaded ", sp);
};


/**
 * Initialization data for the jupyterlab_spellchecker extension.
 */
const extension: JupyterFrontEndPlugin<void> = {
    id: 'jupyterlab_emacs',
    autoStart: true,
    requires: [INotebookTracker, ICommandPalette, IEditorTracker],
    activate: activate
};

export default extension;
