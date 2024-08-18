// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "lib/forge-std/src/Test.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "../src/LendingBorrowing.sol";

contract ERC20Mock is ERC20 {
    constructor(string memory name, string memory symbol) ERC20("", "") {}

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}

contract ERC721Mock is ERC721 {
    constructor(string memory name, string memory symbol) ERC721("", "") {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }
}

contract LendingBorrowingTest is Test {
    LendingBorrowing lendingBorrowing;
    ERC20Mock stablecoin;
    ERC721Mock nft;

    address borrower = address(0x1);
    address otherAccount = address(0x2);

    function setUp() public {
        stablecoin = new ERC20Mock("Stablecoin", "STBL");
        nft = new ERC721Mock("NFT", "NFT");
        lendingBorrowing = new LendingBorrowing(address(stablecoin), address(nft));

        stablecoin.mint(borrower, 10000 * 10 ** 18);
        nft.mint(borrower, 1);
    }

    function testRequestLoan() public {
        vm.startPrank(borrower);
        stablecoin.approve(address(lendingBorrowing), 1000 * 10 ** 18);
        lendingBorrowing.requestLoan(1000 * 10 ** 18, 5, 3600);
        vm.stopPrank();

        (address loanBorrower, uint256 amount, uint256 interestRate, uint256 duration, uint256 startTime, bool repaid) =
            lendingBorrowing.getLoanDetails(1);

        assertEq(loanBorrower, borrower);
        assertEq(amount, 1000 * 10 ** 18);
        assertEq(interestRate, 5);
        assertEq(duration, 3600);
        assertFalse(repaid);
    }

    function testCollateralizeNFT() public {
        vm.startPrank(borrower);
        stablecoin.approve(address(lendingBorrowing), 1000 * 10 ** 18);
        lendingBorrowing.requestLoan(1000 * 10 ** 18, 5, 3600);

        nft.approve(address(lendingBorrowing), 1);
        lendingBorrowing.collateralizeNFT(1, 1);

        uint256 tokenId = lendingBorrowing.nftCollateral(1);
        assertEq(tokenId, 1);
        vm.stopPrank();
    }

    function testRepayLoan() public {
        vm.startPrank(borrower);
        stablecoin.approve(address(lendingBorrowing), 1000 * 10 ** 18);
        lendingBorrowing.requestLoan(1000 * 10 ** 18, 5, 3600);

        nft.approve(address(lendingBorrowing), 1);
        lendingBorrowing.collateralizeNFT(1, 1);

        stablecoin.approve(address(lendingBorrowing), 1050 * 10 ** 18);
        lendingBorrowing.repayLoan(1);

        address ownerOfNFT = nft.ownerOf(1);
        assertEq(ownerOfNFT, borrower);

        (address loanBorrower, uint256 amount, uint256 interestRate, uint256 duration, uint256 startTime, bool repaid) =
            lendingBorrowing.getLoanDetails(1);
        assertTrue(repaid);
        vm.stopPrank();
    }

    function testFailRepayLoanAfterDuration() public {
        vm.startPrank(borrower);
        stablecoin.approve(address(lendingBorrowing), 1000 * 10 ** 18);
        lendingBorrowing.requestLoan(1000 * 10 ** 18, 5, 3600);

        nft.approve(address(lendingBorrowing), 1);
        lendingBorrowing.collateralizeNFT(1, 1);

        // Simulate time passing
        vm.warp(block.timestamp + 3601); // move forward by 3601 seconds

        stablecoin.approve(address(lendingBorrowing), 1050 * 10 ** 18);
        vm.expectRevert("Loan duration exceeded");
        lendingBorrowing.repayLoan(1);
        vm.stopPrank();
        vm.expectRevert();
    }
}
