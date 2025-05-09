;; Standard NFT trait for the Stacks blockchain
;; Implements SIP-009 (Standard Trait Definition for Non-Fungible Tokens)

(define-trait nft-trait
  (
    ;; Last token ID, limited to uint range
    (get-last-token-id () (response uint uint))

    ;; URI for metadata associated with the token
    (get-token-uri (uint) (response (optional (string-utf8 256)) uint))

    ;; Owner of a given token ID
    (get-owner (uint) (response (optional principal) uint))

    ;; Transfer from the sender to a new principal
    (transfer (uint principal principal) (response bool uint))
  )
)