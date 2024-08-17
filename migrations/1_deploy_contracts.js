const LendingBorrowing = artifacts.require("LendingBorrowing");
const ERC20Mock = artifacts.require("ERC20Mock");
const ERC721Mock = artifacts.require("ERC721Mock");

module.exports = async function (deployer) {
    await deployer.deploy(ERC20Mock, "Stablecoin", "STBL", web3.utils.toWei("1000000", "ether"));
    const stablecoin = await ERC20Mock.deployed();

    await deployer.deploy(ERC721Mock, "NFT", "NFT");
    const nft = await ERC721Mock.deployed();

    await deployer.deploy(LendingBorrowing, stablecoin.address, nft.address);
};
