// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceFeed {

    /**
     * Returns the latest price.
     */
    function getLatestPrice(address _tokenPriceFeed) public view returns (int) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            _tokenPriceFeed
        );
        // prettier-ignore
        (
            /* uint80 roundID */,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return price;
    }
}
