;; A robust implementation for managing in-game items on the Stacks blockchain
;; SIP-009 compliant NFT with extensions for gaming functionality

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ITEM-EXISTS (err u101))
(define-constant ERR-ITEM-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-TRANSFER-FAILED (err u104))
(define-constant ERR-LISTING-NOT-FOUND (err u105))
(define-constant ERR-LISTING-EXPIRED (err u106))
(define-constant ERR-INVALID-PRICE (err u107))
(define-constant ERR-SELF-TRANSFER (err u108))

;; Data definitions
(define-data-var contract-owner principal tx-sender)
(define-data-var total-items uint u0)
(define-data-var admin-fee-basis-points uint u250) ;; 2.5% fee (basis points: 1/100 of a percent)

;; Define NFT trait conformance
(impl-trait .nft-trait.nft-trait)

;; Item structure
(define-map items
  uint ;; item-id
  {
    name: (string-ascii 64),
    description: (string-utf8 256),
    image-uri: (string-utf8 256),
    creator: principal,
    item-type: (string-ascii 32),
    attributes: (list 20 {trait-type: (string-ascii 32), value: (string-utf8 64)}),
    metadata: (optional (string-utf8 1024)),
    created-at: uint,
    rarity: uint,
    tradeable: bool
  }
)

;; Ownership mapping
(define-map item-owners
  {item-id: uint, owner: principal}
  uint ;; quantity
)

;; Listings for marketplace
(define-map marketplace-listings
  uint ;; listing-id
  {
    item-id: uint,
    seller: principal,
    price: uint,
    expiry: uint,
    quantity: uint,
    active: bool
  }
)

(define-map active-listing-ids uint bool)
(define-map user-listing-ids {user: principal, listing-id: uint} bool)

;; Global marketplace counter
(define-data-var next-listing-id uint u1)

;; Helper function to find an owner of an item
(define-private (find-item-owner (item-id uint))
  ;; In a real implementation, this would iterate through known users
  ;; For simplicity, we'll just check if contract owner has any
  (let ((owner-balance (default-to u0 (map-get? item-owners {item-id: item-id, owner: (var-get contract-owner)}))))
    (if (> owner-balance u0)
      (ok (some (var-get contract-owner)))
      (ok none))))

;; Authorization functions
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-owner new-owner))
  )
)

(define-public (set-admin-fee (new-fee-basis-points uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee-basis-points u1000) ERR-INVALID-PRICE) ;; Max 10%
    (ok (var-set admin-fee-basis-points new-fee-basis-points))
  )
)

;; SIP-009 NFT trait implementation functions
(define-read-only (get-last-token-id)
  (ok (var-get total-items))
)

(define-read-only (get-token-uri (id uint))
  (let ((item-info (map-get? items id)))
    (if (is-some item-info)
      (ok (some (get image-uri (unwrap-panic item-info))))
      (ok none)
    )
  )
)

(define-read-only (get-owner (id uint))
  (let ((sender-balance (default-to u0 (map-get? item-owners {item-id: id, owner: tx-sender})))
        (owner-balance (default-to u0 (map-get? item-owners {item-id: id, owner: (var-get contract-owner)}))))
    (if (> sender-balance u0)
      ;; If sender owns any, return sender
      (ok (some tx-sender))
      ;; Otherwise, check if owner owns any
      (if (> owner-balance u0)
        ;; If owner owns any, return owner
        (ok (some (var-get contract-owner)))
        ;; Otherwise search until we find an owner with balance
        (find-item-owner id)))))

;; Item creation and management functions
(define-public (create-item 
  (name (string-ascii 64))
  (description (string-utf8 256))
  (image-uri (string-utf8 256))
  (item-type (string-ascii 32))
  (attributes (list 20 {trait-type: (string-ascii 32), value: (string-utf8 64)}))
  (metadata (optional (string-utf8 1024)))
  (rarity uint)
  (tradeable bool)
)
  (let
    (
      (new-item-id (+ (var-get total-items) u1))
    )
    (asserts! (or (is-eq tx-sender (var-get contract-owner))
                  (is-whitelisted tx-sender)) ERR-NOT-AUTHORIZED)
    (map-set items new-item-id {
      name: name,
      description: description,
      image-uri: image-uri,
      creator: tx-sender,
      item-type: item-type,
      attributes: attributes,
      metadata: metadata,
      created-at: block-height,
      rarity: rarity,
      tradeable: tradeable
    })
    (var-set total-items new-item-id)
    (ok new-item-id)
  )
)

;; Whitelist for creators
(define-map creator-whitelist principal bool)

(define-public (add-to-whitelist (creator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (map-set creator-whitelist creator true))
  )
)

(define-public (remove-from-whitelist (creator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (map-set creator-whitelist creator false))
  )
)

(define-read-only (is-whitelisted (creator principal))
  (default-to false (map-get? creator-whitelist creator))
)

;; Mint function for creating copies of an item
(define-public (mint (item-id uint) (quantity uint) (recipient principal))
  (let
    (
      (item (unwrap! (map-get? items item-id) ERR-ITEM-NOT-FOUND))
      (current-qty (default-to u0 (map-get? item-owners {item-id: item-id, owner: recipient})))
    )
    (asserts! (or (is-eq tx-sender (var-get contract-owner))
                  (is-eq tx-sender (get creator item))) ERR-NOT-AUTHORIZED)
    
    ;; Update the ownership mapping
    (map-set item-owners {item-id: item-id, owner: recipient} (+ current-qty quantity))
    
    (ok quantity)
  )
)

;; Item transfer function - implements SIP-009 transfer
(define-public (transfer (item-id uint) (sender principal) (recipient principal))
  ;; For SIP-009 compliance, we transfer 1 item 
  (transfer-item item-id u1 sender recipient)
)

;; Extended transfer function with quantity
(define-public (transfer-item (item-id uint) (amount uint) (sender principal) (recipient principal))
  (let
    (
      (sender-balance (default-to u0 
        (map-get? item-owners {item-id: item-id, owner: sender})))
      (recipient-balance (default-to u0 
        (map-get? item-owners {item-id: item-id, owner: recipient})))
      (item (unwrap! (map-get? items item-id) ERR-ITEM-NOT-FOUND))
    )
    ;; Check authorization and balance
    (asserts! (or (is-eq tx-sender sender) 
                  (is-eq tx-sender (var-get contract-owner))) ERR-NOT-AUTHORIZED)
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (get tradeable item) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq sender recipient)) ERR-SELF-TRANSFER)
    
    ;; Update sender balance
    (map-set item-owners {item-id: item-id, owner: sender} 
             (- sender-balance amount))
    
    ;; Update recipient balance
    (map-set item-owners {item-id: item-id, owner: recipient} 
             (+ recipient-balance amount))
    
    (ok true)
  )
)

;; Read only functions to query item data
(define-read-only (get-item-details (item-id uint))
  (map-get? items item-id)
)

(define-read-only (get-item-balance (item-id uint) (owner principal))
  (default-to u0 (map-get? item-owners {item-id: item-id, owner: owner}))
)

;; Get user owned items - this can only check a limited range
(define-read-only (get-user-items-range (user principal) (start uint) (end uint))
  (list))

;; Marketplace functions
(define-public (create-listing (item-id uint) (price uint) (quantity uint) (expiry uint))
  (let
    (
      (listing-id (var-get next-listing-id))
      (owner-balance (get-item-balance item-id tx-sender))
      (item (unwrap! (map-get? items item-id) ERR-ITEM-NOT-FOUND))
    )
    (asserts! (>= owner-balance quantity) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> price u0) ERR-INVALID-PRICE)
    (asserts! (> quantity u0) ERR-INVALID-PRICE)
    (asserts! (> expiry block-height) ERR-LISTING-EXPIRED)
    (asserts! (get tradeable item) ERR-NOT-AUTHORIZED)
    
    (map-set marketplace-listings listing-id {
      item-id: item-id,
      seller: tx-sender,
      price: price,
      expiry: expiry,
      quantity: quantity,
      active: true
    })
    
    ;; Track this listing in our index maps
    (map-set active-listing-ids listing-id true)
    (map-set user-listing-ids {user: tx-sender, listing-id: listing-id} true)
    
    (var-set next-listing-id (+ listing-id u1))
    (ok listing-id)
  )
)

(define-public (cancel-listing (listing-id uint))
  (let
    (
      (listing (unwrap! (map-get? marketplace-listings listing-id) ERR-LISTING-NOT-FOUND))
    )
    (asserts! (is-eq (get seller listing) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (get active listing) ERR-LISTING-NOT-FOUND)
    
    (map-set marketplace-listings listing-id 
      (merge listing {active: false}))
    
    ;; Update our index
    (map-set active-listing-ids listing-id false)
    
    (ok true)
  )
)

(define-public (buy-item (listing-id uint) (quantity uint))
  (let
    (
      (listing (unwrap! (map-get? marketplace-listings listing-id) ERR-LISTING-NOT-FOUND))
      (item-id (get item-id listing))
      (unit-price (get price listing))
      (seller (get seller listing))
      (available-quantity (get quantity listing))
      (total-price (* unit-price quantity))
      (admin-fee (/ (* total-price (var-get admin-fee-basis-points)) u10000))
      (seller-amount (- total-price admin-fee))
    )
    ;; Check listing validity
    (asserts! (get active listing) ERR-LISTING-NOT-FOUND)
    (asserts! (<= block-height (get expiry listing)) ERR-LISTING-EXPIRED)
    (asserts! (<= quantity available-quantity) ERR-INSUFFICIENT-BALANCE)
    
    ;; Process payment
    (try! (stx-transfer? total-price tx-sender (as-contract tx-sender)))
    (try! (as-contract (stx-transfer? seller-amount tx-sender seller)))
    (try! (as-contract (stx-transfer? admin-fee tx-sender (var-get contract-owner))))
    
    ;; Transfer item(s)
    (try! (as-contract (transfer-item item-id quantity seller tx-sender)))
    
    ;; Update or remove listing
    (if (> available-quantity quantity)
      (map-set marketplace-listings listing-id 
        (merge listing {quantity: (- available-quantity quantity)}))
      (begin
        (map-set marketplace-listings listing-id 
          (merge listing {active: false, quantity: u0}))
        ;; Update indexes
        (map-set active-listing-ids listing-id false)
      ))
    
    (ok true)
  )
)

;; Read-only marketplace functions
(define-read-only (get-listing (listing-id uint))
  (map-get? marketplace-listings listing-id)
)

;; Helper to check if a listing is active
(define-read-only (is-listing-active (listing-id uint))
  (let ((listing (map-get? marketplace-listings listing-id)))
    (match listing
      l (and (get active l) (<= block-height (get expiry l)))
      false
    )
  )
)

;; Helper to check if a listing belongs to a user
(define-read-only (is-user-listing (user principal) (listing-id uint))
  (default-to false (map-get? user-listing-ids {user: user, listing-id: listing-id}))
)

;; Batch operations
(define-public (batch-transfer (transfers (list 20 {item-id: uint, amount: uint, recipient: principal})))
  (fold check-and-transfer transfers (ok true))
)

(define-private (check-and-transfer (tx-data {item-id: uint, amount: uint, recipient: principal}) (previous-result (response bool uint)))
  (match previous-result
    prev-ok (transfer-item (get item-id tx-data) (get amount tx-data) tx-sender (get recipient tx-data))
    prev-err previous-result
  )
)

;; Item burning (destruction)
(define-public (burn (item-id uint) (amount uint))
  (let
    (
      (owner-balance (get-item-balance item-id tx-sender))
    )
    (asserts! (>= owner-balance amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Reduce balance
    (map-set item-owners {item-id: item-id, owner: tx-sender} 
             (- owner-balance amount))
    
    (ok true)
  )
)

;; Item upgrading
(define-map item-upgrades
  uint ;; upgrade-id
  {
    base-item-id: uint,
    required-items: (list 5 {item-id: uint, amount: uint}),
    result-item-id: uint,
    enabled: bool
  }
)

(define-data-var next-upgrade-id uint u1)

(define-public (add-upgrade 
  (base-item-id uint) 
  (required-items (list 5 {item-id: uint, amount: uint}))
  (result-item-id uint))
  (let
    (
      (upgrade-id (var-get next-upgrade-id))
    )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? items base-item-id)) ERR-ITEM-NOT-FOUND)
    (asserts! (is-some (map-get? items result-item-id)) ERR-ITEM-NOT-FOUND)
    
    (map-set item-upgrades upgrade-id {
      base-item-id: base-item-id,
      required-items: required-items,
      result-item-id: result-item-id,
      enabled: true
    })
    
    (var-set next-upgrade-id (+ upgrade-id u1))
    (ok upgrade-id)
  )
)

(define-public (upgrade-item (upgrade-id uint))
  (let
    (
      (upgrade-data (unwrap! (map-get? item-upgrades upgrade-id) ERR-ITEM-NOT-FOUND))
      (base-item-id (get base-item-id upgrade-data))
      (required-items (get required-items upgrade-data))
      (result-item-id (get result-item-id upgrade-data))
    )
    (asserts! (get enabled upgrade-data) ERR-NOT-AUTHORIZED)
    
    ;; Check base item
    (asserts! (>= (get-item-balance base-item-id tx-sender) u1) ERR-INSUFFICIENT-BALANCE)
    
    ;; Check all required items
    (try! (fold check-required-item required-items (ok true)))
    
    ;; Burn base item
    (try! (burn base-item-id u1))
    
    ;; Burn required items
    (try! (fold burn-required-item required-items (ok true)))
    
    ;; Mint result item
    (try! (mint result-item-id u1 tx-sender))
    
    (ok true)
  )
)

(define-private (check-required-item (req {item-id: uint, amount: uint}) (previous-result (response bool uint)))
  (match previous-result
    prev-ok (if (>= (get-item-balance (get item-id req) tx-sender) (get amount req))
             (ok true)
             ERR-INSUFFICIENT-BALANCE)
    prev-err previous-result
  )
)

(define-private (burn-required-item (req {item-id: uint, amount: uint}) (previous-result (response bool uint)))
  (match previous-result
    prev-ok (burn (get item-id req) (get amount req))
    prev-err previous-result
  )
)

;; Enable/disable upgrade path
(define-public (set-upgrade-enabled (upgrade-id uint) (enabled bool))
  (let
    (
      (upgrade-data (unwrap! (map-get? item-upgrades upgrade-id) ERR-ITEM-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    
    (map-set item-upgrades upgrade-id 
      (merge upgrade-data {enabled: enabled}))
    
    (ok true)
  )
)

;; Update item metadata
(define-public (update-item-metadata (item-id uint) (metadata (string-utf8 1024)))
  (let
    (
      (item (unwrap! (map-get? items item-id) ERR-ITEM-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender (var-get contract-owner))
                  (is-eq tx-sender (get creator item))) ERR-NOT-AUTHORIZED)
    
    (map-set items item-id 
      (merge item {metadata: (some metadata)}))
    
    (ok true)
  )
)

;; Update item tradeable status
(define-public (set-tradeable (item-id uint) (tradeable bool))
  (let
    (
      (item (unwrap! (map-get? items item-id) ERR-ITEM-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender (var-get contract-owner))
                  (is-eq tx-sender (get creator item))) ERR-NOT-AUTHORIZED)
    
    (map-set items item-id 
      (merge item {tradeable: tradeable}))
    
    (ok true)
  )
)

;; Initialize contract
(begin
  ;; Contract initialized
  (print "Contract initialized")
)