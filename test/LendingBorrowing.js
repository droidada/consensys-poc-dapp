const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LendingBorrowing Contract", function () {
    let LendingBorrowing;
    let lendingBorrowing;
    let stablecoin;
    let nft;
    let owner;
    let borrower;
    let otherAccount;
    let loanId;

    beforeEach(async function () {
        [owner, borrower, otherAccount] = await ethers.getSigners();

        // Deploy Stablecoin (ERC20)
        const Stablecoin = await ethers.getContractFactory("ERC20Mock");
        stablecoin = await Stablecoin.deploy("Stablecoin", "STBL", ethers.utils.parseUnits("1000000", 18));
        await stablecoin.deployed();

        // Deploy NFT (ERC721)
        const NFT = await ethers.getContractFactory("ERC721Mock");
        nft = await NFT.deploy("NFT", "NFT");
        await nft.deployed();

        // Mint NFT to borrower
        await nft.mint(borrower.address, 1);

        // Deploy LendingBorrowing contract
        LendingBorrowing = await ethers.getContractFactory("LendingBorrowing");
        lendingBorrowing = await LendingBorrowing.deploy(stablecoin.address, nft.address);
        await lendingBorrowing.deployed();

        // Transfer stablecoins to borrower
        await stablecoin.transfer(borrower.address, ethers.utils.parseUnits("10000", 18));
    });

    it("Should request a loan successfully", async function () {
        await stablecoin.connect(borrower).approve(lendingBorrowing.address, ethers.utils.parseUnits("1000", 18));
        await lendingBorrowing.connect(borrower).requestLoan(ethers.utils.parseUnits("1000", 18), 5, 3600);
        const loan = await lendingBorrowing.getLoanDetails(1);

        expect(loan.borrower).to.equal(borrower.address);
        expect(loan.amount).to.equal(ethers.utils.parseUnits("1000", 18));
    });

    it("Should collateralize NFT and repay loan successfully", async function () {
        // Request loan
        await stablecoin.connect(borrower).approve(lendingBorrowing.address, ethers.utils.parseUnits("1000", 18));
        await lendingBorrowing.connect(borrower).requestLoan(ethers.utils.parseUnits("1000", 18), 5, 3600);

        // Collateralize NFT
        await nft.connect(borrower).approve(lendingBorrowing.address, 1);
        await lendingBorrowing.connect(borrower).collateralizeNFT(1, 1);

        // Repay loan
        await stablecoin.connect(borrower).approve(lendingBorrowing.address, ethers.utils.parseUnits("1050", 18)); // amount + interest
        await lendingBorrowing.connect(borrower).repayLoan(1);

        // Verify NFT is returned
        const ownerOfNFT = await nft.ownerOf(1);
        expect(ownerOfNFT).to.equal(borrower.address);
    });
});
