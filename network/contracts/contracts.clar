;; Repository Name: neural-network-dmarket
;; Contract Name: neural-training-market

;; Constants and Variables
(define-constant contract-owner tx-sender)
(define-constant minimum-stake u1000000) ;; Minimum stake required for dataset providers
(define-constant validation-threshold u80) ;; Minimum performance threshold (80%)

;; Error codes
(define-constant err-not-authorized (err u100))
(define-constant err-invalid-amount (err u101))
(define-constant err-dataset-not-found (err u102))
(define-constant err-insufficient-stake (err u103))

;; Data Structures
(define-map datasets
    { dataset-id: uint }
    {
        provider: principal,
        stake-amount: uint,
        metadata-uri: (string-utf8 256),
        quality-score: uint,
        is-active: bool,
        usage-count: uint
    }
)

(define-map computation-bids
    { bid-id: uint }
    {
        developer: principal,
        dataset-id: uint,
        bid-amount: uint,
        computation-time: uint,
        deadline: uint,
        is-active: bool
    }
)

(define-map model-validations
    { model-id: uint }
    {
        bid-id: uint,
        performance-score: uint,
        validation-status: bool,
        reward-claimed: bool
    }
)

;; Public Functions

;; Register a new dataset with staking
(define-public (register-dataset (stake-amount uint) (metadata-uri (string-utf8 256)))
    (let
        (
            (dataset-id (get-next-dataset-id))
        )
        (asserts! (>= stake-amount minimum-stake) err-insufficient-stake)
        (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
        
        (map-set datasets
            { dataset-id: dataset-id }
            {
                provider: tx-sender,
                stake-amount: stake-amount,
                metadata-uri: metadata-uri,
                quality-score: u0,
                is-active: true,
                usage-count: u0
            }
        )
        (ok dataset-id)
    )
)

;; Place a bid for computation time
(define-public (place-computation-bid 
    (dataset-id uint) 
    (bid-amount uint)
    (computation-time uint)
    (deadline uint)
)
    (let
        (
            (bid-id (get-next-bid-id))
        )
        (asserts! (> deadline stacks-block-height) err-invalid-amount)
        (try! (stx-transfer? bid-amount tx-sender (as-contract tx-sender)))
        
        (map-set computation-bids
            { bid-id: bid-id }
            {
                developer: tx-sender,
                dataset-id: dataset-id,
                bid-amount: bid-amount,
                computation-time: computation-time,
                deadline: deadline,
                is-active: true
            }
        )
        (ok bid-id)
    )
)

;; Submit model validation results
(define-public (submit-validation-result 
    (model-id uint)
    (bid-id uint)
    (performance-score uint)
)
    (let
        (
            (bid (unwrap! (map-get? computation-bids { bid-id: bid-id }) err-not-authorized))
        )
        (asserts! (is-eq (get developer bid) tx-sender) err-not-authorized)
        
        (map-set model-validations
            { model-id: model-id }
            {
                bid-id: bid-id,
                performance-score: performance-score,
                validation-status: (>= performance-score validation-threshold),
                reward-claimed: false
            }
        )
        (ok true)
    )
)

;; Claim rewards for successful validation
(define-public (claim-validation-reward (model-id uint))
    (let
        (
            (validation (unwrap! (map-get? model-validations { model-id: model-id }) err-not-authorized))
            (bid (unwrap! (map-get? computation-bids { bid-id: (get bid-id validation) }) err-not-authorized))
        )
        (asserts! (get validation-status validation) err-not-authorized)
        (asserts! (not (get reward-claimed validation)) err-not-authorized)
        
        ;; Transfer rewards
        (try! (as-contract (stx-transfer? 
            (get bid-amount bid)
            tx-sender
            (get developer bid)
        )))
        
        ;; Update validation status
        (map-set model-validations
            { model-id: model-id }
            (merge validation { reward-claimed: true })
        )
        (ok true)
    )
)

;; Data variable to store the last ID
(define-data-var last-dataset-id uint u0)

;; Function to get the next ID
(define-private (get-next-dataset-id)
    (+ (var-get last-dataset-id) u1)
)

;; Data variable to store the last bid ID
(define-data-var last-bid-id uint u0)

;; Function to get the next bid ID
(define-private (get-next-bid-id)
    (+ (var-get last-bid-id) u1)
)
;; Read-only Functions
(define-read-only (get-dataset (dataset-id uint))
    (map-get? datasets { dataset-id: dataset-id })
)

(define-read-only (get-bid (bid-id uint))
    (map-get? computation-bids { bid-id: bid-id })
)

(define-read-only (get-validation (model-id uint))
    (map-get? model-validations { model-id: model-id })
)