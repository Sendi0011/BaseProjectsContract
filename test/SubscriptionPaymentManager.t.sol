// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SubscriptionPaymentManager} from "../src/SubscriptionPaymentManager.sol";
import {MyToken} from "../src/MyToken.sol";

contract SubscriptionPaymentManagerTest is Test {
    SubscriptionPaymentManager public manager;
    address public owner;
    address public subscriber;
    address public merchant;
    MyToken public myToken;
    bytes32 public subId;

    function setUp() public {
        owner = address(this);
        subscriber = makeAddr("subscriber");
        merchant = makeAddr("merchant");
        myToken = new MyToken();

        manager = new SubscriptionPaymentManager();

        vm.deal(subscriber, 10 ether); // Fund subscriber with ETH
        myToken.transfer(subscriber, 1000 * 10 ** myToken.decimals()); // Fund subscriber with tokens
    }

    function test_CreateSubscription_ETH() public {
        uint256 amount = 1 ether;
        uint256 interval = 30 days;
        uint256 duration = 365 days;
        
        vm.prank(subscriber);
        subId = manager.createSubscription(merchant, address(0), amount, interval, duration);

        SubscriptionPaymentManager.Subscription memory sub = manager.getSubscription(subId);

        assertEq(sub.subscriber, subscriber);
        assertEq(sub.token, address(0));
        assertEq(sub.amount, amount);
        assertEq(sub.interval, interval);
        assertTrue(sub.active);
    }
    
    function test_CreateSubscription_ERC20() public {
        uint256 amount = 100 ether;
        uint256 interval = 30 days;
        uint256 duration = 365 days;
        
        vm.prank(subscriber);
        subId = manager.createSubscription(merchant, address(myToken), amount, interval, duration);
        
        SubscriptionPaymentManager.Subscription memory sub = manager.getSubscription(subId);

        assertEq(sub.subscriber, subscriber);
        assertEq(sub.token, address(myToken));
        assertEq(sub.amount, amount);
        assertTrue(sub.active);
    }

    function test_ProcessPayment_ETH() public {
        test_CreateSubscription_ETH(); // Creates subId

        vm.deal(address(manager), 1 ether); // Simulate subscriber sending ETH to manager
        vm.warp(block.timestamp + 31 days); // Move time forward

        uint256 initialMerchantBalance = merchant.balance;

        manager.processPayment(subId, merchant);

        assertEq(merchant.balance, initialMerchantBalance + 1 ether);

        SubscriptionPaymentManager.Subscription memory sub = manager.getSubscription(subId);
        assertEq(sub.lastPayment, block.timestamp);
    }

    function test_ProcessPayment_ERC20() public {
        test_CreateSubscription_ERC20(); // Creates subId

        vm.prank(subscriber);
        myToken.approve(address(manager), 100 ether); // Approve manager to spend tokens
        
        vm.warp(block.timestamp + 31 days); // Move time forward

        uint256 initialMerchantTokenBalance = myToken.balanceOf(merchant);
        
        manager.processPayment(subId, merchant);

        assertEq(myToken.balanceOf(merchant), initialMerchantTokenBalance + 100 ether);
    }

    function test_CancelSubscription() public {
        test_CreateSubscription_ETH();

        vm.prank(subscriber);
        manager.cancelSubscription(subId);

        SubscriptionPaymentManager.Subscription memory sub = manager.getSubscription(subId);
        assertFalse(sub.active);
    }

    function test_PauseAndResumeSubscription() public {
        test_CreateSubscription_ETH();

        vm.prank(subscriber);
        manager.pauseSubscription(subId);

        SubscriptionPaymentManager.Subscription memory sub = manager.getSubscription(subId);
        assertFalse(sub.active);

        vm.prank(subscriber);
        manager.resumeSubscription(subId);

        sub = manager.getSubscription(subId);
        assertTrue(sub.active);
    }

    function test_ExtendSubscription() public {
        test_CreateSubscription_ETH();

        SubscriptionPaymentManager.Subscription memory subBefore = manager.getSubscription(subId);
        
        uint256 extension = 60 days;
        vm.prank(subscriber);
        manager.extendSubscription(subId, extension);

        SubscriptionPaymentManager.Subscription memory subAfter = manager.getSubscription(subId);
        assertEq(subAfter.approvedUntil, subBefore.approvedUntil + extension);
    }

    function test_Fail_ProcessPayment_TooEarly() public {
        test_CreateSubscription_ETH();

        vm.deal(address(manager), 1 ether);

        vm.expectRevert("Too early");
        manager.processPayment(subId, merchant);
    }

    function test_Fail_CancelSubscription_NotSubscriber() public {
        test_CreateSubscription_ETH();
        
        vm.prank(owner); // Not subscriber
        vm.expectRevert("Not subscriber");
        manager.cancelSubscription(subId);
    }
}
