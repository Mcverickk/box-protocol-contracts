// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

abstract contract WETH9interface {
    function deposit() public virtual payable;
    function withdraw(uint wad) public virtual;
}

contract Box is ERC1155,Ownable {

    ISwapRouter public immutable swapRouter;
    WETH9interface wethtoken = WETH9interface(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

    address public constant UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address public constant WETH9 = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    uint24 public constant poolFee = 3000;


    

    struct Token {
        string name;
        uint256 percentage;
    }

    mapping(uint256 => Token[]) boxDistribution;
    mapping(uint256 => string) boxIdtoBoxName;

    uint256 boxNumber;



    constructor() ERC1155(" ") {
        boxNumber = 0;
        swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    }

    function buy() external {
        // wethtoken.deposit{value: msg.value}();
    }

    function sell() external {
        // wethtoken.withdraw(amountOut);
    }
    

    function createBox(string memory boxName, Token[] memory tokens) external onlyOwner returns(uint boxId){
        boxIdtoBoxName[boxNumber] = boxName;
        uint l = tokens.length;
        Token memory token;

        for(uint i = 0; i<l ; i++ ){
            token.name = tokens[i].name;
            token.percentage = tokens[i].percentage;
            boxDistribution[boxNumber].push(token);
        }
        boxNumber++;
        return(boxNumber - 1);
    }

    function getBoxName(uint boxId) external view returns(string memory) {
        return(boxIdtoBoxName[boxId]);
    }
    

    function getNumberOfTokensInBox(uint boxId) public view returns(uint){
        return(boxDistribution[boxId].length);
    }

    function getBoxDistribution(uint boxId, uint tokenNumber) public view returns(Token memory){
        return (boxDistribution[boxId][tokenNumber]);
    }

    function getBoxTokenPrice() public view {

    }


    function _mintBoxToken() internal {
        
    }

    function _burnBoxToken() internal {
        
    }

    function _getBoxTokenMintAmount() internal view {

    }

    function _swapTokens(uint256 amountIn, address tokenIn, address tokenOut) internal returns (uint256 amountOut) {
        TransferHelper.safeApprove(tokenIn, address(swapRouter), amountIn);

        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        amountOut = swapRouter.exactInputSingle(params);
    }

    receive() external payable{}
    fallback() external payable{}

}
