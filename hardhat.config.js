require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy");
require("dotenv").config(); // ⬅️ Load env variables

module.exports = {
  solidity: "0.8.28",
  networks: {
    baseSepolia: {
      url: "https://sepolia.base.org", // Base Sepolia RPC
      chainId: 84532,
      accounts: [process.env.PRIVATE_KEY].filter(Boolean), // ⬅️ Use env var safely
      saveDeployments: true,
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
};
