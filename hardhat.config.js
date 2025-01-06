require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
const path = require("path");

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      // Include the node_modules path explicitly
      includePaths: [path.resolve(__dirname, "./node_modules")],
    },
  },
};
