// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma abicoder v2;

import "./PriceFeed.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';


abstract contract WMATICinterface {
    function deposit() public virtual payable;
    function withdraw(uint wad) public virtual;
}


contract BoxProtocol is ERC1155, ERC1155Supply, PriceFeed {

    event Buy(uint boxId, uint buyAmount, uint boxTokenReceived);
    event Sell(uint boxId, uint sellAmount, uint amountReceived);

    ISwapRouter public immutable swapRouter;
    WMATICinterface wmatictoken;

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
    mapping(string => address) tokenPriceFeed;
    address MATICPriceFeed;
    

    uint256 boxNumber;

// createBox param [["MATIC",50],["WMATIC",20],["UNI",30]]
// createBox param [["WMATIC",20],["UNI",80]]
// createBox param [["MATIC",20],["WMATIC",80]]
//addToken("WMATIC", 0x9c3C9283D3e44854697Cd22D3Faa240Cfb032889, MATICPriceFeed);

    modifier checkBoxID(uint boxId) {
      require(boxId < boxNumber, "Invalid BoxID parameter.");
      _;
   }

   modifier onlyOwner {
      require(msg.sender == owner, "Owner access only");
      _;
   }

    constructor() ERC1155(" ") PriceFeed()   {
        owner = msg.sender;
        swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        MATICPriceFeed = 0xAB594600376Ec9fD91F8e885dADF0CE036862dE0;

        addToken("MATIC", address(0), MATICPriceFeed);
        addToken("WMATIC", 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270, MATICPriceFeed);

        wmatictoken = WMATICinterface(tokenAddress["WMATIC"]);
    }

    function addToken(string memory _tokenSymbol, address _tokenAddress, address _tokenPriceFeed) public onlyOwner {
        tokenAddress[_tokenSymbol] = _tokenAddress;
        tokenPriceFeed[_tokenSymbol] = _tokenPriceFeed;
    }

    function buy(uint boxId) external payable checkBoxID(boxId) returns(uint256 boxTokenMinted){
        require(msg.value > 0, "msg.value is 0");

        uint256 tokenMintAmount = _getBoxTokenMintAmount(boxId, msg.value);

        uint256 tokensInBox = getNumberOfTokensInBox(boxId);
        for(uint i = 0 ; i < tokensInBox ; i++){
            Token memory token = boxDistribution[boxId][i];

            if(keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('MATIC'))){
                uint maticAmount = msg.value * token.percentage / 100;
                boxBalance[boxId][tokenAddress[token.name]] += maticAmount;
            }
            else if(keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('WMATIC'))){
                uint tokenAmount = msg.value * token.percentage / 100;
                wmatictoken.deposit{value: tokenAmount}();
                boxBalance[boxId][tokenAddress[token.name]] += tokenAmount;
            }
            else{
                uint swapAmount = msg.value * token.percentage / 100;
                wmatictoken.deposit{value: swapAmount}();
                uint tokenAmount = _swapTokens(swapAmount, tokenAddress["WMATIC"], tokenAddress[token.name]);
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
            if(keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('MATIC'))){
                uint maticAmount = boxBalance[boxId][tokenAddress[token.name]];
                uint sellAmount = maticAmount * sellRatio / (100 * 1000);
                boxBalance[boxId][tokenAddress[token.name]] -= sellAmount;
                amount += sellAmount;
            }
            else if(keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('WMATIC'))){
                uint wmaticAmount = boxBalance[boxId][tokenAddress[token.name]];
                uint sellAmount = wmaticAmount * sellRatio / (100 * 1000);
                boxBalance[boxId][tokenAddress[token.name]] -= sellAmount;
                wmatictoken.withdraw(sellAmount);
                amount += sellAmount;
            }
            else{
                uint tokenAmount = boxBalance[boxId][tokenAddress[token.name]];
                uint sellAmount = tokenAmount * sellRatio / (100 * 1000);
                boxBalance[boxId][tokenAddress[token.name]] -= sellAmount;
                uint wmaticAmount = _swapTokens(sellAmount, tokenAddress[token.name], tokenAddress["WMATIC"]);
                wmatictoken.withdraw(wmaticAmount);
                amount += wmaticAmount;
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
            if(keccak256(abi.encodePacked(tokens[i].name)) != keccak256(abi.encodePacked('MATIC'))){
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

            if((keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('MATIC'))) || (keccak256(abi.encodePacked(token.name)) == keccak256(abi.encodePacked('WMATIC')))){
                uint maticAmount = boxBalance[boxId][tokenAddress[token.name]];
                int256 maticPrice = getLatestPrice(MATICPriceFeed);
                uint valueInUSD = maticAmount* uint(maticPrice)/(10**8);
                totalValueLocked += valueInUSD;

            }
            else {
                uint tokenAmount = boxBalance[boxId][tokenAddress[token.name]];
                int256 tokenPrice = getLatestPrice(tokenPriceFeed[token.name]);
                uint valueInUSD = tokenAmount* uint(tokenPrice)/(10**8);
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

    function _getBoxTokenMintAmount(uint boxId, uint amountInMATIC) internal view checkBoxID(boxId) returns(uint) {
        int256 maticPrice = getLatestPrice(MATICPriceFeed);
        uint amountInUSD = amountInMATIC * uint(maticPrice)/(10**8);
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
