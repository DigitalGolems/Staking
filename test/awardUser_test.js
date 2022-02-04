const { assert } = require("chai");
const Digibytes = artifacts.require("Digibytes.sol");
const DigitalGolems = artifacts.require("DigitalGolems.sol");
const Card = artifacts.require("Card.sol")
const StakingDBT = artifacts.require("StakingDBT");

contract('Staking', async (accounts)=>{
    const secondsInADay = 86400;
    let DBT;
    let card;
    let DIG;
    let staking;
    let amountDBT = web3.utils.toWei("5015"); //5000$ in DBT + 15$ in DBT comission 
    let userBalanceAfterAward = web3.utils.toWei("5000"); //user balance after operations
    let user = accounts[9];
    let owner = accounts[0];
    before(async () => {
        DBT = await Digibytes.new()
        DIG = await DigitalGolems.new()
        staking = await StakingDBT.new()
        card = await Card.new()
        await staking.setDBT(DBT.address) //set our digibytes address
        await staking.setDIG(DIG.address) //set our digital golems address
        await DIG.setStakingAddress(staking.address)
        await DIG.setCard(card.address)
        await card.setDIGAddress(DIG.address)
        await DBT.transfer(user, amountDBT, {from: owner}) //transfer to user staker amount
    })
    
    it("Should create order", async () => {
        //approve DBT to staking contract
        await DBT.approve(staking.address, amountDBT, {from: user})
        //create staking order
        await staking.blockTokens({from: user})
        //check if we take commission 0,3%
        assert.equal(
            await staking.getDBTBalance(),
            web3.utils.toWei("15"),
            "Balance + commisson from order"
        )
        //get stakers orders
        let stakerOrders = await staking.fetchStakersOrders(user)
        //check length, should be 1 because we added before
        assert.equal(
            stakerOrders.length,
            1,
            "Really Added"
        )
        //check if really stakers
        assert.equal(
            stakerOrders[0][1].toString(),
            user,
            "Really Staker"
        )
    })

    it("Should mock time and award user", async () => {
        //mock time of order
        //current time - 31 day
        let newTime = (Math.trunc(Date.now()/ 1000) - secondsInADay * 31).toString();
        await staking.mockFarmTime(
            0,              //orderID
            newTime,        //New time
            {from: owner}    //from staker
        )
        //we will sign our transaction with our token uri
        //no one can replace uri with another
        const tokenURI = "https://ipfs.io/ipfs/QmUdTP3VBY5b9u1Bdc3AwKggQMg5TQyNXVfzgcUQKjdmRH";//вот отсюда
        //for valid mint
        //signed from server
        const message = web3.utils.soliditySha3(DIG.address, tokenURI, user);
        const sign = await web3.eth.sign(message, owner)
        const r = sign.substr(0, 66)
        const s = '0x' + sign.substr(66, 64);
        const v = web3.utils.toDecimal("0x" + (sign.substr(130,2) == 0 ? "1b" : "1c"));//до сюда, делается серваком
        const kindSeries = ["1", "7"]
        const rs = [r, s]
        //farming
        await staking.farmDIG(
            0,          //orderID
            tokenURI,   //tokenURI
            v,          //v
            rs,         //rs,
            kindSeries, //kindSeries
            {from: user}//staker
        )
        //get stakers orders
        let stakerOrders = await staking.fetchStakersOrders(user)
        //check if really minted
        assert.isTrue(
            stakerOrders[0][4]
        )
    })

    it("Should check users DBT and DIG balance", async () => {
        //check DBT balance
        assert.equal(
            await DBT.balanceOf(user),
            userBalanceAfterAward,
            "Really 5kDBT"
        )
        //check DIG balance
        assert.equal(
            await DIG.balanceOf(user),
            1,
            "Really add DIG"
        )
        //check card balance
        assert.equal(
            await card.cardCount(user),
            1,
            "Really add card"
        )
    })

    it("Should withdraw DBT by owner", async () => {
        //balance before withdraw
        let balanceOwnerBefore = await DBT.balanceOf(owner)
        //withdraw
        await staking.withdrawDBT()
        //balance after withdraw
        let balanceOwnerAfter = await DBT.balanceOf(owner)
        //check if balance after above that before
        assert.isAbove(
            parseInt(balanceOwnerAfter.toString()),
            parseInt(balanceOwnerBefore.toString()),
            "Really added"
        )
    })

})