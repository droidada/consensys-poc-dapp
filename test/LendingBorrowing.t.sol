// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/LendingBorrowing.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract LendingBorrowingTest is Test {
    LendingBorrowing lendingBorrowing;
    ERC20 stablecoin;
    ERC721 nft;

    address borrower = address(0x1);
    address otherAccount = address(0x2);

    function setUp() public {
        stablecoin = new ERC20("Stablecoin", "STBL");
        nft = new ERC721("NFT", "NFT");
        lendingBorrowing = new LendingBorrowing(address(stablecoin), address(nft));

        stablecoin.mint(borrower, 10000 * 10 ** 18);
        nft.mint(borrower, 1);
    }

    function testRequestLoan() public {
        vm.startPrank(borrower);
        stablecoin.approve(address(lendingBorrowing), 1000 * 10 ** 18);
        lendingBorrowing.requestLoan(1000 * 10 ** 18, 5, 3600);
        vm.stopPrank();

        (address loanBorrower, uint256 amount, uint256 interestRate, uint256 duration, uint256 startTime, bool repaid) = lendingBorrowing.getLoanDetails(1);

        assertEq(loanBorrower, borrower);
        assertEq(amount, 1000 * 10 ** 18);
    }

    function testCollateralizeNFT() public {
        vm.startPrank(borrower);
        stablecoin.approve(address(lendingBorrowing), 1000 * 10 ** 18);
        lendingBorrowing.requestLoan(1000 * 10 ** 18, 5, 3600);

        nft.approve(address(lendingBorrowing), 1);
        lendingBorrowing.collateralizeNFT(1, 1);

        (address nftOwner, ) = lendingBorrowing.nftOwners(1);
        assertEq(nftOwner, borrower);
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
        vm.stopPrank();
    }
}
