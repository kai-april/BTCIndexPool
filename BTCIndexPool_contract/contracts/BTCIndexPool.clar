
;; title: BTCIndexPool
;; version: 1.0.0
;; summary: A cross-chain AMM liquidity pool for Bitcoin index tokens on Stacks
;; description: This contract implements an automated market maker (AMM) for Bitcoin index tokens,
;;              allowing users to provide liquidity and swap between different BTC-related tokens.

;; traits
(define-trait sip-010-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; token definitions
(define-fungible-token btc-index-lp)

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u103))
(define-constant ERR_SLIPPAGE_EXCEEDED (err u104))
(define-constant ERR_POOL_EXISTS (err u105))
(define-constant ERR_INSUFFICIENT_BALANCE (err u106))
(define-constant ERR_ZERO_AMOUNT (err u107))
(define-constant ERR_IDENTICAL_TOKENS (err u108))

(define-constant FEE_RATE u300) ;; 0.3% fee (300 basis points out of 100000)
(define-constant FEE_DENOMINATOR u100000)
(define-constant MINIMUM_LIQUIDITY u1000)

;; data vars
(define-data-var protocol-fee-enabled bool false)
(define-data-var protocol-fee-rate uint u50) ;; 0.05% protocol fee
(define-data-var total-pools uint u0)

;; data maps
(define-map pools
  { token-a: principal, token-b: principal }
  {
    reserve-a: uint,
    reserve-b: uint,
    lp-token-supply: uint,
    last-update: uint
  }
)

(define-map user-liquidity
  { user: principal, token-a: principal, token-b: principal }
  { lp-tokens: uint }
)

(define-map authorized-tokens principal bool)

;; public functions

;; Initialize a new liquidity pool for two tokens
(define-public (create-pool (token-a <sip-010-trait>) (token-b <sip-010-trait>))
  (let ((token-a-contract (contract-of token-a))
        (token-b-contract (contract-of token-b)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq token-a-contract token-b-contract)) ERR_IDENTICAL_TOKENS)
    (asserts! (is-none (map-get? pools { token-a: token-a-contract, token-b: token-b-contract })) ERR_POOL_EXISTS)
    (asserts! (is-none (map-get? pools { token-a: token-b-contract, token-b: token-a-contract })) ERR_POOL_EXISTS)

    (map-set pools
      { token-a: token-a-contract, token-b: token-b-contract }
      {
        reserve-a: u0,
        reserve-b: u0,
        lp-token-supply: u0,
        last-update: block-height
      }
    )
    (var-set total-pools (+ (var-get total-pools) u1))
    (ok true)
  )
)

;; Add liquidity to an existing pool
(define-public (add-liquidity
  (token-a <sip-010-trait>)
  (token-b <sip-010-trait>)
  (amount-a uint)
  (amount-b uint)
  (min-lp-tokens uint))
  (let ((token-a-contract (contract-of token-a))
        (token-b-contract (contract-of token-b))
        (pool-key (get-pool-key token-a-contract token-b-contract))
        (pool-data (unwrap! (map-get? pools pool-key) ERR_NOT_FOUND)))

    (asserts! (> amount-a u0) ERR_ZERO_AMOUNT)
    (asserts! (> amount-b u0) ERR_ZERO_AMOUNT)

    (let ((reserve-a (get reserve-a pool-data))
          (reserve-b (get reserve-b pool-data))
          (lp-supply (get lp-token-supply pool-data))
          (lp-tokens-to-mint (if (is-eq lp-supply u0)
                               (- (simple-sqrt (* amount-a amount-b)) MINIMUM_LIQUIDITY)
                               (min
                                 (/ (* amount-a lp-supply) reserve-a)
                                 (/ (* amount-b lp-supply) reserve-b)))))

      (asserts! (>= lp-tokens-to-mint min-lp-tokens) ERR_SLIPPAGE_EXCEEDED)

      ;; Transfer tokens from user
      (try! (contract-call? token-a transfer amount-a tx-sender (as-contract tx-sender) none))
      (try! (contract-call? token-b transfer amount-b tx-sender (as-contract tx-sender) none))

      ;; Mint LP tokens
      (try! (ft-mint? btc-index-lp lp-tokens-to-mint tx-sender))

      ;; Update pool reserves
      (map-set pools pool-key
        {
          reserve-a: (+ reserve-a amount-a),
          reserve-b: (+ reserve-b amount-b),
          lp-token-supply: (+ lp-supply lp-tokens-to-mint),
          last-update: block-height
        }
      )

      ;; Update user liquidity tracking
      (let ((current-lp (default-to u0 (get lp-tokens (map-get? user-liquidity { user: tx-sender, token-a: token-a-contract, token-b: token-b-contract })))))
        (map-set user-liquidity
          { user: tx-sender, token-a: token-a-contract, token-b: token-b-contract }
          { lp-tokens: (+ current-lp lp-tokens-to-mint) }
        )
      )

      (ok lp-tokens-to-mint)
    )
  )
)

;; Remove liquidity from a pool
(define-public (remove-liquidity
  (token-a <sip-010-trait>)
  (token-b <sip-010-trait>)
  (lp-tokens uint)
  (min-amount-a uint)
  (min-amount-b uint))
  (let ((token-a-contract (contract-of token-a))
        (token-b-contract (contract-of token-b))
        (pool-key (get-pool-key token-a-contract token-b-contract))
        (pool-data (unwrap! (map-get? pools pool-key) ERR_NOT_FOUND)))

    (asserts! (> lp-tokens u0) ERR_ZERO_AMOUNT)

    (let ((reserve-a (get reserve-a pool-data))
          (reserve-b (get reserve-b pool-data))
          (lp-supply (get lp-token-supply pool-data))
          (amount-a (/ (* lp-tokens reserve-a) lp-supply))
          (amount-b (/ (* lp-tokens reserve-b) lp-supply)))

      (asserts! (>= amount-a min-amount-a) ERR_SLIPPAGE_EXCEEDED)
      (asserts! (>= amount-b min-amount-b) ERR_SLIPPAGE_EXCEEDED)

      ;; Burn LP tokens
      (try! (ft-burn? btc-index-lp lp-tokens tx-sender))

      ;; Transfer tokens to user
      (try! (as-contract (contract-call? token-a transfer amount-a tx-sender tx-sender none)))
      (try! (as-contract (contract-call? token-b transfer amount-b tx-sender tx-sender none)))

      ;; Update pool reserves
      (map-set pools pool-key
        {
          reserve-a: (- reserve-a amount-a),
          reserve-b: (- reserve-b amount-b),
          lp-token-supply: (- lp-supply lp-tokens),
          last-update: block-height
        }
      )

      ;; Update user liquidity tracking
      (let ((current-lp (default-to u0 (get lp-tokens (map-get? user-liquidity { user: tx-sender, token-a: token-a-contract, token-b: token-b-contract })))))
        (if (> current-lp lp-tokens)
          (map-set user-liquidity
            { user: tx-sender, token-a: token-a-contract, token-b: token-b-contract }
            { lp-tokens: (- current-lp lp-tokens) }
          )
          (map-delete user-liquidity { user: tx-sender, token-a: token-a-contract, token-b: token-b-contract })
        )
      )

      (ok { amount-a: amount-a, amount-b: amount-b })
    )
  )
)

;; Swap tokens using the AMM
(define-public (swap
  (token-in <sip-010-trait>)
  (token-out <sip-010-trait>)
  (amount-in uint)
  (min-amount-out uint))
  (let ((token-in-contract (contract-of token-in))
        (token-out-contract (contract-of token-out))
        (pool-key (get-pool-key token-in-contract token-out-contract))
        (pool-data (unwrap! (map-get? pools pool-key) ERR_NOT_FOUND)))

    (asserts! (> amount-in u0) ERR_ZERO_AMOUNT)
    (asserts! (not (is-eq token-in-contract token-out-contract)) ERR_IDENTICAL_TOKENS)

    (let ((is-token-a (is-eq token-in-contract (get token-a pool-key)))
          (reserve-in (if is-token-a (get reserve-a pool-data) (get reserve-b pool-data)))
          (reserve-out (if is-token-a (get reserve-b pool-data) (get reserve-a pool-data)))
          (amount-in-with-fee (- amount-in (/ (* amount-in FEE_RATE) FEE_DENOMINATOR)))
          (amount-out (/ (* amount-in-with-fee reserve-out) (+ reserve-in amount-in-with-fee))))

      (asserts! (>= amount-out min-amount-out) ERR_SLIPPAGE_EXCEEDED)
      (asserts! (< amount-out reserve-out) ERR_INSUFFICIENT_LIQUIDITY)

      ;; Transfer tokens
      (try! (contract-call? token-in transfer amount-in tx-sender (as-contract tx-sender) none))
      (try! (as-contract (contract-call? token-out transfer amount-out tx-sender tx-sender none)))

      ;; Update pool reserves
      (map-set pools pool-key
        {
          reserve-a: (if is-token-a (+ (get reserve-a pool-data) amount-in) (- (get reserve-a pool-data) amount-out)),
          reserve-b: (if is-token-a (- (get reserve-b pool-data) amount-out) (+ (get reserve-b pool-data) amount-in)),
          lp-token-supply: (get lp-token-supply pool-data),
          last-update: block-height
        }
      )

      (ok amount-out)
    )
  )
)

;; Administrative function to authorize tokens
(define-public (authorize-token (token principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set authorized-tokens token true)
    (ok true)
  )
)

;; read only functions

;; Get pool information
(define-read-only (get-pool-info (token-a principal) (token-b principal))
  (map-get? pools (get-pool-key token-a token-b))
)

;; Get user liquidity position
(define-read-only (get-user-liquidity (user principal) (token-a principal) (token-b principal))
  (map-get? user-liquidity { user: user, token-a: token-a, token-b: token-b })
)

;; Calculate swap output amount
(define-read-only (get-amount-out (amount-in uint) (reserve-in uint) (reserve-out uint))
  (if (or (is-eq amount-in u0) (is-eq reserve-in u0) (is-eq reserve-out u0))
    u0
    (let ((amount-in-with-fee (- amount-in (/ (* amount-in FEE_RATE) FEE_DENOMINATOR))))
      (/ (* amount-in-with-fee reserve-out) (+ reserve-in amount-in-with-fee))
    )
  )
)

;; Get total number of pools
(define-read-only (get-total-pools)
  (var-get total-pools)
)

;; Check if token is authorized
(define-read-only (is-token-authorized (token principal))
  (default-to false (map-get? authorized-tokens token))
)

;; private functions

;; Helper function to find minimum of two values
(define-private (min (a uint) (b uint))
  (if (<= a b) a b)
)

;; Helper function to get consistent pool key ordering
;; Use a simple comparison based on the buffer representation
(define-private (get-pool-key (token-a principal) (token-b principal))
  (let ((buff-a (unwrap-panic (to-consensus-buff? token-a)))
        (buff-b (unwrap-panic (to-consensus-buff? token-b))))
    (if (< buff-a buff-b)
      { token-a: token-a, token-b: token-b }
      { token-a: token-b, token-b: token-a }
    )
  )
)

;; Simple square root approximation for LP token calculation
;; Uses iterative binary search to avoid recursion
(define-private (simple-sqrt (n uint))
  (if (<= n u1)
    n
    (sqrt-binary-search-iterative n u1 (/ n u2))
  )
)

;; Iterative binary search for square root to avoid recursion
(define-private (sqrt-binary-search-iterative (n uint) (start uint) (end uint))
  (let ((result (fold sqrt-search-step
                     (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31)
                     { n: n, start: start, end: end, result: start })))
    (get result result)
  )
)

;; Helper function for iterative square root calculation
(define-private (sqrt-search-step (iteration uint) (state { n: uint, start: uint, end: uint, result: uint }))
  (let ((start (get start state))
        (end (get end state))
        (n (get n state)))
    (if (> start end)
      state
      (let ((mid (/ (+ start end) u2))
            (square (* mid mid)))
        (if (is-eq square n)
          (merge state { result: mid, start: (+ end u1) }) ;; Found exact match, terminate
          (if (< square n)
            (merge state { start: (+ mid u1), result: mid })
            (merge state { end: (- mid u1) })
          )
        )
      )
    )
  )
)
