#|
 This file is a part of cl-mpg123
 (c) 2016 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.fraf.mpg123)

(defmacro with-foreign-values (bindings &body body)
  `(with-foreign-objects ,bindings
     ,@body
     (values ,@(loop for (name type) in bindings
                     collect `(unless (null-pointer-p ,name) (mem-ref ,name ,type))))))

(defmacro with-value-args (bindings call &body body)
  `(multiple-value-bind ,(mapcar #'first bindings)
       (with-foreign-values ,bindings ,call)
     ,@body))

(defmacro with-error ((err datum &rest datum-args) &body form)
  `(let ((,err (progn ,@form)))
     (unless (eql ,err :ok)
       (let ((,err (if (eql ,err :err)
                       "Unknown error."
                       (cl-mpg123-cffi:plain-strerror ,err))))
         (error ,datum ,@datum-args)))))

(defmacro with-generic-error (&body form)
  (let ((err (gensym "ERR")))
    `(with-error (,err "~s failed: ~a" ',form ,err)
       ,@form)))

(defmacro with-negative-error (&body form)
  (let ((res (gensym "RES")))
    `(let ((,res (progn ,@form)))
       (when (< ,res 0) (error "Failed to execute ~s." ',form))
       ,res)))

(defmacro with-zero-error (&body form)
  (let ((res (gensym "RES")))
    `(let ((,res (progn ,@form)))
       (when (= ,res 0) (error "Failed to execute ~s." ',form))
       ,res)))

(defun string-nil (string)
  (when (and string (string/= "" string))
    string))

(defun direct-str (pointer length)
  (string-nil (or (ignore-errors (foreign-string-to-lisp pointer :max-chars length :encoding :utf-8))
                  (ignore-errors (foreign-string-to-lisp pointer :max-chars length :encoding :iso-8859-1)))))

(defun mstring (mstring)
  (string-nil
   (etypecase mstring
     (foreign-pointer
      (cffi:foreign-string-to-lisp
       (cl-mpg123-cffi:mstring-p mstring)
       :max-chars (cl-mpg123-cffi:mstring-size mstring)
       :encoding :UTF-8))
     (list
      (cffi:foreign-string-to-lisp
       (getf mstring 'cl-mpg123-cffi::p)
       :max-chars (getf mstring 'cl-mpg123-cffi::size)
       :encoding :UTF-8)))))

(defun split (string char)
  (let ((parts ()))
    (loop with buf = (make-string-output-stream)
          for c across string
          do (if (char= c char)
                 (let ((part (get-output-stream-string buf)))
                   (when (string-nil part) (push part parts)))
                 (write-char c buf))
          finally (push (get-output-stream-string buf) parts))
    (nreverse parts)))
