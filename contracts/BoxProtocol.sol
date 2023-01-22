// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

abstract contract WETHinterface {
    function deposit() public virtual payable;
    function withdraw(uint wad) public virtual;
}


contract BoxProtocol is ERC1155, ERC1155Supply {

    ISwapRouter public immutable swapRouter;
    WETHinterface wethtoken = WETHinterface(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

    uint24 public constant poolFee = 3000;
    uint256 DECIMAL = 2;

    struct Token {
        string name;
        uint256 percentage;
    }

    uint ethPrice = 1500;
    uint uniPrice = 600;


    mapping(uint256 => Token[]) boxDistribution;
    mapping(uint256 => string) boxIdtoBoxName;
    mapping(uint256 => mapping(address => uint256)) public depositBalance;
    mapping(uint256 => mapping(address => mapping(address=> uint))) public tokensBalance;
    mapping(uint256 => mapping(address => uint256)) public boxBalance;
    mapping(string => address) tokenAddress;
    

    uint256 boxNumber;

// createBox param [["ETH",50],["WETH",20],["UNI",30]]
// createBox param [["WETH",20],["UNI",80]]
// createBox param [["ETH",20],["WETH",80]]


    constructor() ERC1155(" ")  {
        boxNumber = 0;
        swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        tokenAddress["UNI"] = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
        tokenAddress["WETH"] = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
        tokenAddress["ETH"] = address(0);
    }

    function buy(uint boxId) external payable returns(uint boxTokenMinted){
        uint amount = msg.value;
        depositBalance[boxId][msg.sender] += amount;
        uint tokenMintAmount = _getBoxTokenMintAmount(boxId, amount);

        uint tokensInBox = getNumberOfTokensInBox(boxId);
        for(uint i = 0 ; i < tokensInBox ; i++){
            Token memory token = boxDistribution[boxId][i];

            if(keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('ETH'))){
                uint ethAmount = amount * token.percentage / 100;
                tokensBalance[boxId][msg.sender][tokenAddress[token.name]] += ethAmount;
                boxBalance[boxId][tokenAddress[token.name]] += ethAmount;
            }
            else if(keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('WETH'))){
                uint tokenAmount = amount * token.percentage / 100;
                wethtoken.deposit{value: tokenAmount}();
                tokensBalance[boxId][msg.sender][tokenAddress[token.name]] += tokenAmount;
                boxBalance[boxId][tokenAddress[token.name]] += tokenAmount;
            }
            else if(keccak256(abi.encodePacked(token.name)) != keccak256(abi.encodePacked('ETH'))){
                uint swapAmount = amount * token.percentage / 100;
                wethtoken.deposit{value: swapAmount}();
                uint tokenAmount = _swapTokens(swapAmount, tokenAddress["WETH"], tokenAddress[token.name]);
                tokensBalance[boxId][msg.sender][tokenAddress[token.name]] += tokenAmount;
                boxBalance[boxId][tokenAddress[token.name]] += tokenAmount;
            }
        }
        _mint(msg.sender, boxId, tokenMintAmount, "");
        return(tokenMintAmount);
    }

    function sell(uint boxId, uint tokenSellAmount) external {
        uint userBalance = balanceOf(msg.sender, boxId);
        uint sellRatio = tokenSellAmount * 100 / userBalance;

        uint tokensInBox = getNumberOfTokensInBox(boxId);
        uint amount;
        for(uint i = 0 ; i < tokensInBox ; i++){
            Token memory token = boxDistribution[boxId][i];

            if(keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('ETH'))){
                uint ethAmount = tokensBalance[boxId][msg.sender][tokenAddress[token.name]];
                uint sellAmount = ethAmount * sellRatio / 100;
                tokensBalance[boxId][msg.sender][tokenAddress[token.name]] -= sellAmount;
                boxBalance[boxId][tokenAddress[token.name]] -= sellAmount;
                amount += sellAmount;
            }
            else if(keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('WETH'))){
                uint wethAmount = tokensBalance[boxId][msg.sender][tokenAddress[token.name]];
                uint sellAmount = wethAmount * sellRatio / 100;
                tokensBalance[boxId][msg.sender][tokenAddress[token.name]] -= sellAmount;
                boxBalance[boxId][tokenAddress[token.name]] -= sellAmount;
                wethtoken.withdraw(sellAmount);
                amount += sellAmount;
            }
            else if(keccak256(abi.encodePacked(token.name)) != keccak256(abi.encodePacked('ETH'))){
                uint tokenAmount = tokensBalance[boxId][msg.sender][tokenAddress[token.name]];
                uint sellAmount = tokenAmount * sellRatio / 100;
                tokensBalance[boxId][msg.sender][tokenAddress[token.name]] -= sellAmount;
                boxBalance[boxId][tokenAddress[token.name]] -= sellAmount;
                uint wethAmount = _swapTokens(sellAmount, tokenAddress[token.name], tokenAddress["WETH"]);
                wethtoken.withdraw(wethAmount);
                amount += wethAmount;
            }
        }

        _burn(msg.sender, boxId, tokenSellAmount);
        (bool sent,) = msg.sender.call{value : amount}("");
        require(sent);
    }
    

    function createBox(string memory boxName, Token[] memory tokens) external returns(uint boxId){
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

    function getBoxTVL(uint boxId) public view returns(uint) {
        uint tokensInBox = getNumberOfTokensInBox(boxId);
        uint totalValueLocked;
        for(uint i = 0 ; i < tokensInBox ; i++){
            Token memory token = boxDistribution[boxId][i];

            if((keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('ETH'))) || (keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('WETH')))){
                uint ethAmount = boxBalance[boxId][tokenAddress[token.name]];
                uint valueInUSD = ethAmount* ethPrice;
                totalValueLocked += valueInUSD;

            }
            else if(keccak256(abi.encodePacked(token.name)) != keccak256(abi.encodePacked('ETH'))){
                uint tokenAmount = boxBalance[boxId][tokenAddress[token.name]];
                uint valueInUSD = tokenAmount* uniPrice;
                totalValueLocked += valueInUSD;
            }
        }
        return totalValueLocked;
    }

    function getBoxTokenPrice(uint boxId) public view returns(uint)  {
        uint totalValueLocked = getBoxTVL(boxId);
        uint tokenSupply = totalSupply(boxId);
        if(tokenSupply == 0){
            return(10**18);
        }else{
            return(totalValueLocked * (10**DECIMAL) / tokenSupply);
        }
    }

    function _getBoxTokenMintAmount(uint boxId, uint amountInETH) internal view returns(uint) {
        uint amountInUSD = amountInETH * ethPrice;
        uint boxTokenPrice = getBoxTokenPrice(boxId);
        return(amountInUSD * (10**DECIMAL) / boxTokenPrice);
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

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

}
