const { ethers, waffle } = require("hardhat");
const { formatBytes32String } = require('ethers').utils;

async function main() {
    [deployer] = await ethers.getSigners();
    console.log('Deployer: ', deployer.address)

    let bal = await waffle.provider.getBalance(deployer.address);
    console.log("ETH Balance of Manager: ", bal);

    const CompoundRegistry = await ethers.getContractFactory("CompoundRegistry");
    compoundRegistry = await CompoundRegistry.deploy();
    await compoundRegistry.deployed();
    console.log("CompoundRegistry deployed to:", compoundRegistry.address);

    const Compound = await ethers.getContractFactory("Compound");
    const compound = await Compound.deploy(compoundRegistry.address);
    await compound.deployed();
    console.log("Compound deployed to:", compound.address);

    const LFGlobalEscrow = await ethers.getContractFactory("LFGlobalEscrow");
    const escrow = await LFGlobalEscrow.deploy(compound.address);
    await escrow.deployed();
    console.log("LFGlobalEscrow deployed to:", escrow.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
});