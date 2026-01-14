// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/SubscriptionPaymentManager.sol";
import "../src/FreelancerEscrow.sol";
import "../src/RevenueSplitter.sol";
import "../src/DecentralizedReputation.sol";

contract DeployAll is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying from:", deployer);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Subscription Payment Manager
        console.log("\n=== Deploying SubscriptionPaymentManager ===");
        SubscriptionPaymentManager subscriptionManager = new SubscriptionPaymentManager();
        console.log("SubscriptionPaymentManager deployed at:", address(subscriptionManager));

        // 2. Deploy Freelancer Escrow
        console.log("\n=== Deploying FreelancerEscrow ===");
        address feeCollector = deployer; // Change this to your fee collection address
        FreelancerEscrow escrow = new FreelancerEscrow(feeCollector);
        console.log("FreelancerEscrow deployed at:", address(escrow));
        console.log("Fee Collector set to:", feeCollector);

        // 3. Deploy Revenue Splitter
        console.log("\n=== Deploying RevenueSplitter ===");
        // Example: Split between 3 beneficiaries
        address[] memory beneficiaries = new address[](3);
        uint256[] memory shares = new uint256[](3);
        
        // Replace these with actual addresses
        beneficiaries[0] = deployer;
        beneficiaries[1] = 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1; // Example address
        beneficiaries[2] = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4; // Example address
        
        shares[0] = 40; // 40%
        shares[1] = 35; // 35%
        shares[2] = 25; // 25%
        
        RevenueSplitter splitter = new RevenueSplitter(beneficiaries, shares);
        console.log("RevenueSplitter deployed at:", address(splitter));

        // 4. Deploy Decentralized Reputation
        console.log("\n=== Deploying DecentralizedReputation ===");
        DecentralizedReputation reputation = new DecentralizedReputation();
        console.log("DecentralizedReputation deployed at:", address(reputation));

        vm.stopBroadcast();

        // Summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("Network: Base Mainnet (Chain ID: 8453)");
        console.log("Deployer:", deployer);
        console.log("\nContract Addresses:");
        console.log("--------------------");
        console.log("SubscriptionPaymentManager:", address(subscriptionManager));
        console.log("FreelancerEscrow:", address(escrow));
        console.log("RevenueSplitter:", address(splitter));
        console.log("DecentralizedReputation:", address(reputation));
        
        console.log("\n=== Verification Commands ===");
        console.log("forge verify-contract", address(subscriptionManager), "SubscriptionPaymentManager --chain-id 8453 --etherscan-api-key $BASESCAN_API_KEY");
        console.log("forge verify-contract", address(escrow), "FreelancerEscrow --chain-id 8453 --etherscan-api-key $BASESCAN_API_KEY --constructor-args $(cast abi-encode \"constructor(address)\" ", feeCollector, ")");
        console.log("forge verify-contract", address(splitter), "RevenueSplitter --chain-id 8453 --etherscan-api-key $BASESCAN_API_KEY");
        console.log("forge verify-contract", address(reputation), "DecentralizedReputation --chain-id 8453 --etherscan-api-key $BASESCAN_API_KEY");
    }
}

contract DeploySubscriptionOnly is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        SubscriptionPaymentManager subscriptionManager = new SubscriptionPaymentManager();
        console.log("SubscriptionPaymentManager:", address(subscriptionManager));
        
        vm.stopBroadcast();
    }
}

contract DeployEscrowOnly is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address feeCollector = vm.envAddress("FEE_COLLECTOR");
        
        vm.startBroadcast(deployerPrivateKey);
        
        FreelancerEscrow escrow = new FreelancerEscrow(feeCollector);
        console.log("FreelancerEscrow:", address(escrow));
        
        vm.stopBroadcast();
    }
}

contract DeploySplitterOnly is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address[] memory beneficiaries = vm.envAddress("BENEFICIARIES", ",");
        uint256[] memory shares = vm.envUint("SHARES", ",");
        
        vm.startBroadcast(deployerPrivateKey);
        
        RevenueSplitter splitter = new RevenueSplitter(beneficiaries, shares);
        console.log("RevenueSplitter:", address(splitter));
        
        vm.stopBroadcast();
    }
}

contract DeployReputationOnly is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        DecentralizedReputation reputation = new DecentralizedReputation();
        console.log("DecentralizedReputation:", address(reputation));
        
        vm.stopBroadcast();
    }
}