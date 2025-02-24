# TimeCapsuleFund

TimeCapsuleFund is a Clarity smart contract platform that enables time-locked charitable donations with built-in inheritance features. It allows donors to contribute funds, earn yields, and set up multi-tiered inheritance plans while supporting charitable causes.

## Features

### Core Functionality
- **Deposit System**: Donors can contribute STX tokens to the fund
- **Yield Generation**: Automated 5% yield calculation on deposited funds
- **Charitable Distribution**: Yields can be distributed to registered charities
- **Endorsement System**: Donors can endorse registered charities

### Inheritance Management
- **Multi-Tier System**: Support for three inheritance levels
- **Time-Lock Mechanism**: Customizable waiting periods for each inheritance tier
- **Percentage-Based Distribution**: Flexible inheritance share allocation
- **Automated Notifications**: Time-based alerts for potential heirs

### Transparency
- Real-time access to fund statistics
- Complete transaction history
- Public charity registry
- Transparent inheritance settings

## Smart Contract Interface

### Main Functions

#### Deposit Management
```clarity
(define-public (deposit))
(define-public (compute-yield))
(define-public (distribute-yield (name (string-ascii 64))))
```

#### Charity Operations
```clarity
(define-public (add-charity (name (string-ascii 64)) (address principal)))
(define-public (endorse-charity (name (string-ascii 64))))
```

#### Inheritance Control
```clarity
(define-public (set-inheritance-level (level uint) (wait-period uint) (heir principal) (percentage uint)))
(define-public (remove-inheritance-level (level uint)))
(define-public (check-inheritance-status))
```

### Read-Only Functions

```clarity
(define-read-only (get-fund-status))
(define-read-only (get-donor-balance (donor principal)))
(define-read-only (get-charity-info (name (string-ascii 64))))
(define-read-only (get-inheritance-level (owner principal) (level uint)))
```

## Error Codes

| Code | Description |
|------|-------------|
| u100 | Not authorized |
| u101 | Insufficient funds |
| u102 | Charity not found |
| u103 | Already endorsed |
| u104 | Transfer failed |
| u105 | Invalid inheritance level |
| u106 | Heir not found |
| u107 | Not an heir |
| u108 | Time locked |

## Usage Examples

### Setting Up an Inheritance Plan

```clarity
;; Set up a Level 1 inheritance with a 30-day waiting period
(set-inheritance-level 
    u1                  ;; Level
    u4320              ;; Wait period (30 days in blocks)
    'SP2ABCDEF...      ;; Heir address
    u50                ;; 50% inheritance share
)
```

### Contributing to the Fund

```clarity
;; Deposit funds
(deposit)

;; Check your balance
(get-donor-balance tx-sender)
```

### Charity Support

```clarity
;; Endorse a charity
(endorse-charity "charity-name")

;; Check charity information
(get-charity-info "charity-name")
```

## Security Considerations

1. **Time-Lock Protection**: All inheritance claims are subject to waiting periods
2. **Authorization Checks**: Administrative functions restricted to owner
3. **Balance Verification**: Automatic checks for sufficient funds
4. **Duplicate Prevention**: Guards against multiple endorsements
5. **Safe Transfer Protocol**: Protected STX transfer mechanisms

## Development and Testing

### Prerequisites
- Clarity CLI
- Stacks blockchain development environment
- STX testnet access

### Local Development
1. Clone the repository
2. Deploy to local Clarity environment
3. Run test suite
4. Test with testnet STX

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit changes
4. Submit pull request
