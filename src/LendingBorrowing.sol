// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

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
    IERC20 public stablecoin;
    IERC721 public nft;
    uint256 public loanCounter;
    mapping(uint256 => Loan) public loans;
    mapping(uint256 => uint256) public nftCollateral;

    event LoanRequested(uint256 loanId, address borrower, uint256 amount, uint256 interestRate, uint256 duration);
    event LoanRepaid(uint256 loanId);
    event NFTCollateralized(uint256 loanId, uint256 tokenId);
    event NFTReleased(uint256 loanId, uint256 tokenId);

    constructor(address _stablecoin, address _nft) Ownable(address(this)) {
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
        nftCollateral[_loanId] = _tokenId;

        emit NFTCollateralized(_loanId, _tokenId);
    }

    function repayLoan(uint256 _loanId) external nonReentrant {
        Loan storage loan = loans[_loanId];
        require(loan.borrower == msg.sender, "Not the borrower");
        require(!loan.repaid, "Loan already repaid");
        require(block.timestamp <= loan.startTime + loan.duration, "Loan duration exceeded");

        uint256 totalRepayment = loan.amount + (loan.amount * loan.interestRate / 100);
        stablecoin.transferFrom(msg.sender, address(this), totalRepayment);

        loan.repaid = true;
        uint256 tokenId = nftCollateral[_loanId];
        delete nftCollateral[_loanId];

        nft.safeTransferFrom(address(this), msg.sender, tokenId);
        emit LoanRepaid(_loanId);
        emit NFTReleased(_loanId, tokenId);
    }

    function getLoanDetails(uint256 _loanId)
        external
        view
        returns (
            address borrower,
            uint256 amount,
            uint256 interestRate,
            uint256 duration,
            uint256 startTime,
            bool repaid
        )
    {
        return (
            loans[_loanId].borrower,
            loans[_loanId].amount,
            loans[_loanId].interestRate,
            loans[_loanId].duration,
            loans[_loanId].startTime,
            loans[_loanId].repaid
        );
    }
}
