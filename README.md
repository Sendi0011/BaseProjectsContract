# BaseProjectsContract

This repository contains a collection of smart contracts for various decentralized applications, built using the Foundry framework.

## Overview

This project serves as a foundational set of smart contracts that can be used or extended for different on-chain purposes. The contracts included are:

-   **MyToken**: An ERC20 token with a fixed supply.
-   **DecentralizedReputation**: A system for managing user reputations on-chain.
-   **FreelancerEscrow**: An escrow contract to facilitate trustless payments between freelancers and clients.
-   **RevenueSplitter**: A contract to split incoming Ether or ERC20 tokens among a group of beneficiaries.
-   **SubscriptionPaymentManager**: A contract to manage recurring subscription payments.

## Getting Started

### Prerequisites

-   [Foundry](https://getfoundry.sh/): A blazing fast, portable and modular toolkit for Ethereum application development written in Rust.

### Installation

1.  Clone the repository:
    ```shell
    git clone https://github.com/your-username/BaseProjectsContract.git
    cd BaseProjectsContract
    ```

2.  Install dependencies:
    ```shell
    forge install
    ```

### Building the Contracts

To compile the smart contracts, run:

```shell
forge build
```

### Running Tests

To run the test suite for all contracts, use the following command:

```shell
forge test
```

## Contracts

### `MyToken.sol`

A standard ERC20 token contract named "MyToken" with the symbol "MTK". It mints a fixed supply of 1,000,000 tokens to the deployer's address upon creation.

### `DecentralizedReputation.sol`

This contract allows for the creation of a simple on-chain reputation system. Users can be given positive or negative reputation scores, which are publicly recorded.

### `FreelancerEscrow.sol`

This contract acts as a neutral third party for transactions between a freelancer and a client. The client deposits funds into the escrow, and the funds are released to the freelancer upon completion of the work.

### `RevenueSplitter.sol`

A contract that allows for the equitable distribution of funds (Ether or ERC20 tokens) among a predefined group of payees. Each payee is assigned a share, and they can pull their portion of the revenue at any time.

### `SubscriptionPaymentManager.sol`

This contract facilitates recurring payments for subscription-based services. Users can subscribe to a service, and the contract manages the payment schedule and distribution.

## Deployment

To deploy a contract, you can use a script in the `script/` directory. For example, to deploy the `MyToken` contract, you would first need to create a `MyToken.s.sol` script, and then run:

```shell
forge script script/MyToken.s.sol:MyTokenScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```