(require 'jsonrpc)
(require 'cl-lib)

(defvar my-jsonrpc-conn nil)

(defun my-jsonrpc-start ()
  (if (not (and my-jsonrpc-conn (process-live-p (jsonrpc--process my-jsonrpc-conn))))
      (setq my-jsonrpc-conn
            (jsonrpc-process-connection
             :name "My JSON-RPC"
             :process (make-network-process
                       :name "jsonrpc-demo"
                       :buffer "*jsonrpc-io*"
                       :host "127.0.0.1"
                       :service 8193
                       :nowait nil)))))

;; (defun my-jsonrpc-greet (name)
;;   (message (jsonrpc-request my-jsonrpc-conn 'editfunction ["sayhi" "print('Yahallo!')"])))


(defun command-list (path)
  (jsonrpc-request my-jsonrpc-conn 'list (vector path)))



(defun command-addfunction (name)
  (message (pp-to-string (jsonrpc-request my-jsonrpc-conn 'addfunction (vector name)))))

(defun command-editfunction (name args body)
  (message (pp-to-string (jsonrpc-request my-jsonrpc-conn 'editfunction (vector name args body)))))


(defun command-getfunction (name)
  (jsonrpc-request my-jsonrpc-conn 'getfunction (vector name)))


(my-jsonrpc-start)

(define-derived-mode my-table-mode tabulated-list-mode "MyTable"
  "Mode for displaying tabulated data."
  (define-key my-table-mode-map (kbd "RET") #'my-show-list-on-click)
  (define-key my-table-mode-map [mouse-1] #'my-show-list-on-click)
  )

(defun my-show-list ()
  )

(defun voex-show-functions ()
  (interactive)
  (let ((buf (get-buffer-create "*Voex Functions*")))
    (with-current-buffer buf
      (my-table-mode)
      (setq tabulated-list-format [("Name" 20 t)])
      (setq tabulated-list-entries
	    (let ((list (command-list "")))
	      (cl-loop for (name info) on list by 'cddr
		       collect (list (substring (symbol-name name) 1) (vector (substring (symbol-name name) 1))))))

      (tabulated-list-init-header)
      (tabulated-list-print))
    (display-buffer buf)))

(defun voex-edit-function (name)
  (let ((function (command-getfunction name))
	(buf (get-buffer-create (format "Voex function: %s" name))))
    (with-current-buffer buf
      (erase-buffer)
      (insert (plist-get function :body))
      (lua-mode)  ;; enable lua-mode
      (set-buffer-modified-p nil)  ;; mark buffer as unmodified
      (goto-char (point-min)))
    (switch-to-buffer buf)))

(defun my-show-list-on-click ()
  "Action to take when user presses RET or clicks a row."
  (interactive)
  (let* ((id (tabulated-list-get-id)))
    (if id
	(voex-edit-function id)
      (message "No entry at point."))))
