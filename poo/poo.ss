;;-*- Gerbil -*-
;; Trivial implementation of Prototype Object Orientation in Gerbil Scheme.
;;
;; See ../doc/poo.md for documentation
;; TODO: see Future Features and the Internals TODO sections in document above.

(export #t);; XXX for debugging macros as used in other modules; remove afterwards
(export
  .o .o/derived .def .def/derived
  poo? .mix .ref .instantiate .get .call .def! .set! .put! .putslot! .key? .has? .all-slots
  .all-slots-sorted .alist .sorted-alist
  .@ .+
  poo poo-prototypes poo-instance ;; shouldn't these remain internals?
  with-slots)

(import
  (for-syntax :clan/utils/base)
  :clan/utils/base :clan/utils/hash
  :std/lazy :std/misc/list :std/sort :std/srfi/1 :std/srfi/13 :std/sugar)

(defstruct poo (prototypes instance) constructor: :init!)
(defmethod {:init! poo}
   (lambda (self prototypes (instance #f))
     (struct-instance-init! self prototypes instance)))

(def (.instantiate poo.)
  (match poo.
    ((poo _ #f) (set! (poo-instance poo.) (hash))) ;; TODO: call .init method?
    ((poo _ _) (void)) ;; already instantiated
    (else (error "No poo" poo.))))

(def (.ref poo. slot)
  (.instantiate poo.)
  (match poo.
    ((poo prototypes instance)
     (hash-ensure-ref instance slot (cut compute-slot poo. prototypes slot)))))

(def (compute-slot poo. prototypes slot)
  (match prototypes
    ([] (error "No such slot" poo. slot))
    ([prototype . super-prototypes]
     (if-let (fun (hash-get prototype slot))
        (fun poo. super-prototypes)
        (compute-slot poo. super-prototypes slot)))))

(def (append-prototypes x (prototypes []))
  (match x ;; TODO: use lazy merging of patricia trees to maximize the sharing of structure? hash-consing?
    ([] prototypes)
    ((cons x y) (append-prototypes x (append-prototypes y prototypes)))
    ((poo ps _) (append ps prototypes))
    (_ (error "invalid poo spec" x))))

(def (.mix . poos)
  (poo (append-prototypes poos) #f))

(def (.+ base . mixins)
  (.mix mixins base))

(def (.key? poo. slot)
  (match poo.
    ((poo prototypes instance)
     (or (and instance (hash-key? instance slot)) ;; fast check for already-computed slot, also includes slots from .put! or .set!
         (any (cut hash-key? <> slot) prototypes)))
    (else (error ".key?: not poo" poo. slot))))

(defrules .has? ()
  ((_ x) #t)
  ((_ x slot) (.key? x 'slot))
  ((_ x slot1 slot2 slot3 ...) (and (.has? x slot1) (.has? x slot2 slot3 ...))))

(def .all-slots
  (nest
   (λ-ematch) ((poo prototypes instance))
   (with-list-builder (c))
   (let (h (if instance (hash-copy instance) (hash)))
     (when instance (for-each! (hash-keys instance) c)))
   (for-each! prototypes) (λ (p))
   ((cut hash-for-each <> p)) (λ (k _))
   (unless (hash-key? h k)
     (hash-put! h k #t)
     (c k))))

(def (.all-slots-sorted poo)
  (sort (.all-slots poo) symbol<?))

(def (.alist poo)
  (map (λ (slot) (cons slot (.ref poo slot))) (.all-slots poo)))

(def (.sorted-alist poo)
  (map (λ (slot) (cons slot (.ref poo slot))) (.all-slots-sorted poo)))

(defsyntax .o
  (lambda (stx)
    (syntax-case stx ()
      ((_ args ...)
       (with-syntax ((ctx stx)) #'(.o/derived ctx args ...))))))

;; the ctx argument exists for macro-scope purposes
(defrules .o/derived ()
  ((_ ctx (:: self) slot-spec ...)
   (poo/slots ctx self [] () slot-spec ...))
  ((_ ctx (:: self super slots ...) slot-spec ...)
   (poo/slots ctx self super (slots ...) slot-spec ...))
  ((_ ctx () slot-spec ...)
   (poo/slots ctx self [] () slot-spec ...))
  ((_ ctx slot-spec ...)
   (poo/slots ctx self [] () slot-spec ...)))

(begin-syntax
  ;; TODO: is there a better option than (stx-car stx) to introduce correct identifier scope?
  ;; the stx argument is the original syntax #'(.o args ...) or #'(@method args ...)
  (def (unkeywordify-syntax stx k)
    (!> k
        syntax->datum
        keyword->string
        string->symbol
        (cut datum->syntax (stx-car stx) <>)))

  (def (normalize-named-slot-specs stx name specs)
    (syntax-case specs (=> =>.+)
      ((=> value-spec . more)
       (with-syntax ((name name))
         (cons #'(name => value-spec) (normalize-slot-specs stx #'more))))
      ((=>.+ value-spec . more)
       (with-syntax ((name name))
         (cons #'(name =>.+ value-spec) (normalize-slot-specs stx #'more))))
      ((value-spec . more)
       (with-syntax ((name name))
         (cons #'(name value-spec) (normalize-slot-specs stx #'more))))
      (() (error "missing value after slot name" name (syntax->datum name) stx (syntax->datum stx)))))

  (def (normalize-slot-specs stx specs)
    (syntax-case specs ()
      (() '())
      ((arg . more)
       (let ((e (syntax-e #'arg)))
         (cond
          ((pair? e)
           (cons #'arg (normalize-slot-specs stx #'more)))
          ((symbol? e)
           (normalize-named-slot-specs stx #'arg #'more))
          ((keyword? e)
           (normalize-named-slot-specs stx (unkeywordify-syntax stx #'arg) #'more))
          (else
           (error "bad slot spec" #'arg))))))))

;; the ctx argument exists for macro-scope purposes
(defsyntax (poo/slots stx)
  (syntax-case stx ()
    ((_ ctx self super (slots ...) . slot-specs)
     (with-syntax ((((slot spec ...) ...) (normalize-slot-specs #'ctx #'slot-specs)))
       #'(poo/init self super (slots ... slot ...) (slot spec ...) ...)))))

(defrules poo/init ()
  ((_ self super slots (slot slotspec ...) ...)
   (poo (cons (hash (slot (poo/slot-init-form self slots slot slotspec ...)) ...)
              (append-prototypes super)) #f)))

(defrules poo/slot-init-form (=> =>.+)
  ((_ self slots slot form)
   (λ (self super-prototypes)
     (with-slots (self . slots) form)))
  ((_ self slots slot => form args ...)
   (λ (self super-prototypes)
     (let ((inherited-value (compute-slot self super-prototypes 'slot)))
       (with-slots (self . slots) (form inherited-value args ...)))))
  ((_ self slots slot =>.+ args ...)
   (poo/slot-init-form self slots slot => .+ args ...))
  ((_ self slots slot (next-method) form)
   (λ (self super-prototypes)
     (let ((inherited-value (lazy (compute-slot self super-prototypes 'slot))))
       (let-syntax ((next-method (syntax-rules () ((_) (force inherited-value)))))
         (with-slots (self . slots) form)))))
  ((_ self slots slot)
   (λ (self super-prototypes) slot)))

(defrules with-slots ()
  ((_ (self) body ...) (begin body ...))
  ((_ (self slot slots ...) body ...)
   (let-syntax ((slot (syntax-rules () (_ (.@ self slot)))))
     (with-slots (self slots ...) body ...))))

(defsyntax .def
  (lambda (stx)
    (syntax-case stx ()
      ((_ args ...)
       (with-syntax ((ctx stx)) #'(.def/derived ctx args ...))))))

;; the ctx argument exists for macro-scope purposes
(defrules .def/derived ()
  ((_ ctx (name options ...) slot-defs ...)
   (def name (.o/derived ctx (:: options ...) slot-defs ...)))
  ((_ ctx name slot-defs ...)
   (def name (.o/derived ctx () slot-defs ...))))

(defrules .get ()
  ((_ poo) poo)
  ((_ poo slot slots ...) (.get (.ref poo 'slot) slots ...)))

(defalias .@ .get)

(defrules .call ()
  ((_ poo slot args ...) ((.get poo slot) args ...)))

(def (.putslot! poo. slot definition)
  (ematch poo. ((poo [proto . protos] _) (hash-put! proto slot definition))))

(defrules .def! () ;; TODO: check prototype mutability status first
  ((_ poo slot (slots ...) slotspec ...)
   (.putslot! poo 'slot (poo/slot-init-form poo (slot slots ...) slot slotspec ...))))

(def (.put! poo. slot value) ;; TODO: check instance mutability status first
  (.instantiate poo.)
  (hash-put! (poo-instance poo.) slot value))

(defrules .set! () ((_ poo. slot value) (.put! poo. 'slot value)))
