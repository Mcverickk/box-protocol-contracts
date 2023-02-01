# BoxProtocol Smart Contract

## Introduction

This is a smart contract for [BoxProtocol](https://boxprotocol.netlify.app/) - a platform for buying and selling tokenized crypto portfolios. It is an easy, self custodial way to invest in boxes representing the hottest ideas and sectors in Web3!.


### Variables

- `ISwapRouter` : A public, immutable contract reference to the ISwapRouter contract. Used to call the swapTokens function to swap tokens.
- `WETHinterface` : A contract reference to the WETHinterface contract. Used to call the deposit and withdraw functions on the WETH contract.
- `boxNumber` : An uint256 that stores the number of boxes created.

## Mappings

- `boxDistribution` : A mapping that stores token's box distribution for each box.
- `boxBalance` : A mapping that stores the token balance for each box.
- `tokenAddress` : A mapping that maps the token symbol to its corresponding address.

## Constants

- `poolFee` : A public constant uint24 that represents the pool fee for Uniswap swaps.
- `DECIMAL` : A public constant uint8 that sets the decimal precision of each of the box tokens.
- `ethPrice` : An uint that stores the ETH price.
- `uniPrice` : An uint that stores the UNI price.

## Structs

- `Token` : A struct that represents a token.
  - name : A string that represents the token symbol.
  - percentage : An uint8 that represents the token's percentage in the box.

## Functions

### buy
    buy(uint boxId) external payable returns(boxTokenMinted boxTokenMinted)

Parameters:
| Name | Type | Description |
|----------|----------|----------|
| boxId | uint256 |  |


Returns:
| Name | Type | Description |
|----------|----------|----------|
| boxTokenMinted | boxTokenMinted |  |


### sell
    sell(uint boxId, uint256 tokenSellAmount) external
Parameters:
| Name | Type | Description |
|----------|----------|----------|
| boxId | uint256 | Row 1, Column 3 |
| tokenSellAmount | uint256 | Row 2, Column 3 |


### createBox
    createBox(Token[] memory tokens) external returns(uint boxId)
Parameters:
| Name | Type | Description |
|----------|----------|----------|
| tokens | Token[] |  |


Returns:
| Name | Type | Description |
|----------|----------|----------|
| boxId | uint |  |


### getNumberOfTokensInBox
    getNumberOfTokensInBox(uint boxId) public view returns(uint)

Parameters:
| Name | Type | Description |
|----------|----------|----------|
| boxId | uint |  |

Returns:
| Type | Description |
|----------|----------|
|  uint |  |


### getBoxDistribution
    getBoxDistribution(uint boxId, uint tokenNumber) public view returns(Token memory)

Parameters:
| Name | Type | Description |
|----------|----------|----------|
| boxId| uint |  |
| tokenNumber| uint |  |

Returns:
| Type | Description |
|----------|----------|
| Token |  |


### getBoxTVL
    getBoxTVL(uint boxId) public view returns(uint)

Parameters:
| Name | Type | Description |
|----------|----------|----------|
| boxId | uint| |


Returns:
| Type | Description |
|----------|----------|
| uint |  |


### getBoxTokenPrice
    getBoxTokenPrice(uint boxId) public view returns(uint)

Parameters:
| Name | Type | Description |
|----------|----------|----------|
| boxId | uint| |


Returns:
| Type | Description |
|----------|----------|
| uint |  |

### _getBoxTokenMintAmount
    _getBoxTokenMintAmount(uint boxId, uint amountInETH) internal view returns(uint)

Parameters:
| Name | Type | Description |
|----------|----------|----------|
| boxId | uint| |
| amountInETH | uint| |

Returns:
| Type | Description |
|----------|----------|
| uint |  |

### _swapTokens
    _swapTokens(uint256 amountIn, address tokenIn, address tokenOut) internal returns (uint256 amountOut)

Parameters:
| Name | Type | Description |
|----------|----------|----------|
| amountIn | uint256| |
| tokenIn | address| |
| tokenOut | address| |

Returns:
| Name | Type | Description |
|----------|----------|----------|
| amountOut| uint256| |

































0xD956f040A7aA9CEcf4225C0F60221A4a89335d2f

https://goerli.etherscan.io/address/0xD956f040A7aA9CEcf4225C0F60221A4a89335d2f#code
