// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

import "./PriceFeed.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';


abstract contract WETHinterface {
    function deposit() public virtual payable;
    function withdraw(uint wad) public virtual;
}


contract BoxProtocol is ERC1155, ERC1155Supply, PriceFeed {

    event Buy(uint boxId, uint buyAmount, uint boxTokenReceived);
    event Sell(uint boxId, uint sellAmount, uint amountReceived);

    ISwapRouter public immutable swapRouter;
    WETHinterface wethtoken;

    uint24 public constant poolFee = 3000;
    uint8 constant DECIMAL = 2;
    address owner;

    struct Token {
        string name;
        uint8 percentage;
    }

    mapping(uint256 => Token[]) boxDistribution;
    mapping(uint256 => mapping(address => uint256)) public boxBalance;
    mapping(string => address) tokenAddress;
    

    uint256 boxNumber;

// createBox param [["ETH",50],["WETH",20],["UNI",30]]
// createBox param [["WETH",20],["UNI",80]]
// createBox param [["ETH",20],["WETH",80]]

    modifier checkBoxID(uint boxId) {
      require(boxId < boxNumber, "Invalid BoxID parameter.");
      _;
   }

   modifier onlyOwner {
      require(msg.sender == owner, "Owner access only");
      _;
   }

    constructor() ERC1155(" ") PriceFeed(0x368A8C0a75fD707e4f7bF15DD1aA25ED554fE22c)   {
        owner = msg.sender;
        swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

        addToken("UNI", 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);
        addToken("WETH", 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);
        addToken("ETH", address(0));

        wethtoken = WETHinterface(tokenAddress["WETH"]);
    }

    function addToken(string memory _tokenSymbol, address _tokenAddress) public onlyOwner {
        tokenAddress[_tokenSymbol] = _tokenAddress;
    }

    function buy(uint boxId) external payable checkBoxID(boxId) returns(uint256 boxTokenMinted){
        require(msg.value > 0, "msg.value is 0");

        uint256 tokenMintAmount = _getBoxTokenMintAmount(boxId, msg.value);

        uint256 tokensInBox = getNumberOfTokensInBox(boxId);
        for(uint i = 0 ; i < tokensInBox ; i++){
            Token memory token = boxDistribution[boxId][i];

            if(keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('ETH'))){
                uint ethAmount = msg.value * token.percentage / 100;
                boxBalance[boxId][tokenAddress[token.name]] += ethAmount;
            }
            else if(keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('WETH'))){
                uint tokenAmount = msg.value * token.percentage / 100;
                wethtoken.deposit{value: tokenAmount}();
                boxBalance[boxId][tokenAddress[token.name]] += tokenAmount;
            }
            else{
                uint swapAmount = msg.value * token.percentage / 100;
                wethtoken.deposit{value: swapAmount}();
                uint tokenAmount = _swapTokens(swapAmount, tokenAddress["WETH"], tokenAddress[token.name]);
                boxBalance[boxId][tokenAddress[token.name]] += tokenAmount;
            }
        }
        _mint(msg.sender, boxId, tokenMintAmount, "");
        emit Buy(boxId, msg.value, tokenMintAmount);
        return(tokenMintAmount);
    }

    function sell(uint boxId, uint256 tokenSellAmount) external checkBoxID(boxId) returns(uint) {

        uint256 tokenTokenSupply = totalSupply(boxId);
        uint256 sellRatio = tokenSellAmount * 100 * 1000 / tokenTokenSupply;

        uint256 tokensInBox = getNumberOfTokensInBox(boxId);
        uint256 amount;
        for(uint i = 0 ; i < tokensInBox ; i++){
            Token memory token = boxDistribution[boxId][i];
            if(keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('ETH'))){
                uint ethAmount = boxBalance[boxId][tokenAddress[token.name]];
                uint sellAmount = ethAmount * sellRatio / (100 * 1000);
                boxBalance[boxId][tokenAddress[token.name]] -= sellAmount;
                amount += sellAmount;
            }
            else if(keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('WETH'))){
                uint wethAmount = boxBalance[boxId][tokenAddress[token.name]];
                uint sellAmount = wethAmount * sellRatio / (100 * 1000);
                boxBalance[boxId][tokenAddress[token.name]] -= sellAmount;
                wethtoken.withdraw(sellAmount);
                amount += sellAmount;
            }
            else{
                uint tokenAmount = boxBalance[boxId][tokenAddress[token.name]];
                uint sellAmount = tokenAmount * sellRatio / (100 * 1000);
                boxBalance[boxId][tokenAddress[token.name]] -= sellAmount;
                uint wethAmount = _swapTokens(sellAmount, tokenAddress[token.name], tokenAddress["WETH"]);
                wethtoken.withdraw(wethAmount);
                amount += wethAmount;
            }
        }

        _burn(msg.sender, boxId, tokenSellAmount);
        (bool sent,) = msg.sender.call{value : amount}("");
        require(sent);
        emit Sell(boxId, tokenSellAmount, amount);
        return(amount);
    }
    

    function createBox(Token[] memory tokens) external onlyOwner returns(uint boxId){
        uint l = tokens.length;
        Token memory token;

        for(uint i = 0; i<l ; i++ ){
            if(keccak256(abi.encodePacked(tokens[i].name)) != keccak256(abi.encodePacked('ETH'))){
            require(tokenAddress[tokens[i].name] != address(0), "Token not box compatible.");
            }
            token.name = tokens[i].name;
            token.percentage = tokens[i].percentage;
            boxDistribution[boxNumber].push(token);
        }
        boxNumber++;
        return(boxNumber - 1);
    }
    

    function getNumberOfTokensInBox(uint boxId) public view checkBoxID(boxId) returns(uint){
        return(boxDistribution[boxId].length);
    }

    function getBoxDistribution(uint boxId, uint tokenNumber) public view checkBoxID(boxId) returns(Token memory){
        return (boxDistribution[boxId][tokenNumber]);
    }

    function getBoxTVL(uint boxId) public view checkBoxID(boxId) returns(uint) {
        uint tokensInBox = getNumberOfTokensInBox(boxId);
        uint totalValueLocked;
        for(uint i = 0 ; i < tokensInBox ; i++){
            Token memory token = boxDistribution[boxId][i];

            if((keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('ETH'))) || (keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('WETH')))){
                uint ethAmount = boxBalance[boxId][tokenAddress[token.name]];
                int256 ethPrice = getETHprice(); //Change required!!!!!!!!!!
                uint valueInUSD = ethAmount* uint(ethPrice)/(10**18);
                totalValueLocked += valueInUSD;

            }
            else {
                uint tokenAmount = boxBalance[boxId][tokenAddress[token.name]];
                int256 tokenPrice = getUNIprice(); //Change required!!!!!!!!!!
                uint valueInUSD = tokenAmount* uint(tokenPrice)/(10**18);
                totalValueLocked += valueInUSD;
            }
        }
        return totalValueLocked;
    }

    function getBoxTokenPrice(uint boxId) public view checkBoxID(boxId) returns(uint)  {
        uint totalValueLocked = getBoxTVL(boxId);
        uint tokenSupply = totalSupply(boxId);
        if(tokenSupply == 0){
            return(10**18);
        }else{
            return(totalValueLocked * (10**DECIMAL) / tokenSupply);
        }
    }

    function _getBoxTokenMintAmount(uint boxId, uint amountInETH) internal view checkBoxID(boxId) returns(uint) {
        int256 ethPrice = getETHprice(); //Change required!!!!!!!!!!
        uint amountInUSD = amountInETH * uint(ethPrice)/(10**18);
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
