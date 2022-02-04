const { assert } = require("chai");
const Digibytes = artifacts.require("Digibytes.sol");
const StakingDBT = artifacts.require("StakingDBT");

contract('Staking', async (accounts)=>{
    let DBT;
    let staking;
    let amountDBT = web3.utils.toWei("5015"); //5000$ in DBT + 15$ in DBT comission 
    let commissonForAheadOfTimePlusBefore = web3.utils.toWei("1015"); //contract balance = 20% fine for ahead of time + 15$ that we get before
    let userBalanceAfterAheadOfTime = web3.utils.toWei("4000"); //user balance after operations
    let user = accounts[9];
    let owner = accounts[0];
    before(async () => {
        DBT = await Digibytes.new()
        staking = await StakingDBT.new()
        await staking.setDBT(DBT.address) //set our digibytes address
        await DBT.transfer(user, amountDBT, {from: owner}) //transfer to user staker amount
    })
    
    it("Should get 20% from deposit", async () => {
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
        //staker withdraw ahead of time
        await staking.aheadOfTime(
            "0",//orderID
            {from: user}
        )
        //user balance should be: balanceBefore = balanceBefore  - balanceBefore%0,3 - deposit%20
        assert.equal(
            await DBT.balanceOf(user),
            userBalanceAfterAheadOfTime,
            "Really -20%"
        )
        //staking contract balance should be: 20% fine for ahead of time + 15$ in DBT that we get before
        assert.equal(
            await staking.getDBTBalance(),
            commissonForAheadOfTimePlusBefore,
            "Really +20%"
        )
    })

})