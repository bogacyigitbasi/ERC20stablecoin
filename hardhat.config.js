require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config(); // To manage environment variables

module.exports = {
  solidity: {
    version: "0.8.20", // Ensure this matches the version used in OpenZeppelin contracts
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  remappings: [
    // Example remapping for OpenZeppelin imports
    ["openzeppelin/", "@openzeppelin/contracts/"],
  ],
  networks: {
    localhost:{
      url: "http://127.0.0.1:8545",
    },
    // Example: Add a testnet or mainnet configuration if needed
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "", // Your Sepolia RPC URL
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [], // Private key for deploying
    },
    mainnet: {
      url: process.env.MAINNET_RPC_URL || "", // Your Mainnet RPC URL
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [], // Private key for deploying
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY || "", // API Key for Etherscan verification
  },
};



// require("@nomicfoundation/hardhat-toolbox");
// require("@chainlink/hardhat-chainlink");

// // /** @type import('hardhat/config').HardhatUserConfig */
// // module.exports = {
// //   solidity: "0.8.28",
// //   settings: {
// //     optimizer: {
// //       enabled: true,
// //       runs: 200,
// //     },
// //   }
// // };


// const fs = require('fs');
// const path = require('path');

// // Parse remappings.txt into a usable object
// function getRemappings() {
//   const remappingsPath = path.resolve(__dirname, 'remappings.txt');
//   const remappings = fs.readFileSync(remappingsPath, 'utf-8').trim().split('\n');
//   return remappings.map((line) => {
//     const [alias, target] = line.split('=');
//     return { alias, target };
//   });
// }

// // Apply remappings to sources
// function preprocessSources(content, remappings) {
//   remappings.forEach(({ alias, target }) => {
//     content = content.replace(new RegExp(alias, 'g'), target);
//   });
//   return content;
// }

// module.exports = {
//   solidity: "0.8.28",
//   paths: {
//     sources: "./contracts",
//   },
//   preprocess: {
//     eachLine: (content) => preprocessSources(content, getRemappings()),
//   },
// };
