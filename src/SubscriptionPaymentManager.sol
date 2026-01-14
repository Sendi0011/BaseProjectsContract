// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SubscriptionPaymentManager is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Subscription {
        address subscriber;
        address token;
        uint256 amount;
        uint256 interval;
        uint256 lastPayment;
        uint256 approvedUntil;
        bool active;
    }

    mapping(bytes32 => Subscription) public subscriptions;
    mapping(address => bytes32[]) public userSubscriptions;

    event SubscriptionCreated(
        bytes32 indexed subId,
        address indexed subscriber,
        address indexed merchant,
        address token,
        uint256 amount,
        uint256 interval
    );
    event PaymentProcessed(bytes32 indexed subId, uint256 amount, uint256 timestamp);
    event SubscriptionCancelled(bytes32 indexed subId);
    event SubscriptionPaused(bytes32 indexed subId);
    event SubscriptionResumed(bytes32 indexed subId);

    constructor() Ownable(msg.sender) {}

    function createSubscription(
        address merchant,
        address token,
        uint256 amount,
        uint256 interval,
        uint256 duration
    ) external returns (bytes32) {
        require(merchant != address(0), "Invalid merchant");
        require(amount > 0, "Amount must be > 0");
        require(interval > 0, "Interval must be > 0");

        bytes32 subId = keccak256(
            abi.encodePacked(msg.sender, merchant, token, block.timestamp)
        );

        subscriptions[subId] = Subscription({
            subscriber: msg.sender,
            token: token,
            amount: amount,
            interval: interval,
            lastPayment: block.timestamp,
            approvedUntil: block.timestamp + duration,
            active: true
        });

        userSubscriptions[msg.sender].push(subId);

        emit SubscriptionCreated(subId, msg.sender, merchant, token, amount, interval);
        return subId;
    }

    function processPayment(bytes32 subId, address merchant) external nonReentrant {
        Subscription storage sub = subscriptions[subId];
        require(sub.active, "Subscription not active");
        require(block.timestamp >= sub.lastPayment + sub.interval, "Too early");
        require(block.timestamp <= sub.approvedUntil, "Subscription expired");

        sub.lastPayment = block.timestamp;

        if (sub.token == address(0)) {
            require(address(this).balance >= sub.amount, "Insufficient balance");
            (bool success, ) = merchant.call{value: sub.amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20(sub.token).safeTransferFrom(sub.subscriber, merchant, sub.amount);
        }

        emit PaymentProcessed(subId, sub.amount, block.timestamp);
    }

    function cancelSubscription(bytes32 subId) external {
        Subscription storage sub = subscriptions[subId];
        require(sub.subscriber == msg.sender, "Not subscriber");
        sub.active = false;
        emit SubscriptionCancelled(subId);
    }

    function pauseSubscription(bytes32 subId) external {
        Subscription storage sub = subscriptions[subId];
        require(sub.subscriber == msg.sender, "Not subscriber");
        sub.active = false;
        emit SubscriptionPaused(subId);
    }

    function resumeSubscription(bytes32 subId) external {
        Subscription storage sub = subscriptions[subId];
        require(sub.subscriber == msg.sender, "Not subscriber");
        require(block.timestamp <= sub.approvedUntil, "Subscription expired");
        sub.active = true;
        emit SubscriptionResumed(subId);
    }

    function extendSubscription(bytes32 subId, uint256 additionalTime) external {
        Subscription storage sub = subscriptions[subId];
        require(sub.subscriber == msg.sender, "Not subscriber");
        sub.approvedUntil += additionalTime;
    }

    function getSubscription(bytes32 subId) external view returns (Subscription memory) {
        return subscriptions[subId];
    }

    function getUserSubscriptions(address user) external view returns (bytes32[] memory) {
        return userSubscriptions[user];
    }

    receive() external payable {}
}