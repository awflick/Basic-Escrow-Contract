// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {BasicEscrow} from "../src/BasicEscrow.sol";

//Mock contract for testReleaseFailsIfTransferToSellerReverts
contract RevertingReceiver {
    fallback() external payable {
        revert("I don't accept ETH");
    }
}

contract BasicEscrowTest is Test {
    BasicEscrow escrow;
    address buyer = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
    address payable seller = payable(address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8));

    function setUp() public {
        vm.deal(buyer, 10 ether); // Give the buyer some ether       
        vm.prank(buyer); // Set the buyer as the caller
        escrow = new BasicEscrow(seller); // Create a new escrow contract with the seller

        vm.label(buyer, "Buyer");
        vm.label(seller, "Seller");  
    }

    function testInitialState() public view {
        assertEq(escrow.buyer(), buyer, "Buyer shouldbe set correctly");
        assertEq(escrow.seller(), seller, "Seller should be set correctly");
        assertEq(uint(escrow.currentState()), uint(BasicEscrow.State.Created), "Initial state should be Created");
        assertEq(escrow.amountDeposited(), 0, "Initial amount deposited should be 0");
    }

    function testDeposit() public {
        vm.expectEmit(true, true, false, true);
        emit BasicEscrow.Deposited(buyer, 1 ether); //expected event

        vm.prank(buyer);
        escrow.deposit{value: 1 ether}();

        assertEq(address(escrow).balance, 1 ether);
        assertEq(escrow.amountDeposited(), 1 ether, "Amount Deposited should be updated");
        assertEq(uint(escrow.currentState()), uint(BasicEscrow.State.Locked), "State should be Locked after deposit");
    }

    function testBuyerCanReleaseFunds() public {
        vm.prank(buyer);
        escrow.deposit{value: 1 ether}(); // Buyer deposits 1 ETH

        uint256 sellerBalanceBefore = seller.balance;

        vm.expectEmit(true, true, false, true);
        emit BasicEscrow.Released(seller, 1 ether); // expected event

        vm.prank(buyer);
        escrow.releaseFunds();

        uint256 sellerBalanceAfter = seller.balance;
        // Asert
        assertEq(address(escrow).balance, 0, "Escrow balance should be 0 afer release");
        assertEq(uint(escrow.currentState()), uint(BasicEscrow.State.Released), "State should be Completed after release");
        assertEq(sellerBalanceAfter - sellerBalanceBefore, 1 ether, "Seller should receive 1 ETH");
    }

    function testOnlyBuyerCanDeposit() public {
        vm.expectRevert("Only buyer can call this function");
        escrow.deposit{value: 1 ether}(); // Attempt to deposit from the seller's address
    }

    function testOnlyBuyerCanReleaseFunds() public {
        vm.expectRevert("Only buyer can call this function");
        escrow.releaseFunds(); // Attempt to release funds from the seller's address
    }

    function testCannotDepositInLockedOrLaterState() public{
        vm.prank(buyer);
        escrow.deposit{value: 1 ether}(); // Buyer deposits 1 ETH

        vm.expectRevert("Invalid state for this operation");
        vm.prank(buyer);
        escrow.deposit{value:1 ether}(); // Attempt to deposit again in Locked state
    }

    function testCannotReleaseBeforeDeposit() public {
        vm.expectRevert("Invalid state for this operation");
        vm.prank(buyer);
        escrow.releaseFunds(); // Attempt to release funds before deposit
    }

    function testCannotReleaseTwice() public {
        vm.prank(buyer);
        escrow.deposit{value: 1 ether}(); // Buyer deposits 1 ETH

        vm.prank(buyer);
        escrow.releaseFunds(); // First release should suceed

        vm.expectRevert("Invalid state for this operation");
        vm.prank(buyer); // Attempt to release funds again
        escrow.releaseFunds(); // Second release should revert
    }

    function testZeroValueDepositReverts() public {
        vm.expectRevert("Deposit amount must be greater than zero");
        vm.prank(buyer);
        escrow.deposit{value: 0}(); // Attempt to deposit 0 ETH
    }

    function testCannotReleaseWithZeroBalance() public {
        // Note: This test doesn't improve branch coverage, but documents edge behavior
        vm.expectRevert("Invalid state for this operation");
        vm.prank(buyer);
        escrow.releaseFunds(); // Attempt to release funds when no deposit has been made
    }

    function testReleaseFailsIfTransferToSellerReverts() public {
        // Deploy a mock seller that reverts on receiving ETH
        RevertingReceiver badSeller = new RevertingReceiver();

        //Deploy a new escrow contract using this seller
        vm.prank(buyer);
        BasicEscrow badEscrow = new BasicEscrow(payable(address(badSeller)));

        // Deposit 1 ETH
        vm.prank(buyer);
        badEscrow.deposit{value: 1 ether}();

        //Expect revert from failed .call()
        vm.expectRevert("Transfer failed.");
        vm.prank(buyer);
        badEscrow.releaseFunds(); // Attempt to release funds to the reverting receiver
    }

    function testRefundSuccess() public {
        // Arrange
        vm.prank(buyer);
        escrow.deposit{value: 1 ether}(); // Buyer deposits 1 ether
        uint256 buyerBalanceBefore = buyer.balance; // Store buyer's balance before refund
        // Act
        vm.prank(buyer);
        escrow.refund(); // Attempt to refund
        // Assert
        assertEq(address(escrow).balance, 0, "Escrow balance should be 0 after refund");
        assertEq(buyer.balance, buyerBalanceBefore + 1 ether, "Buyer's balance should be refunded 1 ether");
    }

    function testRefundFailsBeforeDeposit() public {
        vm.expectRevert("Invalid state for this operation");
        vm.prank(buyer);
        escrow.refund(); // Should fail because state is Created
    }

    function testcancelWithTimeout() public {
        // Arrange
        uint256 buyerBalanceBefore = buyer.balance; // Store buyer's balance before deposit
        vm.prank(buyer);
        escrow.deposit{value: 1 ether}(); // Buyer deposits 1 ether
        // Fast forward time to simulate timeout
        vm.warp(block.timestamp + 32 days); 
        vm.expectEmit(true, true, false, true);
        emit BasicEscrow.Refunded(buyer, 1 ether); // expected event
        // Act
        vm.prank(buyer);
        escrow.cancelWithTimeout(); // Buyer cancels with timeout
        // Assert
        assertEq(address(escrow).balance, 0, "Escrow balance should be 0 after cancelWithTimeout");
        assertEq(buyer.balance, buyerBalanceBefore, "Buyer's balance should be refunded 1 ether after cancelWithTimeout");
    }

    function testRefundFailsWhenAmountDepositedIsZeroInLockedState() public{
        vm.prank(buyer);
        escrow.deposit{value: 1 ether}();

        vm.store(address(escrow), bytes32(uint256(2)), bytes32(0)); // Set amount Deposited to 0 directly in storage

        vm.expectRevert("No funds to refund");
        vm.prank(buyer);
        escrow.refund(); // Attempt to refund in Locked state should revert
    }

    function testCancelWithTimeoutFailsBeforeTimeoutPeriod() public {
        vm.prank(buyer);
        escrow.deposit{value: 1 ether}(); // Buyer deposits 1 ether

        vm.expectRevert("Cannot cancel before timeout");
        vm.prank(buyer);
        escrow.cancelWithTimeout(); // Attempt to cancel before timeout should revert
    }

    function testCancelWithTimeoutWhenAmountDepositedIsZero() public {
        vm.prank(buyer);
        escrow.deposit{value: 1 ether}();

        vm.store(address(escrow), bytes32(uint256(2)), bytes32(0)); // Set amount Deposited to 0 directly in storage

        vm.warp(block.timestamp + 31 days); // Bypass the timeout requirement

        vm.expectRevert("No funds to refund");
        vm.prank(buyer);
        escrow.cancelWithTimeout(); // Attempt to cancel with zero amount deposited should revert
    }

}