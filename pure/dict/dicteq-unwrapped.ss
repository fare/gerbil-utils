(export empty-dicteq
        dicteq-empty?
        dicteq-ref
        dicteq-get
        dicteq-put
        dicteq-update
        dicteq-remove
        dicteq-has-key?
        dicteq-keys
        dicteq-values
        dicteq-put/list
        list->dicteq
        dicteq->list
        dicteq=?)

(import :std/iter
        :std/misc/rbtree
        :std/srfi/1
        ./assq
        ./rationaldict-unwrapped)



;; Functional Dictionaries mapping keys to values according to eq-ness

;; An [Assqof K V] is a [Listof [Cons K V]]
;; where the keys should be compared by `eq?`,
;; and there are no duplicate keys

;; A [DictEqof K V] is an [Rationaldictof [Assqof K V]]

;; empty-dicteq : [DictEqof K V]
(def empty-dicteq empty-rationaldict)

;; dicteq-empty? : [DictEqof K V] -> Bool
(def dicteq-empty? rationaldict-empty?)

;; dicteq-ref : [DictEqof K V] K ?[-> V] -> V
(def (dicteq-ref d k (default (cut error "dicteq-ref: No value associated with key" d k)))
  (def a (rationaldict-get d (eq?-hash k) []))
  (assq-ref a k default))

;; dicteq-get : [DictEqof K V] K ?V -> V
(def (dicteq-get d k (default #f))
  (def a (rationaldict-get d (eq?-hash k) []))
  (assq-get a k default))

;; dicteq-put : [DictEqof K V] K V -> [DictEqof K V]
(def (dicteq-put d k v)
  (rationaldict-update
    d
    (eq?-hash k)
    (lambda (a) (assq-put a k v))
    []))

;; dicteq-update : [DictEqof K V] K [V -> V] V -> [DictEqof K V]
(def (dicteq-update d k f v0)
  (rationaldict-update
    d
    (eq?-hash k)
    (lambda (a) (assq-update a k f v0))
    []))

;; dicteq-remove : [DictEqof K V] K -> [DictEqof K V]
(def (dicteq-remove d k)
  (def kh (eq?-hash k))
  (def a (assq-remove (rationaldict-get d kh []) k))
  (if (null? a) (rationaldict-remove d kh) (rationaldict-put d kh a)))

;; dicteq-has-key? : [DictEqof K V] K -> Bool
(def (dicteq-has-key? d k)
  (assq-has-key? (rationaldict-get d (eq?-hash k) []) k))

;; dicteq-keys : [DictEqof K V] -> [Listof K]
(def (dicteq-keys d)
  (for/fold (l []) (a (in-rbtree-values d))
    (append-reverse (assq-keys a) l)))

;; dicteq-values : [DictEqof K V] -> [Listof V]
(def (dicteq-values d)
  (for/fold (l []) (a (in-rbtree-values d))
    (append-reverse (assq-values a) l)))

;; dicteq-put/list : [DictEqof K V] [Listof [Cons K V]] -> [DictEqof K V]
(def (dicteq-put/list d l)
  (cond ((null? l) d)
        (else (dicteq-put/list (dicteq-put d (caar l) (cdar l)) (cdr l)))))

;; list->dicteq : [Listof [Cons K V]] -> [DictEqof K V]
(def (list->dicteq l) (dicteq-put/list empty-dicteq l))

;; dicteq->list : [DictEqof K V] -> [Listof [Cons K V]]
(def (dicteq->list d)
  (for/fold (l []) (vs (in-rbtree-values d))
    (append-reverse vs l)))

;; dicteq=? : [DictEqof Any Any] [DictEqof Any Any] -> Bool
(def (dicteq=? a b (v=? equal?))
  (rationaldict=? a b (cut assq=? <> <> v=?)))
