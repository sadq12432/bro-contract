# BRO DeFi Smart Contracts

This repository contains DeFi (Decentralized Finance) smart contract code written in Solidity.

## Overview

The contracts in this repository implement various DeFi functionalities including:
- Token management and operations
- Liquidity pool mechanisms
- Mining and reward systems
- Node management and performance tracking

## Contract Structure

### Core Contracts
- **Token.sol**: Main token contract with ERC-20 functionality
- **TokenLP.sol**: Liquidity pool token contract
- **Master.sol**: Master contract for managing mining and rewards
- **CakeV2Swap.sol**: PancakeSwap V2 integration contract

### Libraries and Utilities
- **MiningNodeLib.sol**: Library for node mining operations
- **MiningLPLib.sol**: Library for liquidity pool mining
- **SafeMath.sol**: Safe mathematical operations
- **Counters.sol**: Counter utilities

### Interfaces
- **ICakeV2Swap.sol**: Interface for CakeV2Swap operations
- **IMaster.sol**: Interface for Master contract
- **IMiningLP.sol**: Interface for mining liquidity pool

## Features

- **Token Operations**: Mint, burn, transfer, and approve tokens
- **Liquidity Management**: Add and remove liquidity from pools
- **Mining Rewards**: Distribute rewards to liquidity providers and node operators
- **Node System**: Manage mining nodes with performance tracking
- **Permission Control**: Manage caller permissions and access control

## Deployment

The contracts are designed to be deployed on BSC (Binance Smart Chain) network, supporting both testnet and mainnet environments.

## Security

All contracts implement security best practices including:
- Access control mechanisms
- Safe mathematical operations
- Input validation
- Reentrancy protection

## License

This project is licensed under the MIT License.
