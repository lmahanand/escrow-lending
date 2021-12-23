/**
 * @type import('hardhat/config').HardhatUserConfig
 */
require("@nomiclabs/hardhat-ganache");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-web3");
module.exports = {
  defaultNetwork: "goerli",
  networks: {
    hardhat: {
    },
    goerli: {
      url: "https://goerli.infura.io/v3/"+process.env.INFURA_ID,
      gas: 6000000,           // Gas sent with each transaction (default: ~6700000)
      gasPrice: 3000000000,  // 3 gwei (in wei) (default: 100 gwei)
      confirmations: 2,
      timeoutBlocks: 200,
      skipDryRun: true,
      accounts: [
                  process.env.PK_MANAGER, 
                  process.env.PK_WALLETUSER
                ]
    }
  },
  solidity: "0.8.0",
};
