# 🧾 Basic Escrow Smart Contract

This is a simple yet secure Ethereum smart contract that functions as a basic escrow system. It enables a buyer to deposit funds that are later released to a seller, or refunded under specific conditions. It is fully tested using Foundry with high code and branch coverage.

## 💡 Features

- Buyer deposits ETH into the contract
- Funds are locked until:
  - Buyer releases to seller, or
  - Buyer cancels and requests a refund
  - Buyer cancels with timeout if seller is unresponsive
- Strict access control: only the buyer can trigger key actions
- Emits events for `Deposited`, `Released`, and `Refunded`
- Fully tested with Foundry (17 passing tests, >87% branch coverage)

## ⚙️ Tech Stack

- Solidity `^0.8.25`
- Foundry (`forge`, `anvil`)
- Custom testing utilities:
  - Direct storage manipulation
  - `vm.expectRevert`
  - Edge case simulations

## ✅ Test Coverage

- 100% Line Coverage
- 100% Function Coverage
- 100% Statement Coverage
- 87.5% Branch Coverage  
*Includes negative tests, reverts, and direct storage injections*

## 🔒 Planned Enhancements

- **Stablecoin Support:**  
  Upgrade contract to support ERC20 tokens such as USDC or DAI alongside native ETH.
  - Use OpenZeppelin's `IERC20` interface
  - Add a constructor flag to choose between ETH and token mode
  - Validate allowances and call `transferFrom` in token mode
  - Rework refund and release logic to call `transfer` to buyer/seller
  - Update tests for both ETH and token workflows

- **Milestone or Partial Payments:**  
  Break escrow into multiple releasable milestones for service contracts.

- **Multi-sig or Oracle Integration:**  
  Require third-party approval for fund release or timeout extension.

## 🚀 Quick Start

```bash
forge install
forge build
forge test -vvvv
forge coverage
```

## 📁 Structure

```
src/
  BasicEscrow.sol         # Main escrow contract
test/
  BasicEscrowTest.t.sol   # Comprehensive unit tests
```

## 👤 Author

Adam Flick — [@mrflick](https://github.com/awflick)  
Part of a series of smart contract warm-up projects building toward advanced Web3 tools and smart automation bots.

## 📜 License

MIT — free to use, remix, or expand.
