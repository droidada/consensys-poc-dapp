// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LendingBorrowing is ReentrancyGuard, Ownable, ERC721Holder {
    struct Loan {
        address borrower;
        uint256 amount;
        uint256 interestRate;
        uint256 duration;
        uint256 startTime;
        bool repaid;
    }

    // State variables
    IERC20 public immutable stablecoin;
    IERC721 public immutable nft;
    uint256 public loanCounter;
    mapping(uint256 => Loan) public loans;
    mapping(uint256 => address) public nftOwners;

    event LoanRequested(uint256 loanId, address borrower, uint256 amount, uint256 interestRate, uint256 duration);
    event LoanRepaid(uint256 loanId);
    event NFTCollateralized(uint256 loanId, address owner, uint256 tokenId);
    event NFTReleased(uint256 loanId, address owner, uint256 tokenId);

    constructor(address _stablecoin, address _nft) {
        stablecoin = IERC20(_stablecoin);
        nft = IERC721(_nft);
    }

    function requestLoan(uint256 _amount, uint256 _interestRate, uint256 _duration) external nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        require(_interestRate > 0, "Interest rate must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");

        stablecoin.transferFrom(msg.sender, address(this), _amount);

        loanCounter++;
        loans[loanCounter] = Loan({
            borrower: msg.sender,
            amount: _amount,
            interestRate: _interestRate,
            duration: _duration,
            startTime: block.timestamp,
            repaid: false
        });

        emit LoanRequested(loanCounter, msg.sender, _amount, _interestRate, _duration);
    }

    function collateralizeNFT(uint256 _loanId, uint256 _tokenId) external nonReentrant {
        Loan storage loan = loans[_loanId];
        require(loan.borrower == msg.sender, "Not the borrower");
        require(!loan.repaid, "Loan already repaid");

        nft.safeTransferFrom(msg.sender, address(this), _tokenId);

        nftOwners[_loanId] = msg.sender;
        emit NFTCollateralized(_loanId, msg.sender, _tokenId);
    }

    function repayLoan(uint256 _loanId) external nonReentrant {
        Loan storage loan = loans[_loanId];
        require(loan.borrower == msg.sender, "Not the borrower");
        require(!loan.repaid, "Loan already repaid");
        require(block.timestamp <= loan.startTime + loan.duration, "Loan duration exceeded");

        uint256 totalRepayment = loan.amount + (loan.amount * loan.interestRate / 100);
        stablecoin.transferFrom(msg.sender, address(this), totalRepayment);

        loan.repaid = true;
        uint256 tokenId = nftOwners[_loanId];
        delete nftOwners[_loanId];

        nft.safeTransferFrom(address(this), msg.sender, tokenId);
        emit LoanRepaid(_loanId);
        emit NFTReleased(_loanId, msg.sender, tokenId);
    }

    function getLoanDetails(uint256 _loanId) external view returns (Loan memory) {
        return loans[_loanId];
    }
}
