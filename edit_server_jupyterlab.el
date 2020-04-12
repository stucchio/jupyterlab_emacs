;; Redefine edit-server-send-response to allow CORS
(defun edit-server-send-response (proc &optional body progress)
  "Send an HTTP 200 OK response back to process PROC.
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

;; Redefine edit-server-find-or-create-edit-buffer to set the variable edit-server-file
;; buffer-locally before running hooks.
(defun edit-server-find-or-create-edit-buffer (proc &optional existing)
  "Find and existing or create an new edit buffer, place content in it
and save the network process for the final call back"
  ;; FIXME: `existing' is useless: see issue #104.
  (let* ((existing-buffer (and (stringp existing) (get-buffer existing)))
	 (buffer (or existing-buffer (generate-new-buffer
				      (or edit-server-url
					  edit-server-edit-buffer-name)))))

    (edit-server-log proc
		     "using buffer %s for edit (existing-buffer is %s)"
		     buffer existing-buffer)

    ;; set multi-byte for proper UTF-8 handling (djb)
    (when (fboundp 'set-buffer-multibyte)
      (with-current-buffer buffer
	(set-buffer-multibyte t)))

    ;; I seem to be working around a bug here :-/
    ;;
    ;; For some reason the copy-to-buffer doesn't blat the existing contents.
    ;; This screws up formatting as the contents were decoded before being
    ;; sent back to the browser. As a kludge I save the returned contents
    ;; in the kill-ring.
    (when existing-buffer
      (kill-ring-save (point-min) (point-max)))

    (edit-server-log proc "copying new data into buffer")
    (copy-to-buffer buffer (point-min) (point-max))

    (with-current-buffer buffer
      (setq edit-server-url (with-current-buffer (process-buffer proc) edit-server-url))
      (edit-server-choose-major-mode)
      ;; Allow `edit-server-start-hook' to override the major mode.
      ;; (re)setting the minor mode seems to clear the buffer-local
      ;; variables that we depend upon for the response, so call the
      ;; hooks early on
      (setq-local edit-server-file *tmp-edit-server-file
                  edit-server-url *tmp-edit-server-url)
      (setq *tmp-edit-server-file nil
            *tmp-edit-server-url nil)
      (run-hooks 'edit-server-start-hook)
      (set-buffer-modified-p 'nil)
      (add-hook 'kill-buffer-hook 'edit-server-abort* nil t)
      (buffer-enable-undo)
      (setq edit-server-proc proc
	    edit-server-frame (edit-server-show-edit-buffer buffer))
      (edit-server-edit-mode)
      buffer)))

;; In order to pass variables to buffer, need to set them globally here
(defun edit-server-filter (proc string)
  "Process data received from the client."
  ;; there is no guarantee that data belonging to the same client
  ;; request will arrive all in one go; therefore, we must accumulate
  ;; data in the buffer and process it in different phases, which
  ;; requires us to keep track of the processing state.
  (with-current-buffer (process-buffer proc)
    (insert string)
    (setq edit-server-received
	  (+ edit-server-received (string-bytes string)))
    (when (eq edit-server-phase 'wait)
      ;; look for a complete HTTP request string
      (save-excursion
	(goto-char (point-min))
	(when (re-search-forward
	       "^\\([A-Z]+\\)\\s-+\\(\\S-+\\)\\s-+\\(HTTP/[0-9\.]+\\)\r?\n"
	       nil t)
	  (setq edit-server-request (match-string 1)
		edit-server-request-url (match-string 2)
		edit-server-content-length nil
		edit-server-phase 'head)
          (setq *tmp-edit-server-request edit-server-request
		*tmp-edit-server-request-url edit-server-request-url)
	  (edit-server-log
	   proc "Got HTTP `%s' request of url `%s', processing in buffer `%s'..."
	   edit-server-request edit-server-request-url (current-buffer)))))

    (when (eq edit-server-phase 'head)
      ;; look for "Content-length" header
      (save-excursion
	(goto-char (point-min))
	(when (re-search-forward "^Content-Length:\\s-+\\([0-9]+\\)" nil t)
	  (setq edit-server-content-length
		(string-to-number (match-string 1)))))
      ;; look for "x-url" header
      (save-excursion
	(goto-char (point-min))
	(when (re-search-forward "^x-url: .*/\\{2,3\\}\\([^\r\n]+\\)" nil t)
	  (setq edit-server-url (match-string 1)
                *tmp-edit-server-url (match-string 1))))
      ;; look for "x-file" header
      (save-excursion
	(goto-char (point-min))
	(when (re-search-forward "^x-file: \\([^\r\n]+\\)" nil t)
	  (edit-server-log proc "Found x-file: %s" (match-string 1))
	  (setq edit-server-file (match-string 1)
                *tmp-edit-server-file (match-string 1))))
      ;; look for head/body separator
      (save-excursion
	(goto-char (point-min))
	(when (re-search-forward "\\(\r?\n\\)\\{2\\}" nil t)
	  ;; HTTP headers are pure ASCII (1 char = 1 byte), so we can subtract
	  ;; the buffer position from the count of received bytes
	  (setq edit-server-received
		(- edit-server-received (- (match-end 0) (point-min))))
	  ;; discard headers - keep only HTTP content in buffer
	  (delete-region (point-min) (match-end 0))
	  (edit-server-log proc
			   "Processed headers, length: %s, url: %s, file: %s"
			   edit-server-content-length edit-server-url edit-server-file)
	  (setq edit-server-phase 'body))))

    (when (eq edit-server-phase 'body)
      (if (and edit-server-content-length
	       (> edit-server-content-length edit-server-received))
	  (edit-server-log proc
			   "Received %d bytes of %d ..."
			   edit-server-received edit-server-content-length)
	;; all content transferred - process request now
	(cond
	 ((string-match "foreground" edit-server-request-url)
	  (edit-server-foreground-request (current-buffer))
	  (edit-server-send-response proc "edit-server received foreground request.\n")
	  (edit-server-kill-client proc))
	 ((string= edit-server-request "POST")
	  ;; create editing buffer, and move content to it
          (edit-server-find-or-create-edit-buffer proc edit-server-file)
	  )
	 (t
	  ;; send 200 OK response to any other request
	  (edit-server-send-response proc "edit-server is running.\n")
	  (edit-server-kill-client proc)))
	;; wait for another connection to arrive
	(setq edit-server-received 0)
	(setq edit-server-phase 'wait)))))

(setq edit-server-start-hook nil)
(add-hook 'edit-server-start-hook
           (lambda ()
             (progn
               (cond ((string= edit-server-file "jupyterhub:code") (python-mode))
                     ((string= edit-server-file "jupyterhub:markdown") (markdown-mode))
                     )
               )))
