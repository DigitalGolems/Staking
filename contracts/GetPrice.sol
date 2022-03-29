// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;
pragma solidity 0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../Utils/Owner.sol";

contract GetPrice is Owner {

    AggregatorV3Interface internal priceFeed;

    //0x1a602D4928faF0A153A520f58B332f9CAFF320f7 BTC/ETH
    function setPriceFeed(address _priceFeed) public isOwner {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice() public view returns (int) {
        (
            uint80 roundID,
            int price,
            uint startedAt,
            uint timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        return price;
    }

    function getLatestPriceTest() public pure returns(uint256) {
        return 1 * 10**18; //means DBT/USD = 1$
    }

    function getDecimalsTest() public pure returns(uint8) {
        return 18;
    }

}
