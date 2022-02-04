// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;
pragma solidity 0.8.10;

import "./GetPrice.sol";
import "../Digibytes/Digibytes.sol";
import "../DigitalGolems/DigitalGolems.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../Utils/SafeMath.sol";


contract StakingDBT is GetPrice {
    using SafeMath for uint256;

    struct Order {
        uint256 orderID;
        address staker;
        uint256 deposit;
        uint256 timeWhenEnded;
        bool minted;
    }

    Order[] orders;

    uint256 oneDIGPrice;
    uint256 thisDBTBalance;
    
    Digibytes public DBT;
    DigitalGolems public DIG;

    mapping (address => uint256) userOrderCount;

    constructor () {
        priceFeed = AggregatorV3Interface(0x1a602D4928faF0A153A520f58B332f9CAFF320f7);
        oneDIGPrice = 5000;
    }

    function setDBT(address _DBT) public isOwner {
        DBT = Digibytes(_DBT);
    }

    function setDIG(address _DIG) public isOwner {
        DIG = DigitalGolems(_DIG);
    }

    function blockTokens() external {
        //take latest price in usd of our token
        //our price for one nft multiply by 10 to the power of token decimals
        //then divide it on token price in USD
        //so we will get price in our token
        uint256 oneDIGPriceInDBT = (oneDIGPrice * 10 ** getDecimalsTest()) / uint256(getLatestPriceTest());
        //price multiply by 10 to the power of token decimals
        uint256 totalAmountInDBT = oneDIGPriceInDBT * 10 ** getDecimalsTest();
        //counting comission
        uint256 comission = totalAmountInDBT * 3 / 1000; //0,3% 
        //checking if user have amount for staking in dbt and commision
        require(DBT.balanceOf(msg.sender) >= totalAmountInDBT + comission, "Not enough DBT");
        //check if we can use this money
        require(DBT.allowance(msg.sender, address(this)) >= totalAmountInDBT + comission, "Not enough allowance DBT");
        //transfer to this address
        DBT.transferFrom(msg.sender, address(this), totalAmountInDBT + comission);
        //creating order for staking
        orders.push(
            Order(
                orders.length,              //orderID
                msg.sender,                 //staker
                totalAmountInDBT,           //DBT amount
                block.timestamp + 30 days,  //Time when can mint
                false                       //Minted
            )
        );
        //+1 order to user
        userOrderCount[msg.sender] = userOrderCount[msg.sender].add(1);
        //take comission to this address
        thisDBTBalance = thisDBTBalance.add(comission);
    }

    //fetching stakers orders
    function fetchStakersOrders(address staker) public view returns(Order[] memory) {
        //array with length of user's orders
        Order[] memory userOrders = new Order[](userOrderCount[staker]);
        for (uint256 i = 0; i < orders.length; i++) {
            //if staker of order is who we ask, take this order
            if (orders[i].staker == staker) {
                userOrders[i] = orders[i];
            }
        }
        return userOrders;
    }

    //withdraw DBT before mint
    //we take fine in 20% of order deposit
    function aheadOfTime(uint256 orderID) public {
        //only staker of this order
        require(orders[orderID].staker == msg.sender, "You not staker");
        //if time already ended he cant withdraw with fine 
        //it's from unnecessary calls
        require(block.timestamp < orders[orderID].timeWhenEnded, "Time already ended");
        //users order -1
        userOrderCount[msg.sender] = userOrderCount[msg.sender].sub(1);
        //take fine 20%
        uint256 minus20Percent = orders[orderID].deposit - (orders[orderID].deposit * 20 / 100);
        //add to this balance
        thisDBTBalance = thisDBTBalance.add(orders[orderID].deposit * 20 / 100);
        //order equal 0
        orders[orderID].staker = address(0);
        orders[orderID].deposit = 0;
        orders[orderID].timeWhenEnded = 0;
        orders[orderID].minted = false;
        //transfer 80% DBT to staker
        DBT.transfer(msg.sender, minus20Percent);
    }

    function farmDIG(
        uint256 orderID,
        string memory tokenURI, 
        uint8 v,
        bytes32[] memory rs,
        uint8[] memory kindSeries
    ) external isTimeToFarmEnded(orderID) {
        require(msg.sender == orders[orderID].staker, "You not staker");
        DIG.awardItem(msg.sender, tokenURI, v, rs, kindSeries);
        DBT.transfer(msg.sender, orders[orderID].deposit);
        orders[orderID].deposit = 0;
        orders[orderID].timeWhenEnded = 0;
        orders[orderID].minted = true;
    }

    function mockFarmTime(uint256 orderID, uint256 _newTime) public isOwner {
        orders[orderID].timeWhenEnded = _newTime;
    }

    modifier isTimeToFarmEnded(uint256 _orderID) {
        require(block.timestamp > orders[_orderID].timeWhenEnded, "Its still farming");
        _;
    }

    function withdrawDBT() public isOwner {
        DBT.transfer(msg.sender, thisDBTBalance);
    }

    function getDBTBalance() public view isOwner returns(uint256) {
        return thisDBTBalance;
    }
}