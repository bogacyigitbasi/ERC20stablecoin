const { expect } = require("chai");
const { ethers } = require("hardhat");
const {dotenv} = require("dotenv").config()


describe ("Test DSC and Engine", function(){
    let dsc;
    let account1, account2;
    beforeEach(async() => {

        // deploy DSC

        [account1, account2] = await ethers.getSigners();
        const DecentralizedStablecoin = await hre.ethers.getContractFactory("DecentralizedStablecoin")
        const dsc = await DecentralizedStablecoin.deploy("DecentralizedStablecoin", "DSC", await account1.getAddress())
        await dsc.waitForDeployment()

        console.log(await dsc.getAddress())

        // create MockERC20
        const MockERC20 = await hre.ethers.getContractFactory("DecentralizedStablecoin")
        const mockerc20 = await MockERC20.deploy("Mock ERC20", "wETH", await account1.getAddress(), 5e18);
        await mockerc20.waitForDeployment()
        console.log(await mockerc20.getAddress())

        // create mock V3Aggregator
        const MockV3Aggregator = await hre.ethers.getContractFactory("Mockv3Aggregator");
        const mockv3Aggragator = await MockV3Aggregator.deploy(process.env.DECIMALS, process.env.TEST_ETH_USD_PRICE_INITIAL);
        await mockv3Aggragator.waitForDeployment()
        console.log(await mockv3Aggragator.getAddress())
    })
})