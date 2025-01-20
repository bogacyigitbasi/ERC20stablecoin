require("@nomicfoundation/hardhat-toolbox");
require("@chainlink/hardhat-chainlink");

// /** @type import('hardhat/config').HardhatUserConfig */
// module.exports = {
//   solidity: "0.8.28",
//   settings: {
//     optimizer: {
//       enabled: true,
//       runs: 200,
//     },
//   }
// };


const fs = require('fs');
const path = require('path');

// Parse remappings.txt into a usable object
function getRemappings() {
  const remappingsPath = path.resolve(__dirname, 'remappings.txt');
  const remappings = fs.readFileSync(remappingsPath, 'utf-8').trim().split('\n');
  return remappings.map((line) => {
    const [alias, target] = line.split('=');
    return { alias, target };
  });
}

// Apply remappings to sources
function preprocessSources(content, remappings) {
  remappings.forEach(({ alias, target }) => {
    content = content.replace(new RegExp(alias, 'g'), target);
  });
  return content;
}

module.exports = {
  solidity: "0.8.28",
  paths: {
    sources: "./contracts",
  },
  preprocess: {
    eachLine: (content) => preprocessSources(content, getRemappings()),
  },
};
