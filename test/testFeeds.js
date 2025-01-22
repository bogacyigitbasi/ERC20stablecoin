// npx hardhat test test/testFeeds.js --network localhost

const { expect } = require("chai");
const { ethers } = require("hardhat");
const {dotenv} = require("dotenv").config()


describe ("Test DSC and Engine", function(){
    let dsc, mockerc20, mockv3Aggregator, dscEngine;
    let account1, account2;
    beforeEach(async() => {

        // deploy DSC
        [account1, account2] = await ethers.getSigners();
        const DecentralizedStablecoin = await hre.ethers.getContractFactory("DecentralizedStablecoin")
        dsc = await DecentralizedStablecoin.deploy("DecentralizedStablecoin", "DSC", await account1.getAddress())
        await dsc.waitForDeployment()

        console.log(await dsc.getAddress())

        // create MockERC20
        const MockERC20 = await hre.ethers.getContractFactory("MockERC20")
        mockerc20 = await MockERC20.deploy("Mock ERC20", "wETH", await account1.getAddress(), BigInt(500000000));
        await mockerc20.waitForDeployment()
        console.log(await mockerc20.getAddress())

        // create mock V3Aggregator
        const MockV3Aggregator = await hre.ethers.getContractFactory("MockV3Aggregator");

        mockv3Aggregator = await MockV3Aggregator.deploy(process.env.DECIMALS,BigInt(process.env.TEST_ETH_USD_PRICE_INITIAL));
        await mockv3Aggregator.waitForDeployment()
        console.log(await mockv3Aggregator.getAddress())


        // create mock V3Aggregator
        const DSCEngine = await hre.ethers.getContractFactory("DSEngine");
        dscEngine = await DSCEngine.deploy(JSON.parse(process.env.COLLATERAL_ADDRESSES), JSON.parse(process.env.PRICE_FEED_ADDRESSES),dsc.getAddress());
        await dscEngine.waitForDeployment()
        console.log(await dscEngine.getAddress())

        const transaction = await dsc.connect(account1).transferOwnership(dscEngine.getAddress())
        await transaction.wait()
    })

    it ("check contract owner for dsc", async () => {
        expect (await dsc.owner()).to.equal(await dscEngine.getAddress())
    })
})