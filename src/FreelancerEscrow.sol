// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FreelancerEscrow is ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum Status { Active, Completed, Disputed, Cancelled, Refunded }

    struct Milestone {
        uint256 amount;
        bool released;
        string description;
    }

    struct Escrow {
        address client;
        address freelancer;
        address token;
        uint256 totalAmount;
        uint256 deadline;
        Status status;
        address arbitrator;
        Milestone[] milestones;
        uint256 releasedAmount;
    }

    mapping(bytes32 => Escrow) public escrows;
    mapping(address => bytes32[]) public clientEscrows;
    mapping(address => bytes32[]) public freelancerEscrows;

    uint256 public platformFee = 25; // 0.25%
    uint256 public constant FEE_DENOMINATOR = 10000;
    address public feeCollector;

    event EscrowCreated(
        bytes32 indexed escrowId,
        address indexed client,
        address indexed freelancer,
        uint256 amount
    );
    event MilestoneReleased(bytes32 indexed escrowId, uint256 milestoneIndex, uint256 amount);
    event EscrowCompleted(bytes32 indexed escrowId);
    event DisputeRaised(bytes32 indexed escrowId);
    event DisputeResolved(bytes32 indexed escrowId, uint256 clientAmount, uint256 freelancerAmount);
    event EscrowCancelled(bytes32 indexed escrowId);

    constructor(address _feeCollector) {
        feeCollector = _feeCollector;
    }

    function createEscrow(
        address freelancer,
        address token,
        uint256 totalAmount,
        uint256 deadline,
        address arbitrator,
        uint256[] memory milestoneAmounts,
        string[] memory milestoneDescriptions
    ) external payable nonReentrant returns (bytes32) {
        require(freelancer != address(0), "Invalid freelancer");
        require(totalAmount > 0, "Amount must be > 0");
        require(deadline > block.timestamp, "Invalid deadline");
        require(milestoneAmounts.length == milestoneDescriptions.length, "Milestone mismatch");

        uint256 sum = 0;
        for (uint256 i = 0; i < milestoneAmounts.length; i++) {
            sum += milestoneAmounts[i];
        }
        require(sum == totalAmount, "Milestones must sum to total");

        bytes32 escrowId = keccak256(
            abi.encodePacked(msg.sender, freelancer, block.timestamp)
        );

        Escrow storage escrow = escrows[escrowId];
        escrow.client = msg.sender;
        escrow.freelancer = freelancer;
        escrow.token = token;
        escrow.totalAmount = totalAmount;
        escrow.deadline = deadline;
        escrow.status = Status.Active;
        escrow.arbitrator = arbitrator;

        for (uint256 i = 0; i < milestoneAmounts.length; i++) {
            escrow.milestones.push(Milestone({
                amount: milestoneAmounts[i],
                released: false,
                description: milestoneDescriptions[i]
            }));
        }

        if (token == address(0)) {
            require(msg.value == totalAmount, "Incorrect ETH amount");
        } else {
            IERC20(token).safeTransferFrom(msg.sender, address(this), totalAmount);
        }

        clientEscrows[msg.sender].push(escrowId);
        freelancerEscrows[freelancer].push(escrowId);

        emit EscrowCreated(escrowId, msg.sender, freelancer, totalAmount);
        return escrowId;
    }

    function releaseMilestone(bytes32 escrowId, uint256 milestoneIndex) external nonReentrant {
        Escrow storage escrow = escrows[escrowId];
        require(escrow.client == msg.sender, "Not client");
        require(escrow.status == Status.Active, "Escrow not active");
        require(milestoneIndex < escrow.milestones.length, "Invalid milestone");
        require(!escrow.milestones[milestoneIndex].released, "Already released");

        escrow.milestones[milestoneIndex].released = true;
        uint256 amount = escrow.milestones[milestoneIndex].amount;
        uint256 fee = (amount * platformFee) / FEE_DENOMINATOR;
        uint256 freelancerAmount = amount - fee;

        escrow.releasedAmount += amount;

        if (escrow.token == address(0)) {
            (bool success1, ) = escrow.freelancer.call{value: freelancerAmount}("");
            (bool success2, ) = feeCollector.call{value: fee}("");
            require(success1 && success2, "Transfer failed");
        } else {
            IERC20(escrow.token).safeTransfer(escrow.freelancer, freelancerAmount);
            IERC20(escrow.token).safeTransfer(feeCollector, fee);
        }

        emit MilestoneReleased(escrowId, milestoneIndex, amount);

        if (escrow.releasedAmount == escrow.totalAmount) {
            escrow.status = Status.Completed;
            emit EscrowCompleted(escrowId);
        }
    }

    function raiseDispute(bytes32 escrowId) external {
        Escrow storage escrow = escrows[escrowId];
        require(
            escrow.client == msg.sender || escrow.freelancer == msg.sender,
            "Not authorized"
        );
        require(escrow.status == Status.Active, "Escrow not active");
        escrow.status = Status.Disputed;
        emit DisputeRaised(escrowId);
    }

    function resolveDispute(
        bytes32 escrowId,
        uint256 clientAmount,
        uint256 freelancerAmount
    ) external nonReentrant {
        Escrow storage escrow = escrows[escrowId];
        require(escrow.arbitrator == msg.sender, "Not arbitrator");
        require(escrow.status == Status.Disputed, "Not disputed");
        
        uint256 remaining = escrow.totalAmount - escrow.releasedAmount;
        require(clientAmount + freelancerAmount == remaining, "Invalid amounts");

        escrow.status = Status.Completed;

        if (escrow.token == address(0)) {
            if (clientAmount > 0) {
                (bool success, ) = escrow.client.call{value: clientAmount}("");
                require(success, "Client transfer failed");
            }
            if (freelancerAmount > 0) {
                uint256 fee = (freelancerAmount * platformFee) / FEE_DENOMINATOR;
                (bool success1, ) = escrow.freelancer.call{value: freelancerAmount - fee}("");
                (bool success2, ) = feeCollector.call{value: fee}("");
                require(success1 && success2, "Transfer failed");
            }
        } else {
            if (clientAmount > 0) {
                IERC20(escrow.token).safeTransfer(escrow.client, clientAmount);
            }
            if (freelancerAmount > 0) {
                uint256 fee = (freelancerAmount * platformFee) / FEE_DENOMINATOR;
                IERC20(escrow.token).safeTransfer(escrow.freelancer, freelancerAmount - fee);
                IERC20(escrow.token).safeTransfer(feeCollector, fee);
            }
        }

        emit DisputeResolved(escrowId, clientAmount, freelancerAmount);
    }

    function cancelEscrow(bytes32 escrowId) external nonReentrant {
        Escrow storage escrow = escrows[escrowId];
        require(escrow.client == msg.sender, "Not client");
        require(escrow.status == Status.Active, "Escrow not active");
        require(escrow.releasedAmount == 0, "Milestones already released");
        require(block.timestamp < escrow.deadline, "Deadline passed");

        escrow.status = Status.Cancelled;

        if (escrow.token == address(0)) {
            (bool success, ) = escrow.client.call{value: escrow.totalAmount}("");
            require(success, "Refund failed");
        } else {
            IERC20(escrow.token).safeTransfer(escrow.client, escrow.totalAmount);
        }

        emit EscrowCancelled(escrowId);
    }

    function getEscrow(bytes32 escrowId) external view returns (
        address client,
        address freelancer,
        address token,
        uint256 totalAmount,
        uint256 releasedAmount,
        Status status,
        uint256 deadline
    ) {
        Escrow storage escrow = escrows[escrowId];
        return (
            escrow.client,
            escrow.freelancer,
            escrow.token,
            escrow.totalAmount,
            escrow.releasedAmount,
            escrow.status,
            escrow.deadline
        );
    }

    function getMilestones(bytes32 escrowId) external view returns (Milestone[] memory) {
        return escrows[escrowId].milestones;
    }
}