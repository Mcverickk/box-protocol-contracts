// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

abstract contract WETHinterface {
    function deposit() public virtual payable;
    function withdraw(uint wad) public virtual;
}

contract Box is ERC1155, Ownable {

    ISwapRouter public immutable swapRouter;
    WETHinterface wethtoken = WETHinterface(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

    uint24 public constant poolFee = 3000;

    struct Token {
        string name;
        uint256 percentage;
    }


    mapping(uint256 => Token[]) boxDistribution;
    mapping(uint256 => string) boxIdtoBoxName;
    mapping(uint256 => mapping(address => uint256)) public depositBalance;
    mapping(uint256 => mapping(address => mapping(address=> uint))) public tokensBalance;
    mapping(string => address) tokenAddress;
    

    uint256 boxNumber;

// createBox param [["ETH",50],["WETH",20],["UNI",30]]


    constructor() ERC1155(" ")  {
        boxNumber = 0;
        swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        tokenAddress["UNI"] = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
        tokenAddress["WETH"] = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
        tokenAddress["ETH"] = address(0);
    }

    function buy(uint boxId) external payable{
        // wethtoken.deposit{value: msg.value}();
        depositBalance[boxId][msg.sender] += msg.value;
        uint tokensInBox = getNumberOfTokensInBox(boxId);
        uint amount = msg.value;
        for(uint i = 0 ; i < tokensInBox ; i++){
            Token memory token = boxDistribution[boxId][i];

            if(keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('ETH'))){
                uint ethAmount = amount * token.percentage / 100;
                tokensBalance[boxId][msg.sender][tokenAddress[token.name]] += ethAmount;
            }
            else if(keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('WETH'))){
                uint tokenAmount = amount * token.percentage / 100;
                wethtoken.deposit{value: tokenAmount}();
                tokensBalance[boxId][msg.sender][tokenAddress[token.name]] += tokenAmount;
            }
            else if(keccak256(abi.encodePacked(token.name)) != keccak256(abi.encodePacked('ETH'))){
                uint swapAmount = amount * token.percentage / 100;
                wethtoken.deposit{value: swapAmount}();
                uint tokenAmount = _swapTokens(swapAmount, tokenAddress["WETH"], tokenAddress[token.name]);
                tokensBalance[boxId][msg.sender][tokenAddress[token.name]] += tokenAmount;
            }
        }
    }

    function sell(uint boxId) external {
        // wethtoken.withdraw(amountOut);
        uint tokensInBox = getNumberOfTokensInBox(boxId);
        uint amount;
        for(uint i = 0 ; i < tokensInBox ; i++){
            Token memory token = boxDistribution[boxId][i];

            if(keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('ETH'))){
                uint ethAmount = tokensBalance[boxId][msg.sender][tokenAddress[token.name]];
                tokensBalance[boxId][msg.sender][tokenAddress[token.name]] -= ethAmount;
                amount += ethAmount;

            }
            else if(keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('WETH'))){
                uint wethAmount = tokensBalance[boxId][msg.sender][tokenAddress[token.name]];
                tokensBalance[boxId][msg.sender][tokenAddress[token.name]] -= wethAmount;
                wethtoken.withdraw(wethAmount);
                amount += wethAmount;
            }
            else if(keccak256(abi.encodePacked(token.name)) != keccak256(abi.encodePacked('ETH'))){
                uint tokenAmount = tokensBalance[boxId][msg.sender][tokenAddress[token.name]];
                tokensBalance[boxId][msg.sender][tokenAddress[token.name]] -= tokenAmount;
                uint wethAmount = _swapTokens(tokenAmount, tokenAddress[token.name], tokenAddress["WETH"]);
                wethtoken.withdraw(wethAmount);
                amount += wethAmount;
            }
        }

        (bool sent,) = msg.sender.call{value : amount}("");
        require(sent);
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
