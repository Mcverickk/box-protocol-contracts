// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Box is ERC1155 {

    struct Token {
        string name;
        uint256 percentage;
    }

    mapping(uint256 => Token[]) boxDistribution;
    mapping(uint256 => string) boxIdtoBoxName;

    uint256 boxNumber;

    constructor() ERC1155(" ") {
        boxNumber = 0;
    }

    function buy() external {
    }

    function sell() external {
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

    function getBoxTokenPrice() public view {
    }

    function _swapTokens() internal {
    }

    function _mintBoxToken() internal {  
    }

    function _burnBoxToken() internal {       
    }
    
    function _getBoxTokenMintAmount() internal view {
    }
    
}
