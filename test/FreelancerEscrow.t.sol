// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {FreelancerEscrow} from "../src/FreelancerEscrow.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "./mocks/ERC20Mock.sol"; // Assuming a mock ERC20 for testing

contract FreelancerEscrowTest is Test {
    FreelancerEscrow public escrow;
    address public client;
    address public freelancer;
    address public arbitrator;
    address public feeCollector;
    ERC20Mock public mockToken;

    function setUp() public {
        feeCollector = makeAddr("feeCollector");
        escrow = new FreelancerEscrow(feeCollector);
        client = makeAddr("client");
        freelancer = makeAddr("freelancer");
        arbitrator = makeAddr("arbitrator");
        mockToken = new ERC20Mock("MockToken", "MTK", 18);

        vm.deal(client, 10 ether); // Fund client
    }

    function test_CreateEscrow_ETH() public {
        uint256 totalAmount = 1 ether;
        uint256 deadline = block.timestamp + 1 days;
        uint256[] memory milestoneAmounts = new uint256[](1);
        milestoneAmounts[0] = totalAmount;
        string[] memory milestoneDescriptions = new string[](1);
        milestoneDescriptions[0] = "First milestone";

        vm.prank(client);
        bytes32 escrowId = escrow.createEscrow{value: totalAmount}(
            freelancer,
            address(0), // ETH
            totalAmount,
            deadline,
            arbitrator,
            milestoneAmounts,
            milestoneDescriptions
        );

        (
            address _client,
            address _freelancer,
            address _token,
            uint256 _totalAmount,
            ,
            FreelancerEscrow.Status _status,
            
        ) = escrow.getEscrow(escrowId);

        assertEq(_client, client);
        assertEq(_freelancer, freelancer);
        assertEq(_token, address(0));
        assertEq(_totalAmount, totalAmount);
        assertEq(uint256(_status), uint256(FreelancerEscrow.Status.Active));
    }

    function test_CreateEscrow_ERC20() public {
        uint256 totalAmount = 1000;
        uint256 deadline = block.timestamp + 1 days;
        uint256[] memory milestoneAmounts = new uint256[](1);
        milestoneAmounts[0] = totalAmount;
        string[] memory milestoneDescriptions = new string[](1);
        milestoneDescriptions[0] = "First milestone";

        // Mint tokens to client and approve escrow contract
        mockToken.mint(client, totalAmount);
        vm.prank(client);
        mockToken.approve(address(escrow), totalAmount);

        vm.prank(client);
        bytes32 escrowId = escrow.createEscrow(
            freelancer,
            address(mockToken),
            totalAmount,
            deadline,
            arbitrator,
            milestoneAmounts,
            milestoneDescriptions
        );

        (
            address _client,
            address _freelancer,
            address _token,
            uint256 _totalAmount,
            ,
            FreelancerEscrow.Status _status,
            
        ) = escrow.getEscrow(escrowId);

        assertEq(_client, client);
        assertEq(_freelancer, freelancer);
        assertEq(_token, address(mockToken));
        assertEq(_totalAmount, totalAmount);
        assertEq(uint256(_status), uint256(FreelancerEscrow.Status.Active));
        assertEq(mockToken.balanceOf(address(escrow)), totalAmount);
    }

    function test_ReleaseMilestone_ETH() public {
        uint256 totalAmount = 1 ether;
        uint256 deadline = block.timestamp + 1 days;
        uint256[] memory milestoneAmounts = new uint256[](2);
        milestoneAmounts[0] = 0.5 ether;
        milestoneAmounts[1] = 0.5 ether;
        string[] memory milestoneDescriptions = new string[](2);
        milestoneDescriptions[0] = "Milestone 1";
        milestoneDescriptions[1] = "Milestone 2";

        vm.prank(client);
        bytes32 escrowId = escrow.createEscrow{value: totalAmount}(
            freelancer,
            address(0),
            totalAmount,
            deadline,
            arbitrator,
            milestoneAmounts,
            milestoneDescriptions
        );

        uint256 initialFreelancerBalance = freelancer.balance;
        uint256 initialFeeCollectorBalance = feeCollector.balance;

        // Release first milestone
        vm.prank(client);
        escrow.releaseMilestone(escrowId, 0);

        (
            ,
            ,
            ,
            ,
            uint256 releasedAmount,
            ,
            
        ) = escrow.getEscrow(escrowId);

        assertEq(releasedAmount, 0.5 ether);

        uint256 platformFee = (0.5 ether * escrow.platformFee()) / escrow.FEE_DENOMINATOR();
        assertEq(freelancer.balance, initialFreelancerBalance + (0.5 ether - platformFee));
        assertEq(feeCollector.balance, initialFeeCollectorBalance + platformFee);

        // Release second milestone, should complete escrow
        vm.prank(client);
        escrow.releaseMilestone(escrowId, 1);

        (
            ,
            ,
            ,
            ,
            releasedAmount,
            FreelancerEscrow.Status _status,
            
        ) = escrow.getEscrow(escrowId);

        assertEq(releasedAmount, totalAmount);
        assertEq(uint256(_status), uint256(FreelancerEscrow.Status.Completed));
    }

    function test_RaiseAndResolveDispute_ETH() public {
        uint256 totalAmount = 1 ether;
        uint256 deadline = block.timestamp + 1 days;
        uint256[] memory milestoneAmounts = new uint256[](1);
        milestoneAmounts[0] = totalAmount;
        string[] memory milestoneDescriptions = new string[](1);
        milestoneDescriptions[0] = "Milestone";

        vm.prank(client);
        bytes32 escrowId = escrow.createEscrow{value: totalAmount}(
            freelancer,
            address(0),
            totalAmount,
            deadline,
            arbitrator,
            milestoneAmounts,
            milestoneDescriptions
        );

        // Raise dispute
        vm.prank(client);
        escrow.raiseDispute(escrowId);
        (
            ,
            ,
            ,
            ,
            ,
            FreelancerEscrow.Status _status,
            
        ) = escrow.getEscrow(escrowId);
        assertEq(uint256(_status), uint256(FreelancerEscrow.Status.Disputed));

        // Resolve dispute
        uint256 clientShare = 0.6 ether;
        uint256 freelancerShare = 0.4 ether;
        uint256 initialClientBalance = client.balance;
        uint256 initialFreelancerBalance = freelancer.balance;
        uint256 initialFeeCollectorBalance = feeCollector.balance;

        vm.prank(arbitrator);
        escrow.resolveDispute(escrowId, clientShare, freelancerShare);

        (
            ,
            ,
            ,
            ,
            ,
            _status,
            
        ) = escrow.getEscrow(escrowId);
        assertEq(uint256(_status), uint256(FreelancerEscrow.Status.Completed));
        
        assertApproxEqAbs(client.balance, initialClientBalance + clientShare, 1e18); // Use approx due to gas costs
        
        uint256 freelancerFee = (freelancerShare * escrow.platformFee()) / escrow.FEE_DENOMINATOR();
        assertApproxEqAbs(freelancer.balance, initialFreelancerBalance + (freelancerShare - freelancerFee), 1e18);
        assertApproxEqAbs(feeCollector.balance, initialFeeCollectorBalance + freelancerFee, 1e18);
    }
    
    function test_CancelEscrow_ETH() public {
        uint256 totalAmount = 1 ether;
        uint256 deadline = block.timestamp + 1 days;
        uint256[] memory milestoneAmounts = new uint256[](1);
        milestoneAmounts[0] = totalAmount;
        string[] memory milestoneDescriptions = new string[](1);
        milestoneDescriptions[0] = "Milestone";

        vm.prank(client);
        bytes32 escrowId = escrow.createEscrow{value: totalAmount}(
            freelancer,
            address(0),
            totalAmount,
            deadline,
            arbitrator,
            milestoneAmounts,
            milestoneDescriptions
        );

        uint256 initialClientBalance = client.balance;

        // Cancel escrow
        vm.prank(client);
        escrow.cancelEscrow(escrowId);

        (
            ,
            ,
            ,
            ,
            ,
            FreelancerEscrow.Status _status,
            
        ) = escrow.getEscrow(escrowId);
        assertEq(uint256(_status), uint256(FreelancerEscrow.Status.Cancelled));
        assertApproxEqAbs(client.balance, initialClientBalance + totalAmount, 1e18);
    }
    
    function test_Fail_CreateEscrow_InvalidAmount() public {
        uint256 totalAmount = 0; // Invalid amount
        uint256 deadline = block.timestamp + 1 days;
        uint256[] memory milestoneAmounts = new uint256[](1);
        milestoneAmounts[0] = 0;
        string[] memory milestoneDescriptions = new string[](1);
        milestoneDescriptions[0] = "Milestone";

        vm.prank(client);
        vm.expectRevert("Amount must be > 0");
        escrow.createEscrow{value: totalAmount}(
            freelancer,
            address(0),
            totalAmount,
            deadline,
            arbitrator,
            milestoneAmounts,
            milestoneDescriptions
        );
    }

    function test_Fail_ReleaseMilestone_NotClient() public {
        uint256 totalAmount = 1 ether;
        uint256 deadline = block.timestamp + 1 days;
        uint256[] memory milestoneAmounts = new uint256[](1);
        milestoneAmounts[0] = totalAmount;
        string[] memory milestoneDescriptions = new string[](1);
        milestoneDescriptions[0] = "Milestone";

        vm.prank(client);
        bytes32 escrowId = escrow.createEscrow{value: totalAmount}(
            freelancer,
            address(0),
            totalAmount,
            deadline,
            arbitrator,
            milestoneAmounts,
            milestoneDescriptions
        );

        vm.prank(freelancer); // Not client
        vm.expectRevert("Not client");
        escrow.releaseMilestone(escrowId, 0);
    }

    function test_Fail_CancelEscrow_MilestonesReleased() public {
        uint256 totalAmount = 1 ether;
        uint256 deadline = block.timestamp + 1 days;
        uint256[] memory milestoneAmounts = new uint256[](1);
        milestoneAmounts[0] = totalAmount;
        string[] memory milestoneDescriptions = new string[](1);
        milestoneDescriptions[0] = "Milestone";

        vm.prank(client);
        bytes32 escrowId = escrow.createEscrow{value: totalAmount}(
            freelancer,
            address(0),
            totalAmount,
            deadline,
            arbitrator,
            milestoneAmounts,
            milestoneDescriptions
        );

        vm.prank(client);
        escrow.releaseMilestone(escrowId, 0); // Release milestone

        vm.prank(client);
        vm.expectRevert("Milestones already released");
        escrow.cancelEscrow(escrowId);
    }
}