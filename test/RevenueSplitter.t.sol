// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {RevenueSplitter} from "../src/RevenueSplitter.sol";
import {MyToken} from "../src/MyToken.sol";

contract RevenueSplitterTest is Test {
    RevenueSplitter public splitter;
    address public owner;
    address public beneficiary1;
    address public beneficiary2;
    address public beneficiary3;
    MyToken public myToken1;
    MyToken public myToken2;

    function setUp() public {
        owner = address(this); // test contract is the owner of MyToken
        beneficiary1 = makeAddr("beneficiary1");
        beneficiary2 = makeAddr("beneficiary2");
        beneficiary3 = makeAddr("beneficiary3");

        address[] memory initialBeneficiaries = new address[](2);
        initialBeneficiaries[0] = beneficiary1;
        initialBeneficiaries[1] = beneficiary2;

        uint256[] memory initialShares = new uint256[](2);
        initialShares[0] = 50;
        initialShares[1] = 50;

        splitter = new RevenueSplitter(initialBeneficiaries, initialShares);

        myToken1 = new MyToken();
        myToken2 = new MyToken();

        vm.deal(address(splitter), 10 ether); // Fund splitter with ETH
        
        // Fund splitter with tokens
        myToken1.transfer(address(splitter), 500 * 10 ** myToken1.decimals());
        myToken2.transfer(address(splitter), 250 * 10 ** myToken2.decimals());
    }

    function test_AddBeneficiary() public {
        splitter.addBeneficiary(beneficiary3, 100);

        assertTrue(splitter.isBeneficiary(beneficiary3));
        assertEq(splitter.beneficiaries(2).account, beneficiary3); // Check index 2 as 0 and 1 are already taken
        assertEq(splitter.beneficiaries(2).shares, 100);
        assertEq(splitter.totalShares(), 200); // 50+50+100
    }

    function test_RemoveBeneficiary() public {
        splitter.removeBeneficiary(beneficiary1);

        assertFalse(splitter.isBeneficiary(beneficiary1));
        assertFalse(splitter.beneficiaries(0).active);
        assertEq(splitter.totalShares(), 50); // Only beneficiary2's shares remain active
    }

    function test_UpdateShares() public {
        splitter.updateShares(beneficiary1, 100);

        assertEq(splitter.beneficiaries(0).shares, 100);
        assertEq(splitter.totalShares(), 150); // 100 (new) + 50 (old)
    }

    function test_DistributeETH() public {
        uint256 initialBeneficiary1Balance = beneficiary1.balance;
        uint256 initialBeneficiary2Balance = beneficiary2.balance;

        splitter.distributeETH();

        // 10 ether in splitter, 50/50 split
        assertApproxEqAbs(beneficiary1.balance, initialBeneficiary1Balance + 5 ether, 1e18);
        assertApproxEqAbs(beneficiary2.balance, initialBeneficiary2Balance + 5 ether, 1e18);
    }

    function test_DistributeToken() public {
        uint256 initialBeneficiary1Token1Balance = myToken1.balanceOf(beneficiary1);
        uint256 initialBeneficiary2Token1Balance = myToken1.balanceOf(beneficiary2);

        splitter.distributeToken(address(myToken1));

        // 500 ether of myToken1 in splitter, 50/50 split
        assertEq(myToken1.balanceOf(beneficiary1), initialBeneficiary1Token1Balance + 250 * 10 ** myToken1.decimals());
        assertEq(myToken1.balanceOf(beneficiary2), initialBeneficiary2Token1Balance + 250 * 10 ** myToken1.decimals());
    }

    function test_DistributeMultipleTokens() public {
        uint256 initialBeneficiary1ETHBalance = beneficiary1.balance;
        uint256 initialBeneficiary2ETHBalance = beneficiary2.balance;
        uint256 initialBeneficiary1Token1Balance = myToken1.balanceOf(beneficiary1);
        uint256 initialBeneficiary2Token1Balance = myToken1.balanceOf(beneficiary2);
        uint256 initialBeneficiary1Token2Balance = myToken2.balanceOf(beneficiary1);
        uint256 initialBeneficiary2Token2Balance = myToken2.balanceOf(beneficiary2);

        address[] memory tokensToDistribute = new address[](3);
        tokensToDistribute[0] = address(0); // ETH
        tokensToDistribute[1] = address(myToken1);
        tokensToDistribute[2] = address(myToken2);

        splitter.distributeMultipleTokens(tokensToDistribute);

        // ETH distribution
        assertApproxEqAbs(beneficiary1.balance, initialBeneficiary1ETHBalance + 5 ether, 1e18);
        assertApproxEqAbs(beneficiary2.balance, initialBeneficiary2ETHBalance + 5 ether, 1e18);

        // Token1 distribution
        assertEq(myToken1.balanceOf(beneficiary1), initialBeneficiary1Token1Balance + 250 * 10 ** myToken1.decimals());
        assertEq(myToken1.balanceOf(beneficiary2), initialBeneficiary2Token1Balance + 250 * 10 ** myToken1.decimals());

        // Token2 distribution
        assertEq(myToken2.balanceOf(beneficiary1), initialBeneficiary1Token2Balance + 125 * 10 ** myToken2.decimals());
        assertEq(myToken2.balanceOf(beneficiary2), initialBeneficiary2Token2Balance + 125 * 10 ** myToken2.decimals());
    }

    function test_Fail_AddBeneficiary_NotOwner() public {
        vm.prank(beneficiary1); // Not owner
        vm.expectRevert("Ownable: caller is not the owner");
        splitter.addBeneficiary(makeAddr("hacker"), 100);
    }

    function test_Fail_UpdateShares_NotBeneficiary() public {
        vm.expectRevert("Not a beneficiary");
        splitter.updateShares(makeAddr("nonBeneficiary"), 100);
    }
}
