// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedReputation} from "../src/DecentralizedReputation.sol";

contract DecentralizedReputationTest is Test {
    DecentralizedReputation public reputationContract;
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    function setUp() public {
        reputationContract = new DecentralizedReputation();
        owner = reputationContract.owner();
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
    }

    function test_StakeAndWithdraw() public {
        // Stake
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        reputationContract.stake{value: 0.1 ether}();
        assertEq(reputationContract.stakedAmount(user1), 0.1 ether);

        // Withdraw
        vm.prank(user1);
        reputationContract.withdrawStake(0.05 ether);
        assertEq(reputationContract.stakedAmount(user1), 0.05 ether);
    }

    function test_EndorseAndRevoke() public {
        // Setup stakes for endorsement weight
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        reputationContract.stake{value: reputationContract.MIN_STAKE()}();

        // Endorse
        vm.prank(user1);
        reputationContract.endorse(user2, true, "Great collaborator");

        (
            uint256 score,
            uint256 positiveScore,
            ,
            uint256 totalEndorsements,
            
        ) = reputationContract.getReputationData(user2);
        
        assertTrue(positiveScore > 0);
        assertEq(totalEndorsements, 1);
        assertTrue(score > 0);

        // Revoke Endorsement
        vm.prank(user1);
        reputationContract.revokeEndorsement(user2);

        (
            score,
            positiveScore,
            ,
            totalEndorsements,
            
        ) = reputationContract.getReputationData(user2);

        assertEq(positiveScore, 0);
        assertEq(totalEndorsements, 0);
        assertEq(score, 0);
    }

    function test_IssueCredential() public {
        vm.prank(user1);
        reputationContract.issueCredential(user2, "Verified Developer", "github.com/user2");
        
        DecentralizedReputation.Credential[] memory creds = reputationContract.getCredentials(user2);
        assertEq(creds.length, 1);
        assertEq(creds[0].issuer, user1);
        assertEq(creds[0].credentialType, "Verified Developer");
    }

    function test_ReputationDecay() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        reputationContract.stake{value: reputationContract.MIN_STAKE()}();

        vm.prank(user1);
        reputationContract.endorse(user2, true, "Initial endorsement");

        uint256 initialScore = reputationContract.getReputationScore(user2);
        assertTrue(initialScore > 0);

        // Advance time beyond decay period
        vm.warp(block.timestamp + reputationContract.DECAY_PERIOD() + 1);

        uint256 decayedScore = reputationContract.getReputationScore(user2);
        assertTrue(decayedScore < initialScore);
    }

    function test_Fail_EndorseSelf() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        reputationContract.stake{value: reputationContract.MIN_STAKE()}();

        vm.expectRevert("Cannot endorse self");
        vm.prank(user1);
        reputationContract.endorse(user1, true, "Self-endorse");
    }

    function test_Fail_DoubleEndorse() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        reputationContract.stake{value: reputationContract.MIN_STAKE()}();

        vm.prank(user1);
        reputationContract.endorse(user2, true, "First time");

        vm.expectRevert("Already endorsed");
        vm.prank(user1);
        reputationContract.endorse(user2, true, "Second time");
    }

    function test_EndorsementWeight() public {
        // User 1 has a higher stake, so their endorsement should have more weight
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        reputationContract.stake{value: 0.5 ether}(); // Higher stake

        vm.deal(user3, 1 ether);
        vm.prank(user3);
        reputationContract.stake{value: 0.1 ether}(); // Lower stake
        
        vm.prank(user1);
        reputationContract.endorse(user2, true, "High stake endorsement");
        uint256 scoreAfterUser1 = reputationContract.getReputationScore(user2);

        vm.prank(user3);
        reputationContract.endorse(user2, false, "Low stake endorsement");
        uint256 scoreAfterUser3 = reputationContract.getReputationScore(user2);

        // Even with a negative endorsement, the score should be positive
        // because the positive endorsement had a much higher weight
        assertTrue(scoreAfterUser3 < scoreAfterUser1);
    }
}
