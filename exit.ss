;; -*- Gerbil -*-
;;;; Support for building a single multicall binary that has all the fricfrac functionality.

(export #t)

(import
  :gerbil/gambit/ports
  :std/format :std/misc/list :std/misc/repr :std/sugar
  ./base)

(defrule (eval-print-exit body ...) (call-print-exit (λ () body ...)))

;; Return a magic value that will be not be printed but will return an error code.
;; (void) is silent success, because it's what successful side-effecting functions return.
;; (values) is failure, because it's the other naturally silent return thing, and it's abnormal enough.
(def (silent-exit (bool #t))
  (if bool (void) (values)))

;; Execute a function, print the result (if application), and exit with an according value.
;;
;; (void) prints nothing and counts as false. #f is printed and counts as false.
;; (values) prints nothing and counts as true. All other values are printed and count as true.
;; If you want to print #f and return true, then print it then return (values).
;;
;; True is returned as exit code 0, false as exit code 1.
;; Any uncaught exception will be printed then trigger an exit with code 2.
(def (call-print-exit fun)
  (with-catch
   (λ (x) (ignore-errors (eprintf "~s~%" x)) (exit 2))
   (call/values
     fun
     (λ vs
       (unless (equal? vs [(void)])
         (for-each prn vs))
       (force-output)
       (exit (if (or (null? vs) (and (length=n? vs 1) (not (car vs)))) 1 0))))))