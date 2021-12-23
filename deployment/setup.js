const { ethers, waffle } = require("hardhat");

const CETH = '0x4ddc2d193948926d02f9b1fe9e1daa0718270ed5';
const COMPOUND_REGISTRY = '0x6F48C09d171F1526Bf88fA718bbe87e307e03EaF';
const ETH_TOKEN_ADDRESS = '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e';

async function main() {
    [deployer] = await ethers.getSigners();
    console.log('Deployer: ', deployer.address)

    let bal = await waffle.provider.getBalance(deployer.address);
    console.log("ETH Balance of Manager: ", bal);

    const CompoundRegistry = await ethers.getContractFactory("CompoundRegistry", COMPOUND_REGISTRY);
    const compoundRegistry = CompoundRegistry.attach(COMPOUND_REGISTRY);
    let owner = await compoundRegistry.owner();
    console.log('owner: ', owner);

    const tx = await compoundRegistry.connect(deployer).addCToken(ETH_TOKEN_ADDRESS, CETH);
    let txReceipt = await tx.wait();
    let cTokenAddedEvent = txReceipt.events.filter(event => event.event)[0].event
    console.log('cETH token added with event as: ', cTokenAddedEvent)
    let cETH = await compoundRegistry.getCToken(ETH_TOKEN_ADDRESS);
    console.log('cETH: ',cETH)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});