require('@openzeppelin/hardhat-upgrades');
require("@nomicfoundation/hardhat-toolbox");
// dotenv.config();
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  networks: {
    localhost: {},
    mumbai: {
      url: process.env.MUMBAI_URLL || "https://rpc-mumbai.maticvigil.com",
      accounts: [process.env.PRIVATE_KEY],
      // url: process.env.RPC_URL,
      // accounts: [process.env.PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN_API_KEY,
  },
};

// require("@nomiclabs/hardhat-ethers");
// require("@openzeppelin/hardhat-upgrades");
// require("@nomiclabs/hardhat-etherscan");
// require('dotenv').config()

// module.exports = {
//   solidity: "0.8.24",
//   networks: {
//     mumbai: {
//       url: process.env.RPC_URL,
//       accounts: [process.env.PRIVATE_KEY],
//     },
//   },
//   etherscan: {
//     apiKey: process.env.ETHERSCAN_API_KEY,
//   }
// };
