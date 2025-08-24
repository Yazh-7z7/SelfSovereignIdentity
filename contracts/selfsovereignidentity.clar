
;; Self-Sovereign Identity Contract
;; A user-controlled identity system with selective disclosure and privacy protection

;; Error constants
(define-constant err-not-authorized (err u100))
(define-constant err-identity-not-found (err u101))
(define-constant err-invalid-data (err u102))
(define-constant err-identity-already-exists (err u103))

;; Data structures
(define-map identities 
  principal 
  {
    did: (string-ascii 128),
    public-key: (buff 33),
    metadata-hash: (buff 32),
    is-active: bool,
    created-at: uint,
    updated-at: uint
  })

(define-map selective-disclosures
  {identity: principal, disclosure-id: uint}
  {
    data-hash: (buff 32),
    requester: principal,
    is-approved: bool,
    created-at: uint
  })

(define-data-var next-disclosure-id uint u1)

;; Function 1: Register Identity
;; Allows users to register their self-sovereign identity with privacy-preserving metadata
(define-public (register-identity (did (string-ascii 128)) (public-key (buff 33)) (metadata-hash (buff 32)))
  (begin
    ;; Ensure the identity doesn't already exist
    (asserts! (is-none (map-get? identities tx-sender)) err-identity-already-exists)
    
    ;; Validate input data
    (asserts! (> (len did) u0) err-invalid-data)
    (asserts! (is-eq (len public-key) u33) err-invalid-data)
    (asserts! (is-eq (len metadata-hash) u32) err-invalid-data)
    
    ;; Store the identity with privacy-preserving approach (only hash of metadata)
    (map-set identities tx-sender {
      did: did,
      public-key: public-key,
      metadata-hash: metadata-hash,
      is-active: true,
      created-at: stacks-block-height,
      updated-at: stacks-block-height
    })
    
    ;; Emit event for identity registration
    (print {
      event: "identity-registered",
      identity: tx-sender,
      did: did,
      block-height: stacks-block-height
    })
    
    (ok true)))

;; Function 2: Create Selective Disclosure
;; Allows users to create selective data disclosures for specific requesters with privacy control
(define-public (create-selective-disclosure (data-hash (buff 32)) (requester principal))
  (let ((current-disclosure-id (var-get next-disclosure-id)))
    (begin
      ;; Ensure the identity exists and is active
      (asserts! (is-some (map-get? identities tx-sender)) err-identity-not-found)
      (asserts! (get is-active (unwrap! (map-get? identities tx-sender) err-identity-not-found)) err-not-authorized)
      
      ;; Validate input data
      (asserts! (is-eq (len data-hash) u32) err-invalid-data)
      (asserts! (not (is-eq requester tx-sender)) err-invalid-data)
      
      ;; Create the selective disclosure record
      (map-set selective-disclosures 
        {identity: tx-sender, disclosure-id: current-disclosure-id}
        {
          data-hash: data-hash,
          requester: requester,
          is-approved: false,
          created-at: stacks-block-height
        })
      
      ;; Increment disclosure ID for next use
      (var-set next-disclosure-id (+ current-disclosure-id u1))
      
      ;; Emit event for selective disclosure creation
      (print {
        event: "selective-disclosure-created",
        identity: tx-sender,
        disclosure-id: current-disclosure-id,
        requester: requester,
        block-height: stacks-block-height
      })
      
      (ok current-disclosure-id))))

;; Read-only functions for querying identity data

(define-read-only (get-identity (identity principal))
  (map-get? identities identity))

(define-read-only (get-selective-disclosure (identity principal) (disclosure-id uint))
  (map-get? selective-disclosures {identity: identity, disclosure-id: disclosure-id}))

(define-read-only (get-next-disclosure-id)
  (var-get next-disclosure-id)) 
  
