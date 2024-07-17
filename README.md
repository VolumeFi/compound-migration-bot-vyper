# Compound Migration Bot Vyper contract

This smart contract system is to let users move Compound asset tokens just like cUSDC and cETH between Ethereum and Base/Arbitrum chain. This uses Native USDC bridge to move assets.


## Test and dependencies

Install Foundry, Apeworx.

```ape plugins install foundry infura vyper```

```ape test --network ethereum:mainnet:foundry```



## Read-Only functions

### compass

| Key        | Type    | Description                                |
| ---------- | ------- | ------------------------------------------ |
| **Return** | address | Returns compass-evm smart contract address |

### refund_wallet

| Key        | Type    | Description                   |
| ---------- | ------- | ----------------------------- |
| **Return** | address | Returns refund wallet address |

### gas_fee

| Key        | Type    | Description                                         |
| ---------- | ------- | --------------------------------------------------- |
| **Return** | uint256 | Returns gas fee amount to pay to use paloma message |

### service_fee_collector

| Key        | Type    | Description                           |
| ---------- | ------- | ------------------------------------- |
| **Return** | address | Returns service fee collector address |

### service_fee

| Key        | Type    | Description                                     |
| ---------- | ------- | ----------------------------------------------- |
| **Return** | uint256 | Returns service fee ratio. 100% equals 10 ** 18 |

### paloma

| Key        | Type    | Description                         |
| ---------- | ------- | ----------------------------------- |
| **Return** | bytes32 | Public key of Paloma message sender |

### last_nonce

| Key        | Type    | Description                          |
| ---------- | ------- | ------------------------------------ |
| **Return** | uint256 | nonce number of sending transactions |

## State-Changing functions

### send_to_bridge_usdc

Send USDC token to USDC native bridge to migrate cUSDC

| Key                | Type    | Description                                                                                             |
| ------------------ | ------- | ------------------------------------------------------------------------------------------------------- |
| amount             | uint256 | Bridging token amount. If this is 0, the contract tries to bridge entire amount the message sender has. |
| destination_domain | uint32  | Destination chain domain number in USDC native bridge                                                   |
| mint_recipient     | bytes32 | Recipient address. This should be the Migration bot contract on opposite chain                          |
| burn_token         | address | Burn token address parameter for USDC native bridge                                                     |

### receive_from_bridge_usdc

Receive USDC token to migrate cUSDC using native USDC bridge. Paloma messenger can run this function via Compass-EVM only.

| Key       | Type    | Description                                                       |
| --------- | ------- | ----------------------------------------------------------------- |
| message   | bytes   | USDC bridge message data                                          |
| signature | bytes   | USDC bridge signature data                                        |
| receiver  | address | Receiver address. It should be same as the token migrator address |

### send_to_bridge_other

Send USDC token to USDC native bridge to migrate cTokens

| Key                | Type    | Description                                                                                             |
| ------------------ | ------- | ------------------------------------------------------------------------------------------------------- |
| ctoken             | address | cToken address to migrate                                                                               |
| amount             | uint256 | Bridging token amount. If this is 0, the contract tries to bridge entire amount the message sender has. |
| dex                | address | dex address to exchange asset into USDC                                                                 |
| payload            | bytes   | payload data to exchange asset into USDC                                                                |
| destination_domain | uint32  | Destination chain domain number in USDC native bridge                                                   |
| mint_recipient     | bytes32 | Recipient address. This should be the Migration bot contract on opposite chain                          |
| burn_token         | address | Burn token address parameter for USDC native bridge                                                     |

### receive_from_bridge_other

Receive USDC token to migrate cUSDC using native USDC bridge. Paloma messenger can run this function via Compass-EVM only.

| Key       | Type    | Description                                                       |
| --------- | ------- | ----------------------------------------------------------------- |
| message   | bytes   | USDC bridge message data                                          |
| signature | bytes   | USDC bridge signature data                                        |
| receiver  | address | Receiver address. It should be same as the token migrator address |
| ctoken    | address | cToken address to be migrated                                     |
| dex       | address | dex address to exchange USDC into asset                           |
| payload   | bytes   | payload data to exchange USDC into asset                          |
