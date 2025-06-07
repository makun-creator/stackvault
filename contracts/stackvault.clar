;; StackVault - Bitcoin Layer 2 Portfolio Manager
;;
;; Summary:
;;   Enterprise-grade decentralized portfolio management protocol engineered 
;;   for Bitcoin Layer 2 ecosystems, delivering institutional-level asset 
;;   allocation strategies with Bitcoin's inherent security guarantees.
;;
;; Description:
;;   StackVault Pro revolutionizes decentralized finance by bringing Wall Street-caliber
;;   portfolio management to the Bitcoin ecosystem. Built on Stacks' secure foundation,
;;   this protocol empowers users to construct sophisticated multi-asset portfolios with
;;   intelligent rebalancing algorithms, precise allocation controls, and comprehensive
;;   risk management tools. Unlike traditional DeFi platforms, StackVault Pro maintains
;;   Bitcoin's core principles of self-custody and decentralization while delivering
;;   the advanced features typically reserved for institutional investors.
;;
;;   Perfect for crypto natives seeking to optimize their Bitcoin L2 holdings through
;;   systematic diversification and automated portfolio management strategies.

;; ERROR CODES
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-PORTFOLIO (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-INVALID-TOKEN (err u103))
(define-constant ERR-REBALANCE-FAILED (err u104))
(define-constant ERR-PORTFOLIO-EXISTS (err u105))
(define-constant ERR-INVALID-PERCENTAGE (err u106))
(define-constant ERR-MAX-TOKENS-EXCEEDED (err u107))
(define-constant ERR-LENGTH-MISMATCH (err u108))
(define-constant ERR-USER-STORAGE-FAILED (err u109))
(define-constant ERR-INVALID-TOKEN-ID (err u110))

;; DATA VARIABLES
(define-data-var protocol-owner principal tx-sender)
(define-data-var portfolio-counter uint u0)
(define-data-var protocol-fee uint u25) ;; 0.25% represented as basis points

;; CONSTANTS
(define-constant MAX-TOKENS-PER-PORTFOLIO u10)
(define-constant BASIS-POINTS u10000)

;; DATA MAPS
(define-map Portfolios
  uint ;; portfolio-id
  {
    owner: principal,
    created-at: uint,
    last-rebalanced: uint,
    total-value: uint,
    active: bool,
    token-count: uint,
  }
)

(define-map PortfolioAssets
  {
    portfolio-id: uint,
    token-id: uint,
  }
  {
    target-percentage: uint,
    current-amount: uint,
    token-address: principal,
  }
)

(define-map UserPortfolios
  principal
  (list 20 uint)
)

;; READ-ONLY FUNCTIONS

;; Get portfolio information by ID
(define-read-only (get-portfolio (portfolio-id uint))
  (map-get? Portfolios portfolio-id)
)

;; Get specific asset information within a portfolio
(define-read-only (get-portfolio-asset
    (portfolio-id uint)
    (token-id uint)
  )
  (map-get? PortfolioAssets {
    portfolio-id: portfolio-id,
    token-id: token-id,
  })
)

;; Get all portfolios owned by a user
(define-read-only (get-user-portfolios (user principal))
  (default-to (list) (map-get? UserPortfolios user))
)

;; Calculate rebalancing requirements for a portfolio
(define-read-only (calculate-rebalance-amounts (portfolio-id uint))
  (let (
      (portfolio (unwrap! (get-portfolio portfolio-id) ERR-INVALID-PORTFOLIO))
      (total-value (get total-value portfolio))
    )
    (ok {
      portfolio-id: portfolio-id,
      total-value: total-value,
      needs-rebalance: (> (- stacks-block-height (get last-rebalanced portfolio)) u144), ;; 24 hours in blocks
    })
  )
)

;; PRIVATE FUNCTIONS

;; Validate token ID within portfolio constraints
(define-private (validate-token-id
    (portfolio-id uint)
    (token-id uint)
  )
  (let ((portfolio (unwrap! (get-portfolio portfolio-id) false)))
    (and
      (< token-id MAX-TOKENS-PER-PORTFOLIO)
      (< token-id (get token-count portfolio))
      true
    )
  )
)

;; Validate percentage is within acceptable range
(define-private (validate-percentage (percentage uint))
  (and (>= percentage u0) (<= percentage BASIS-POINTS))
)

;; Validate all percentages in a portfolio allocation
(define-private (validate-portfolio-percentages (percentages (list 10 uint)))
  (fold check-percentage-sum percentages true)
)

;; Helper function for percentage validation
(define-private (check-percentage-sum
    (current-percentage uint)
    (valid bool)
  )
  (and valid (validate-percentage current-percentage))
)

;; Add portfolio to user's portfolio list
(define-private (add-to-user-portfolios
    (user principal)
    (portfolio-id uint)
  )
  (let (
      (current-portfolios (get-user-portfolios user))
      (new-portfolios (unwrap! (as-max-len? (append current-portfolios portfolio-id) u20)
        ERR-USER-STORAGE-FAILED
      ))
    )
    (map-set UserPortfolios user new-portfolios)
    (ok true)
  )
)

;; Initialize individual portfolio asset
(define-private (initialize-portfolio-asset
    (index uint)
    (token principal)
    (percentage uint)
    (portfolio-id uint)
  )
  (if (>= percentage u0) ;; Only check percentage validity since principal is already a valid type
    (begin
      (map-set PortfolioAssets {
        portfolio-id: portfolio-id,
        token-id: index,
      } {
        target-percentage: percentage,
        current-amount: u0,
        token-address: token,
      })
      (ok true)
    )
    ERR-INVALID-TOKEN
  )
)