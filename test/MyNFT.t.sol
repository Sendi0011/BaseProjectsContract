// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MyNFT} from "../src/MyNFT.sol";
import {Test, console} from "forge-std/Test.sol";
import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract MyNFTTest is Test {
    MyNFT public myNft;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this); // The contract deployer
        myNft = new MyNFT(owner);
        user1 = vm.makeAddr("user1");
        user2 = vm.makeAddr("user2");
    }

    function test_InitialState() public view {
        assertEq(myNft.name(), "MyNFT", "NFT name should be 'MyNFT'");
        assertEq(myNft.symbol(), "MNFT", "NFT symbol should be 'MNFT'");
        assertEq(myNft.totalSupply(), 0, "Initial total supply should be 0");
    }

    function test_Mint() public {
        string memory tokenURI = "ipfs://QmT...1";
        uint256 tokenId = myNft.mint(user1, tokenURI);

        assertEq(myNft.ownerOf(tokenId), user1, "Owner of minted token should be user1");
        assertEq(myNft.balanceOf(user1), 1, "Balance of user1 should be 1");
        assertEq(myNft.tokenURI(tokenId), tokenURI, "Token URI should be set correctly");
        assertEq(myNft.totalSupply(), 1, "Total supply should be 1 after minting");
    }

    function test_Mint_OnlyOwner() public {
        vm.prank(user1); // A non-owner address
        vm.expectRevert(abi.encodeWithSelector(myNft.OwnableUnauthorizedAccount.selector, user1));
        myNft.mint(user1, "ipfs://QmT...fail");
    }

    function test_TransferFrom() public {
        uint256 tokenId = myNft.mint(user1, "ipfs://QmT...2");

        vm.prank(user1);
        myNft.transferFrom(user1, user2, tokenId);

        assertEq(myNft.ownerOf(tokenId), user2, "New owner should be user2");
        assertEq(myNft.balanceOf(user1), 0, "user1's balance should be 0");
        assertEq(myNft.balanceOf(user2), 1, "user2's balance should be 1");
    }

    function test_TransferFrom_NotOwner() public {
        uint256 tokenId = myNft.mint(user1, "ipfs://QmT...3");
        
        vm.prank(user2); // user2 is not the owner
        vm.expectRevert(abi.encodeWithSelector(ERC721.ERC721InsufficientApproval.selector, user2, tokenId));
        myNft.transferFrom(user1, user2, tokenId);
    }

    function test_Approve() public {
        uint256 tokenId = myNft.mint(user1, "ipfs://QmT...4");

        vm.prank(user1);
        myNft.approve(user2, tokenId);

        assertEq(myNft.getApproved(tokenId), user2, "user2 should be approved");
    }

    function test_Approve_And_TransferFrom() public {
        uint256 tokenId = myNft.mint(user1, "ipfs://QmT...5");

        vm.prank(user1);
        myNft.approve(user2, tokenId);

        vm.prank(user2);
        myNft.transferFrom(user1, owner, tokenId);

        assertEq(myNft.ownerOf(tokenId), owner, "New owner should be 'owner'");
        assertEq(myNft.balanceOf(user1), 0, "user1's balance should be 0");
        assertEq(myNft.balanceOf(owner), 1, "'owner' balance should be 1");
        assertEq(myNft.getApproved(tokenId), address(0), "Approval should be cleared after transfer");
    }
    
    function test_SetApprovalForAll() public {
        uint256 tokenId1 = myNft.mint(user1, "ipfs://QmT...6");
        uint256 tokenId2 = myNft.mint(user1, "ipfs://QmT...7");

        vm.prank(user1);
        myNft.setApprovalForAll(user2, true);

        assertTrue(myNft.isApprovedForAll(user1, user2), "user2 should be an approved operator for user1");

        // user2 can now transfer both tokens
        vm.prank(user2);
        myNft.transferFrom(user1, owner, tokenId1);
        myNft.transferFrom(user1, owner, tokenId2);

        assertEq(myNft.ownerOf(tokenId1), owner, "New owner of token 1 should be 'owner'");
        assertEq(myNft.ownerOf(tokenId2), owner, "New owner of token 2 should be 'owner'");
        assertEq(myNft.balanceOf(user1), 0, "user1's balance should be 0");
        assertEq(myNft.balanceOf(owner), 2, "'owner' balance should be 2");

        // Unset approval
        vm.prank(user1);
        myNft.setApprovalForAll(user2, false);
        assertFalse(myNft.isApprovedForAll(user1, user2), "user2 should no longer be an approved operator");
    }
}
