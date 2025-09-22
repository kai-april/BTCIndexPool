# BTCIndexPool

BTCIndexPool is a cross-chain Automated Market Maker (AMM) liquidity pool for Bitcoin index tokens built on the Stacks blockchain using Clarity smart contracts.

## Description

BTCIndexPool provides decentralized liquidity for Bitcoin-related tokens through an automated market maker mechanism. Users can create liquidity pools, provide liquidity to earn fees, and swap between different BTC-related tokens in a trustless manner.

## Features

- **Automated Market Maker**: Constant product formula (x * y = k) for token swaps
- **Liquidity Pool Creation**: Create new trading pairs for any SIP-010 compliant tokens
- **Liquidity Provision**: Add liquidity to pools and earn LP tokens representing your share
- **Token Swapping**: Swap between tokens with automatic price discovery
- **Fee Structure**: 0.3% trading fees distributed to liquidity providers
- **Slippage Protection**: Minimum output amounts to protect against excessive slippage
- **Authorization System**: Token authorization mechanism for enhanced security
- **Cross-chain Support**: Designed for Bitcoin index tokens across different chains

## Technical Specifications

- **Blockchain**: Stacks
- **Language**: Clarity
- **Standard**: SIP-010 (Stacks Improvement Proposal for Fungible Tokens)
- **Clarity Version**: 2
- **Epoch**: 2.5
- **Trading Fee**: 0.3% (300 basis points)
- **Protocol Fee**: 0.05% (configurable)
- **Minimum Liquidity**: 1,000 units

## Installation

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) for local development
- Node.js and npm for testing
- Stacks wallet for mainnet deployment

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd BTCIndexPool
```

2. Install dependencies:
```bash
cd BTCIndexPool_contract
npm install
```

3. Run tests:
```bash
npm run test
```

4. Run tests with coverage:
```bash
npm run test:report
```

## Usage Examples

### Creating a New Pool

Only the contract owner can create new pools:

```clarity
(contract-call? .BTCIndexPool create-pool .token-a .token-b)
```

### Adding Liquidity

Provide liquidity to an existing pool:

```clarity
(contract-call? .BTCIndexPool add-liquidity
  .token-a
  .token-b
  u1000000  ;; amount of token A
  u2000000  ;; amount of token B
  u900000   ;; minimum LP tokens to receive
)
```

### Removing Liquidity

Remove liquidity from a pool:

```clarity
(contract-call? .BTCIndexPool remove-liquidity
  .token-a
  .token-b
  u500000   ;; LP tokens to burn
  u450000   ;; minimum token A to receive
  u900000   ;; minimum token B to receive
)
```

### Token Swapping

Swap tokens through the AMM:

```clarity
(contract-call? .BTCIndexPool swap
  .token-in
  .token-out
  u1000000  ;; amount to swap in
  u950000   ;; minimum amount to receive
)
```

## Contract Functions

### Public Functions

#### `create-pool`
Creates a new liquidity pool for two SIP-010 tokens.
- **Parameters**: `token-a`, `token-b`
- **Access**: Contract owner only
- **Returns**: `(response bool uint)`

#### `add-liquidity`
Adds liquidity to an existing pool and mints LP tokens.
- **Parameters**: `token-a`, `token-b`, `amount-a`, `amount-b`, `min-lp-tokens`
- **Access**: Public
- **Returns**: `(response uint uint)` - LP tokens minted

#### `remove-liquidity`
Removes liquidity from a pool and burns LP tokens.
- **Parameters**: `token-a`, `token-b`, `lp-tokens`, `min-amount-a`, `min-amount-b`
- **Access**: Public
- **Returns**: `(response {amount-a: uint, amount-b: uint} uint)`

#### `swap`
Swaps one token for another using the AMM.
- **Parameters**: `token-in`, `token-out`, `amount-in`, `min-amount-out`
- **Access**: Public
- **Returns**: `(response uint uint)` - Amount received

#### `authorize-token`
Authorizes a token for use in the protocol.
- **Parameters**: `token`
- **Access**: Contract owner only
- **Returns**: `(response bool uint)`

### Read-Only Functions

#### `get-pool-info`
Returns pool information including reserves and LP token supply.
- **Parameters**: `token-a`, `token-b`
- **Returns**: Pool data or none

#### `get-user-liquidity`
Returns a user's liquidity position in a specific pool.
- **Parameters**: `user`, `token-a`, `token-b`
- **Returns**: LP token balance or none

#### `get-amount-out`
Calculates the output amount for a given input amount.
- **Parameters**: `amount-in`, `reserve-in`, `reserve-out`
- **Returns**: Output amount

#### `get-total-pools`
Returns the total number of pools created.
- **Returns**: Number of pools

#### `is-token-authorized`
Checks if a token is authorized for use.
- **Parameters**: `token`
- **Returns**: Authorization status

## Deployment Guide

### Local Development

1. Start Clarinet console:
```bash
clarinet console
```

2. Deploy and test contracts in the REPL environment

### Testnet Deployment

1. Configure testnet settings in `settings/Testnet.toml`
2. Deploy using Clarinet:
```bash
clarinet deployments apply --testnet
```

### Mainnet Deployment

1. Configure mainnet settings in `settings/Mainnet.toml`
2. Ensure thorough testing on testnet
3. Deploy using Clarinet:
```bash
clarinet deployments apply --mainnet
```

## Security Notes

### Important Considerations

- **Smart Contract Risk**: This contract handles user funds and should be thoroughly audited before mainnet deployment
- **Slippage Protection**: Always set appropriate minimum amounts to protect against MEV attacks
- **Token Authorization**: Only authorized tokens should be used in pools for additional security
- **Reentrancy**: The contract uses proper token transfer patterns to prevent reentrancy attacks
- **Access Control**: Pool creation is restricted to the contract owner

### Best Practices

1. **Test Thoroughly**: Run comprehensive tests before deployment
2. **Use Minimum Amounts**: Always specify minimum output amounts for swaps and liquidity operations
3. **Monitor Pool Health**: Check pool reserves and liquidity levels regularly
4. **Gradual Rollout**: Start with small amounts and gradually increase exposure
5. **Emergency Procedures**: Have contingency plans for potential issues

### Error Codes

- `100`: Unauthorized access
- `101`: Pool or resource not found
- `102`: Invalid amount specified
- `103`: Insufficient liquidity in pool
- `104`: Slippage tolerance exceeded
- `105`: Pool already exists
- `106`: Insufficient token balance
- `107`: Zero amount not allowed
- `108`: Identical tokens not allowed

## Testing

The project includes comprehensive test coverage using Vitest and the Clarinet SDK:

```bash
# Run all tests
npm run test

# Run tests with coverage and cost analysis
npm run test:report

# Watch mode for development
npm run test:watch
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes with appropriate tests
4. Submit a pull request

## License

This project is licensed under the ISC License.

## Disclaimer

This software is provided as-is without any warranty. Users should conduct their own security audits and testing before using in production environments. The authors are not responsible for any losses incurred through the use of this software.