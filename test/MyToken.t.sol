// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {MyToken} from "../src/MyToken.sol";
import {Test, console} from "forge-std/Test.sol";

contract MyTokenTest is Test {
    MyToken public myToken;
    address public owner;
    address public user1;
    address public user2;

    uint256 public initialSupply;

    function setUp() public {
        myToken = new MyToken();
        owner = address(this); // The deployer of the contract in a test context
        user1 = vm.makeAddr("user1");
        user2 = vm.makeAddr("user2");
        initialSupply = 1_000_000 * (10 ** myToken.decimals());
    }

    function test_InitialSupplyAndOwnerBalance() public {
        assertEq(myToken.totalSupply(), initialSupply, "Total supply should match initial supply");
        assertEq(myToken.balanceOf(owner), initialSupply, "Owner should have the entire initial supply");
    }

    function test_NameAndSymbol() public {
        assertEq(myToken.name(), "MyToken", "Token name should be 'MyToken'");
        assertEq(myToken.symbol(), "MTK", "Token symbol should be 'MTK'");
    }

    function test_Transfer() public {
        uint256 transferAmount = 1000 * (10 ** myToken.decimals());

        // Transfer from owner to user1
        vm.prank(owner);
        myToken.transfer(user1, transferAmount);

        assertEq(myToken.balanceOf(owner), initialSupply - transferAmount, "Owner balance incorrect after transfer");
        assertEq(myToken.balanceOf(user1), transferAmount, "User1 balance incorrect after transfer");

        // Attempt to transfer more than balance should revert
        vm.prank(user1);
        vm.expectRevert();
        myToken.transfer(user2, transferAmount + 1);
    }

    function test_ApproveAndTransferFrom() public {
        uint256 approveAmount = 500 * (10 ** myToken.decimals());
        uint256 transferFromAmount = 300 * (10 ** myToken.decimals());

        // Owner approves user1 to spend
        vm.prank(owner);
        myToken.approve(user1, approveAmount);

        assertEq(myToken.allowance(owner, user1), approveAmount, "Allowance incorrect after approval");

        // User1 transfers from owner to user2
        vm.prank(user1);
        myToken.transferFrom(owner, user2, transferFromAmount);

        assertEq(myToken.balanceOf(owner), initialSupply - transferFromAmount, "Owner balance incorrect after transferFrom");
        assertEq(myToken.balanceOf(user2), transferFromAmount, "User2 balance incorrect after transferFrom");
        assertEq(myToken.allowance(owner, user1), approveAmount - transferFromAmount, "Allowance incorrect after transferFrom");

        // Attempt to transfer more than allowance should revert
        vm.prank(user1);
        vm.expectRevert();
        myToken.transferFrom(owner, user2, approveAmount - transferFromAmount + 1);
    }

    function test_TransferFromWithoutAllowance() public {
        uint256 transferFromAmount = 100 * (10 ** myToken.decimals());

        // User1 attempts to transfer from owner without allowance
        vm.prank(user1);
        vm.expectRevert();
        myToken.transferFrom(owner, user2, transferFromAmount);
    }
}
