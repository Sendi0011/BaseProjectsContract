// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract RevenueSplitter is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Beneficiary {
        address account;
        uint256 shares;
        bool active;
    }

    Beneficiary[] public beneficiaries;
    mapping(address => uint256) public beneficiaryIndex;
    mapping(address => bool) public isBeneficiary;
    
    uint256 public totalShares;
    
    mapping(address => uint256) public totalReceived;
    mapping(address => uint256) public totalDistributed;
    mapping(address => mapping(address => uint256)) public beneficiaryReceived;

    event BeneficiaryAdded(address indexed account, uint256 shares);
    event BeneficiaryRemoved(address indexed account);
    event SharesUpdated(address indexed account, uint256 oldShares, uint256 newShares);
    event PaymentReceived(address indexed token, uint256 amount);
    event PaymentDistributed(address indexed token, address indexed beneficiary, uint256 amount);

    constructor(address[] memory accounts, uint256[] memory shares_) Ownable(msg.sender) {
        require(accounts.length == shares_.length, "Length mismatch");
        require(accounts.length > 0, "No beneficiaries");

        for (uint256 i = 0; i < accounts.length; i++) {
            _addBeneficiary(accounts[i], shares_[i]);
        }
    }

    function addBeneficiary(address account, uint256 shares_) external onlyOwner {
        _addBeneficiary(account, shares_);
    }

    function _addBeneficiary(address account, uint256 shares_) private {
        require(account != address(0), "Invalid address");
        require(shares_ > 0, "Shares must be > 0");
        require(!isBeneficiary[account], "Already beneficiary");

        beneficiaries.push(Beneficiary({
            account: account,
            shares: shares_,
            active: true
        }));
        
        beneficiaryIndex[account] = beneficiaries.length - 1;
        isBeneficiary[account] = true;
        totalShares += shares_;

        emit BeneficiaryAdded(account, shares_);
    }

    function removeBeneficiary(address account) external onlyOwner {
        require(isBeneficiary[account], "Not a beneficiary");
        
        uint256 index = beneficiaryIndex[account];
        Beneficiary storage ben = beneficiaries[index];
        
        totalShares -= ben.shares;
        ben.active = false;
        isBeneficiary[account] = false;

        emit BeneficiaryRemoved(account);
    }

    function updateShares(address account, uint256 newShares) external onlyOwner {
        require(isBeneficiary[account], "Not a beneficiary");
        require(newShares > 0, "Shares must be > 0");
        
        uint256 index = beneficiaryIndex[account];
        Beneficiary storage ben = beneficiaries[index];
        
        uint256 oldShares = ben.shares;
        totalShares = totalShares - oldShares + newShares;
        ben.shares = newShares;

        emit SharesUpdated(account, oldShares, newShares);
    }

    function distributeETH() public nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to distribute");

        totalReceived[address(0)] += balance;

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            if (beneficiaries[i].active) {
                uint256 payment = (balance * beneficiaries[i].shares) / totalShares;
                
                beneficiaryReceived[beneficiaries[i].account][address(0)] += payment;
                totalDistributed[address(0)] += payment;

                (bool success, ) = beneficiaries[i].account.call{value: payment}("");
                require(success, "ETH transfer failed");

                emit PaymentDistributed(address(0), beneficiaries[i].account, payment);
            }
        }
    }

    function distributeToken(address token) public nonReentrant {
        require(token != address(0), "Use distributeETH for ETH");
        
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to distribute");

        totalReceived[token] += balance;

        for (uint256 i = 0; i < beneficiaries.length; i++) {
            if (beneficiaries[i].active) {
                uint256 payment = (balance * beneficiaries[i].shares) / totalShares;
                
                beneficiaryReceived[beneficiaries[i].account][token] += payment;
                totalDistributed[token] += payment;

                IERC20(token).safeTransfer(beneficiaries[i].account, payment);

                emit PaymentDistributed(token, beneficiaries[i].account, payment);
            }
        }
    }

    function distributeMultipleTokens(address[] calldata tokens) external {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) {
                distributeETH();
            } else {
                distributeToken(tokens[i]);
            }
        }
    }

    function getBeneficiaries() external view returns (Beneficiary[] memory) {
        return beneficiaries;
    }

    function getActiveBeneficiaries() external view returns (address[] memory, uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            if (beneficiaries[i].active) count++;
        }

        address[] memory accounts = new address[](count);
        uint256[] memory shares_ = new uint256[](count);
        
        uint256 j = 0;
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            if (beneficiaries[i].active) {
                accounts[j] = beneficiaries[i].account;
                shares_[j] = beneficiaries[i].shares;
                j++;
            }
        }

        return (accounts, shares_);
    }

    function getBeneficiaryInfo(address account) external view returns (
        uint256 shares_,
        bool active,
        uint256 ethReceived,
        uint256 tokenReceived,
        address token
    ) {
        require(isBeneficiary[account], "Not a beneficiary");
        uint256 index = beneficiaryIndex[account];
        Beneficiary memory ben = beneficiaries[index];
        
        return (
            ben.shares,
            ben.active,
            beneficiaryReceived[account][address(0)],
            0,
            address(0)
        );
    }

    receive() external payable {
        emit PaymentReceived(address(0), msg.value);
        distributeETH();
    }
}