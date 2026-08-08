(in-package :fab)

(defun print-version (&optional (stream *standard-output*))
  (format stream "fab & ~A~%" (asdf:component-version (asdf:find-system :fab))))

(defun print-usage (&optional (stream *standard-output*))
  (write-string
   "Usage: fab [options] <DESIGN>

Generate Verilog (and constraint files) from a (fab) Lisp design file.
With --board, also compile to FPGA bitstream.

Arguments:
    DESIGN                  Path to the .lisp design file

Options:
    -o, --output-dir DIR    Output directory for generated files (default: build)
    -b, --board-dir DIR     Board search directory (may be repeated)
    --board NAME            Compile with this board (triggers yosys/nextpnr/gowin_pack)

Examples:
    fab usb-keyboard.lisp                                  # generate .v only
    fab --board tangnano9k usb-keyboard.lisp               # generate + compile
    fab -o rtl/ --board tangnano9k usb-keyboard.lisp       # custom output dir

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
    (if (and (plusp (length name))
             (not (char= (char name (1- (length name))) #\/)))
        (concatenate 'string name "/")
        name)))

(defun verilog-ident (name)
  "Convert a symbol/string name to uppercase Verilog-safe identifier."
  (let ((s (if (symbolp name) (symbol-name name) (string name))))
    (with-output-to-string (out)
      (loop for ch across s
            do (if (or (alphanumericp ch) (char= ch #\_))
                   (write-char (char-upcase ch) out)
                   (write-char #\_ out))))))

(defun compile-board (board-name output-dir)
  "Run yosys → nextpnr → gowin_pack for BOARD-NAME using generated .v and .cst files."
  (let* ((board-key (if (symbolp board-name) (symbol-name board-name)
                        (string-upcase (string board-name))))
         (board (gethash board-key *boards*))
         (device (ir-board-device board))
         (family (ir-board-family board)))
    ;; Find the module that has a board-target for this board
    (let ((target (find-if (lambda (bt) (string= (if (symbolp (second bt))
                                                      (symbol-name (second bt))
                                                      (string (second bt)))
                                                  board-key))
                           *board-targets*)))
      (unless target
        (error "No board-target found for board ~a" board-name))
      (let* ((mod-name (first target))
             (mod-name-str (if (symbolp mod-name) (symbol-name mod-name) (string mod-name)))
             (top-v (verilog-ident mod-name-str))
             (board-v (string-upcase (if (symbolp board-name)
                                         (symbol-name board-name)
                                         board-name)))
             (cst-file (format nil "~a/~a_~a.cst" output-dir top-v board-v))
             (json-file (format nil "~a/~a.json" output-dir top-v))
             (pnr-file (format nil "~a/~a_pnr.json" output-dir top-v))
             (fs-file (format nil "~a/~a.fs" output-dir top-v)))
        ;; yosys: synthesis
        (format t "~%--- Synthesizing with yosys ---~%")
        (let ((cmd (format nil "yosys -p \"read_verilog ~a/*.v; synth_gowin -json ~a -top ~a\""
                           output-dir json-file top-v)))
          (format t "$ ~a~%" cmd)
          (uiop:run-program cmd :output t :error-output :interactive))
        ;; nextpnr: place and route (himbaechel)
        (format t "~%--- Place & route with nextpnr-himbaechel-gowin ---~%")
        (let ((cmd (format nil "yowasp-nextpnr-himbaechel-gowin --device ~a -o family=~a -o cst=~a --json ~a --write ~a"
                           device family cst-file json-file pnr-file)))
          (format t "$ ~a~%" cmd)
          (uiop:run-program cmd :output t :error-output :interactive))
        ;; gowin_pack: bitstream
        (format t "~%--- Packing with gowin_pack ---~%")
        (let ((cmd (format nil "gowin_pack -d ~a -o ~a ~a" device fs-file pnr-file)))
          (format t "$ ~a~%" cmd)
          (uiop:run-program cmd :output t :error-output :interactive))
        (format t "~%Bitstream: ~a~%" fs-file)
        fs-file))))

(defun generate-handler (cmd)
  (handler-case
      (progn
        (let* ((args (clingon:command-arguments cmd))
               (input (ensure-input-file (first args)))
               (output-dir (normalize-directory (or (clingon:getopt cmd :output-dir) "build")))
               (board-dirs (clingon:getopt cmd :board-dir))
               (board-name (clingon:getopt cmd :board)))
          ;; Set output directory
          (setf *output-dir* output-dir)
          ;; Reset board targets for this run
          (setf *board-targets* nil)
          ;; Set board search directories
          (setf *board-dirs*
                (mapcar (lambda (d) (merge-pathnames (format nil "~a" d) #p""))
                        board-dirs))
          ;; Load the design file
          (format t "Generating from ~a -> ~a~%" input output-dir)
          (load input)
          ;; Compile if --board specified
          (when board-name
            (compile-board board-name output-dir))
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
                        :key :board-dir)
   (clingon:make-option :string
                        :long-name "board"
                        :description "Compile with this board (triggers yosys/nextpnr/gowin_pack)"
                        :key :board)))

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
