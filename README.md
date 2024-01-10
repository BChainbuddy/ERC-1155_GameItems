# AvatarItems Smart Contract

## Overview

`AvatarItems` is an Ethereum-based smart contract developed using the Hardhat framework. It implements the ERC1155 token standard for creating and managing semi-fungible tokens for avatar customization. The contract leverages Chainlink's Verifiable Random Function (VRF) for unbiased randomness in item distribution.

## Features

- ERC1155 implementation for semi-fungible avatar items.
- Chainlink VRF integration for random item distribution.
- Functions for item creation, purchase, and management.
- Power-up features with custom effects and durations.

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/)
- [Hardhat](https://hardhat.org/getting-started/)
- Solidity 0.8.19
- OpenZeppelin and Chainlink contracts

### Installation

1. Clone the repository:
   ```sh
   git clone [repository-url]
   ```
2. Install NPM packages:
   ```sh
   npm install
   ```
3. Compile the smart contract:
   ```sh
   npx hardhat compile
   ```

### Testing

Run tests to validate the contract's functionalities:

```sh
npx hardhat test
```

### Deployment

Deploy the contract to a network (e.g., Ethereum mainnet, Rinkeby testnet):

```sh
npx hardhat deploy --network [network-name]
```

## Usage

- **Create Items**: Use `addAvatarItem` to introduce new avatar customization items.
- **Purchase Packs**: Users can buy item packs using `buyPack`.
- **Open Packs**: On opening a pack, `packOpened` event provides details of the acquired item.
- **Power-Ups**: Implement and manage power-ups with specific attributes.

## Events

- `packBought`: Emitted when a pack is bought.
- `packOpened`: Emitted when a pack is opened, indicating the item received.
- `itemAdded`: Indicates the addition of a new item.
- `earnedReward`: Triggered upon distributing rewards.
- `powerUpMinted`: Emitted when a power-up is minted.

## Contribution

We welcome contributions from the community. If you'd like to contribute, please follow these guidelines:

1. Fork the repository.
2. Create a branch: `git checkout -b feature/your-feature-name`.
3. Commit your changes: `git commit -am 'Add some feature'`.
4. Push to the branch: `git push origin feature/your-feature-name`.
5. Submit a pull request.

Please make sure to update tests as appropriate and adhere to the code of conduct.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE.md) file for details.
