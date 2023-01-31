# BoxProtocol Smart Contract

## Introduction

This is a smart contract for [BoxProtocol](https://boxprotocol.netlify.app/) - a platform for buying and selling tokenized crypto portfolios. It is an easy, self custodial way to invest in boxes representing the hottest ideas and sectors in Web3!.

## Variables

- `ISwapRouter` : A public, immutable contract reference to the ISwapRouter contract. Used to call the swapTokens function to swap tokens.
- `WETHinterface` : A contract reference to the WETHinterface contract. Used to call the deposit and withdraw functions on the WETH contract.
- `poolFee` : A public constant uint24 that represents the pool fee for Uniswap swaps.
- `DECIMAL` : A public constant uint8 that sets the decimal precision of each of the box tokens.
- `Token` : A struct that represents a token.
  - name : A string that represents the token symbol.
  - percentage : An uint8 that represents the token's percentage in the box.
- `ethPrice` : An uint that stores the ETH price.
- `uniPrice` : An uint that stores the UNI price.
- `boxDistribution` : A mapping that stores token's box distribution for each box.
- `boxBalance` : A mapping that stores the token balance for each box.
- `tokenAddress` : A mapping that maps the token symbol to its corresponding address.
- `boxNumber` : An uint256 that stores the number of boxes created.

## 































0xD956f040A7aA9CEcf4225C0F60221A4a89335d2f

https://goerli.etherscan.io/address/0xD956f040A7aA9CEcf4225C0F60221A4a89335d2f#code
