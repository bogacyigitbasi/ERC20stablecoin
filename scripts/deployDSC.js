// deploy the stablecoin contract first

const hre = require("hardhat")

async function main() {
    const [account1] = await hre.ethers.getSigners()

    // Deploy DSC
    const DecentralizedStablecoin = await hre.ethers.getContractFactory("DecentralizedStablecoin")
    const dsc = await DecentralizedStablecoin.deploy("DecentralizedStablecoin", "DSC", await account1.getAddress())
    await dsc.waitForDeployment()

    console.log("stablecoin address", await dsc.getAddress())

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
