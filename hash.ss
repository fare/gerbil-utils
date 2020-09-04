;; -*- Gerbil -*-
;;;; hash-table utilities

;; NB: Most functions previously here are now in std/misc/hash, as of gerbil v0.16-DEV-536-geac7706d
;; Some have been renamed. See gerbil's doc/reference/misc.md

(export
  count-hash<-vector
  invert-hash<-vector/fold
  sum<-hash-values)

(import
  :std/misc/hash)

(def (count-hash<-vector
      from start: (start 0) end: (end (vector-length from)) to: (to (make-hash-table)))
  (invert-hash<-vector/fold from start: start end: end to: to nil: 0 cons: 1+))

(def (sum<-hash-values hash)
  (hash-fold (lambda (_ v acc) (+ v acc)) 0 hash))