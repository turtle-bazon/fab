(in-package :fab)

(defun print-version (&optional (stream *standard-output*))
  (format stream "fab & ~A~%" (asdf:component-version (asdf:find-system :fab))))

(defun print-usage (&optional (stream *standard-output*))
  (write-string
   "Usage: fab [options] <DESIGN>

Generate Verilog (and constraint files) from a (fab) Lisp design file.

Arguments:
    DESIGN                  Path to the .lisp design file

Options:
    -o, --output-dir DIR    Output directory for generated files (default: build)
    -b, --board-dir DIR     Board search directory (may be repeated)
    -v, --version           Print version and exit
    -h, --help              Print this help message and exit

Examples:
    fab usb-keyboard.lisp
    fab -o rtl/ -b /usr/share/fab/boards usb-keyboard.lisp

"
   stream)
  (print-version stream))

(defun ensure-input-file (input)
  (unless input
    (error "No design file specified."))
  (unless (probe-file input)
    (error "Cannot open design file: ~a" input))
  input)

(defun normalize-directory (dir)
  "Ensure DIR is a proper directory pathname string."
  (let ((name (namestring (merge-pathnames dir))))
    ;; Ensure trailing slash so ensure-directories-exist works
    (if (and (plusp (length name))
             (not (char= (char name (1- (length name))) #\/)))
        (concatenate 'string name "/")
        name)))

(defun generate-handler (cmd)
  (handler-case
      (progn
        (let* ((args (clingon:command-arguments cmd))
               (input (ensure-input-file (first args)))
               (output-dir (normalize-directory (or (clingon:getopt cmd :output-dir) "build")))
               (board-dirs (clingon:getopt cmd :board-dir)))
          ;; Set output directory
          (setf *output-dir* output-dir)
          ;; Set board search directories
          (setf *board-dirs*
                (mapcar (lambda (d) (merge-pathnames (format nil "~a" d) #p""))
                        board-dirs))
          ;; Load the design file
          (format t "Generating from ~a -> ~a~%" input output-dir)
          (load input)
          (format t "Done.~%")))
    (file-error ()
      (format *error-output* "Cannot write output file.~%")
      (clingon:exit 255))
    (error (e)
      (format *error-output* "~a~%" e)
      (clingon:exit 255))))

(defun make-generate-options ()
  (list
   (clingon:make-option :string
                        :short-name #\o
                        :long-name "output-dir"
                        :description "Output directory for generated files (default: build)"
                        :key :output-dir)
   (clingon:make-option :list
                        :short-name #\b
                        :long-name "board-dir"
                        :description "Board search directory (may be repeated)"
                        :key :board-dir)))

(defun make-generate-command ()
  (clingon:make-command
   :name "fab"
   :description "Generate Verilog from (fab) Lisp design files"
   :version (asdf:component-version (asdf:find-system :fab))
   :options (make-generate-options)
   :handler #'generate-handler))

(defun make-root-command ()
  (clingon:make-command
   :name "fab"
   :description "(fab): Common Lisp hardware description toolchain"
   :version (asdf:component-version (asdf:find-system :fab))
   :handler (lambda (cmd)
              (declare (ignore cmd))
              (print-usage)
              (clingon:exit 0))))

(defun main ()
  (if (null (uiop:command-line-arguments))
      (progn
        (print-usage)
        (clingon:exit 0))
      (clingon:run (make-generate-command))))
