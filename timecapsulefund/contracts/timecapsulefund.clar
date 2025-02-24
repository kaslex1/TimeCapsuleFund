
;; TimeCapsuleFund: A Time-Locked Charitable Donation Platform with Inheritance Features

;; Constants
(define-constant owner-wallet tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-low-funds (err u101))
(define-constant err-charity-not-found (err u102))
(define-constant err-already-endorsed (err u103))
(define-constant err-transfer-failed (err u104))
(define-constant err-invalid-inheritance-level (err u105))
(define-constant err-heir-not-found (err u106))
(define-constant err-not-heir (err u107))
(define-constant err-time-locked (err u108))

;; Data Variables
(define-data-var fund-total uint u0)
(define-data-var pending-yield uint u0)
(define-data-var last-active-block uint u0)
(define-map donor-balances principal uint)
(define-map charities {name: (string-ascii 64)} {address: principal, endorsement-count: uint})
(define-map endorsements {charity: (string-ascii 64), donor: principal} bool)
(define-map inheritance-levels 
  {owner: principal, level: uint} 
  {wait-period: uint, heir: principal, percentage: uint, last-notification: uint}
)
(define-map heir-notifications 
  {heir: principal, owner: principal} 
  {level: uint, trigger-time: uint, notified: bool}
)

;; Private Functions
(define-private (process-transfer (recipient principal) (amount uint))
  (match (as-contract (stx-transfer? amount tx-sender recipient))
    success (ok amount)
    error (err err-transfer-failed)
  )
)

(define-private (update-activity)
  (var-set last-active-block block-height)
)

;; Public Functions
(define-public (deposit)
  (let ((amount (stx-get-balance tx-sender)))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set donor-balances tx-sender (+ (default-to u0 (map-get? donor-balances tx-sender)) amount))
    (var-set fund-total (+ (var-get fund-total) amount))
    (update-activity)
    (ok amount)
  )
)

(define-public (compute-yield)
  (let (
    (new-yield (/ (* (var-get fund-total) u5) u100)) ;; 5% yield for simulation
  )
    (var-set pending-yield (+ (var-get pending-yield) new-yield))
    (update-activity)
    (ok new-yield)
  )
)

(define-public (distribute-yield (name (string-ascii 64)))
  (let (
    (charity-info (unwrap! (map-get? charities {name: name}) (err err-charity-not-found)))
    (yield-amount (var-get pending-yield))
  )
    (match (process-transfer (get address charity-info) yield-amount)
      success (begin
        (var-set pending-yield u0)
        (update-activity)
        (ok yield-amount)
      )
      error (err err-transfer-failed)
    )
  )
)

(define-read-only (get-fund-status)
  (ok {
    total-balance: (var-get fund-total),
    undistributed-yield: (var-get pending-yield)
  })
)

(define-public (add-charity (name (string-ascii 64)) (address principal))
  (begin
    (asserts! (is-eq tx-sender owner-wallet) err-not-authorized)
    (map-set charities {name: name} {address: address, endorsement-count: u0})
    (update-activity)
    (ok true)
  )
)

(define-public (endorse-charity (name (string-ascii 64)))
  (let (
    (previous-endorsement (default-to false (map-get? endorsements {charity: name, donor: tx-sender})))
    (current-endorsements (get endorsement-count (unwrap! (map-get? charities {name: name}) err-charity-not-found)))
  )
    (asserts! (not previous-endorsement) err-already-endorsed)
    (map-set endorsements {charity: name, donor: tx-sender} true)
    (map-set charities {name: name} 
      (merge (unwrap! (map-get? charities {name: name}) err-charity-not-found)
             {endorsement-count: (+ u1 current-endorsements)}))
    (update-activity)
    (ok true)
  )
)

;; Inheritance Level Management
(define-public (set-inheritance-level (level uint) (wait-period uint) (heir principal) (percentage uint))
  (begin
    (asserts! (and (>= level u1) (<= level u3)) err-invalid-inheritance-level)
    (asserts! (<= percentage u100) err-invalid-inheritance-level)
    (map-set inheritance-levels {owner: tx-sender, level: level} 
      {wait-period: wait-period, heir: heir, percentage: percentage, last-notification: u0})
    (update-activity)
    (ok true)
  )
)

(define-public (remove-inheritance-level (level uint))
  (begin
    (asserts! (and (>= level u1) (<= level u3)) err-invalid-inheritance-level)
    (map-delete inheritance-levels {owner: tx-sender, level: level})
    (update-activity)
    (ok true)
  )
)

(define-read-only (get-inheritance-level (owner principal) (level uint))
  (match (map-get? inheritance-levels {owner: owner, level: level})
    level-info (ok level-info)
    (err err-heir-not-found)
  )
)

(define-private (execute-inheritance (owner principal) (heir principal) (percentage uint) (total-balance uint))
  (let (
    (transfer-amount (/ (* total-balance percentage) u100))
  )
    (match (as-contract (stx-transfer? transfer-amount tx-sender heir))
      success (begin
        (var-set fund-total (- total-balance transfer-amount))
        (map-delete donor-balances owner)
        (map-delete inheritance-levels {owner: owner, level: u1})
        (map-delete inheritance-levels {owner: owner, level: u2})
        (map-delete inheritance-levels {owner: owner, level: u3})
        (map-delete heir-notifications {heir: heir, owner: owner})
        (ok transfer-amount)
      )
      error (err err-transfer-failed)
    )
  )
)

;; Time-Based Notification System
(define-public (check-inheritance-status)
  (let (
    (current-block block-height)
    (last-activity (var-get last-active-block))
  )
    (map-set heir-notifications 
      {heir: tx-sender, owner: owner-wallet}
      (merge 
        (default-to 
          {level: u0, trigger-time: u0, notified: false}
          (map-get? heir-notifications {heir: tx-sender, owner: owner-wallet})
        )
        {
          level: (get-highest-eligible-level tx-sender owner-wallet current-block last-activity),
          trigger-time: (+ last-activity (get-wait-period tx-sender owner-wallet)),
          notified: true
        }
      )
    )
    (ok true)
  )
)

(define-private (get-highest-eligible-level (heir principal) (owner principal) (current-block uint) (last-activity uint))
  (let (
    (level-1 (default-to {wait-period: u0, heir: 'SP000000000000000000002Q6VF78, percentage: u0, last-notification: u0} 
              (map-get? inheritance-levels {owner: owner, level: u1})))
    (level-2 (default-to {wait-period: u0, heir: 'SP000000000000000000002Q6VF78, percentage: u0, last-notification: u0} 
              (map-get? inheritance-levels {owner: owner, level: u2})))
    (level-3 (default-to {wait-period: u0, heir: 'SP000000000000000000002Q6VF78, percentage: u0, last-notification: u0} 
              (map-get? inheritance-levels {owner: owner, level: u3})))
  )
    (if (and (is-eq heir (get heir level-3)) (>= (- current-block last-activity) (get wait-period level-3)))
      u3
      (if (and (is-eq heir (get heir level-2)) (>= (- current-block last-activity) (get wait-period level-2)))
        u2
        (if (and (is-eq heir (get heir level-1)) (>= (- current-block last-activity) (get wait-period level-1)))
          u1
          u0
        )
      )
    )
  )
)

(define-private (get-wait-period (heir principal) (owner principal))
  (let (
    (level-1 (default-to {wait-period: u0, heir: 'SP000000000000000000002Q6VF78, percentage: u0, last-notification: u0} 
              (map-get? inheritance-levels {owner: owner, level: u1})))
    (level-2 (default-to {wait-period: u0, heir: 'SP000000000000000000002Q6VF78, percentage: u0, last-notification: u0} 
              (map-get? inheritance-levels {owner: owner, level: u2})))
    (level-3 (default-to {wait-period: u0, heir: 'SP000000000000000000002Q6VF78, percentage: u0, last-notification: u0} 
              (map-get? inheritance-levels {owner: owner, level: u3})))
  )
    (if (is-eq heir (get heir level-3))
      (get wait-period level-3)
      (if (is-eq heir (get heir level-2))
        (get wait-period level-2)
        (if (is-eq heir (get heir level-1))
          (get wait-period level-1)
          u0
        )
      )
    )
  )
)

;; Read-only functions for transparency
(define-read-only (get-donor-balance (donor principal))
  (ok (default-to u0 (map-get? donor-balances donor)))
)

(define-read-only (get-charity-info (name (string-ascii 64)))
  (ok (unwrap! (map-get? charities {name: name}) err-charity-not-found))
)

(define-read-only (get-total-funds)
  (ok (var-get fund-total))
)

(define-read-only (get-undistributed-yield)
  (ok (var-get pending-yield))
)

(define-read-only (get-last-activity-block)
  (ok (var-get last-active-block))
)

(define-read-only (get-heir-notification (heir principal) (owner principal))
  (ok (unwrap! (map-get? heir-notifications {heir: heir, owner: owner}) err-not-heir))
)