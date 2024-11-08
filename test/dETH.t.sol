// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test} from "@forge/Test.sol";
import {TestPlus} from "@solady/test/utils/TestPlus.sol";

import {dETH} from "../dETH.sol";

contract dETHTest is Test, TestPlus {
    dETH internal deth;

    function setUp() public payable {
        deth = new dETH();
    }

    function testName() public {
        assertEq(deth.name(), "Delayed Ether");
    }

    function testSymbol() public {
        assertEq(deth.symbol(), "dETH");
    }
    
    function testFuzz_Deposit(uint256 amount) public {
        // Test depositing ETH
        uint256 depositAmount = bound(amount, 1, 1000 ether);
        deth.deposit{value: depositAmount}();
        
        // Check balances
        assertEq(address(deth).balance, depositAmount, "Contract balance should match deposit");
        assertEq(deth.balanceOf(address(this)), depositAmount, "User dETH balance should match deposit");
    }

    function testFuzz_DepositTo(uint256 amount) public {
        uint256 depositAmount = bound(amount, 1, 1000 ether);
        deth.deposit{value: depositAmount}();
    }

    function testFuzz_Withdraw(uint256 amount) public {
        // First deposit some ETH
        uint256 depositAmount = bound(amount, 1, 1000 ether);
        deth.deposit{value: depositAmount}();
        
        // Record balance before withdrawal
        uint256 balanceBefore = address(this).balance;
        
        // Withdraw the full amount
        deth.withdraw(depositAmount);
        
        // Check balances
        assertEq(address(deth).balance, 0, "Contract should have zero balance");
        assertEq(deth.balanceOf(address(this)), 0, "User should have zero dETH");
        assertEq(address(this).balance, balanceBefore + depositAmount, "ETH should be returned");
    }

    function testFuzz_PartialWithdraw(uint256 amount) public {
        // Deposit ETH
        uint256 depositAmount = bound(amount, 1, 1000 ether);
        deth.deposit{value: depositAmount}();
        
        // Withdraw half
        uint256 withdrawAmount = bound(_random(), 1, depositAmount);
        uint256 balanceBefore = address(this).balance;
        
        deth.withdraw(withdrawAmount);
        
        // Check balances
        assertEq(address(deth).balance, depositAmount - withdrawAmount, "Contract balance should be reduced");
        assertEq(deth.balanceOf(address(this)), depositAmount - withdrawAmount, "User dETH should be reduced");
        assertEq(address(this).balance, balanceBefore + withdrawAmount, "ETH should be partially returned");
    }

    function testFuzz_FailWithdrawInsufficientBalance(uint256 amount) public {
        uint256 withdrawAmount = bound(amount, 1, type(uint256).max);
        // Try to withdraw without depositing
        vm.expectRevert();
        deth.withdraw(withdrawAmount);
    }

    function testFailWithdrawZero() public {
        vm.expectRevert();
        deth.withdraw(0);
    }

    function testFuzz_Transfer(address recipient, uint256 amount) public {
        uint256 transferAmount = bound(amount, 1, 1000 ether);
        
        // Deposit first
        deth.deposit{value: transferAmount}();
        
        // Transfer to recipient
        bool success = deth.transfer(recipient, transferAmount);
        
        assertTrue(success, "Transfer should succeed");  
        assertEq(deth.balanceOf(address(this)), 0, "Sender balance should be zero");
        assertEq(deth.balanceOf(recipient), transferAmount, "Recipient should receive tokens");
    }

    function testFuzz_TransferFrom(address spender, address recipient, uint256 amount) public {
        vm.assume(spender != address(0) && recipient != address(0) && spender != recipient);
        uint256 transferAmount = bound(amount, 1, 1000 ether);
        
        // Deposit first
        deth.deposit{value: transferAmount}();
        
        // Approve spender
        deth.approve(spender, transferAmount);
        
        // Switch to spender's context and transfer
        vm.prank(spender);
        bool success = deth.transferFrom(address(this), recipient, transferAmount);
        
        assertTrue(success, "TransferFrom should succeed");
        assertEq(deth.balanceOf(address(this)), 0, "Sender balance should be zero");
        assertEq(deth.balanceOf(recipient), transferAmount, "Recipient should receive tokens");
        assertEq(deth.allowance(address(this), spender), 0, "Allowance should be consumed");
    }

    function testFailReverseIncorrectTransferId() public {        
        // Deposit and transfer
        bytes32 transferId = bytes32(0);
        
        // Try to reverse more than received
        vm.expectRevert();
        deth.reverse(transferId);
    }

    function testFuzz_FailReverseAfterTimeout(address recipient, uint256 amount) public {
        uint256 transferAmount = bound(amount, 1, 1000 ether);
        
        // Deposit and transfer
        bytes32 transferId = _depositAndTransfer(recipient, transferAmount);

        // Wait beyond the reverse timeframe
        vm.warp(block.timestamp + _hem(_random(), 1 days + 1, 100 days));
        
        vm.expectRevert();
        deth.reverse(transferId);
    }

    function testFuzz_ReverseTransfer(address recipient, uint256 amount) public {
        uint256 transferAmount = bound(amount, 1, 1000 ether);
        
        // Deposit and transfer
        bytes32 transferId = _depositAndTransfer(recipient, transferAmount);
        
        deth.reverse(transferId);
        
        assertEq(deth.balanceOf(recipient), 0, "Recipient balance should be zero");
        assertEq(deth.balanceOf(address(this)), transferAmount, "Original sender should receive tokens back");
    }

    function _depositAndTransfer(address to, uint256 amount) internal returns (bytes32) {
        bytes32 transferId = keccak256(
            abi.encodePacked(address(this), to, amount, block.timestamp)
        );
        deth.deposit{value: amount}();
        deth.transfer(to, amount);
        return transferId;
    }

    function testFuzz_WithdrawFrom(address spender, uint256 amount) public {
        vm.assume(spender != address(0) && spender != address(this));
        uint256 depositAmount = bound(amount, 1, 1000 ether);
        
        // Deposit first
        deth.deposit{value: depositAmount}();
        
        // Approve spender
        deth.approve(spender, depositAmount);
        
        // Switch to spender's context and withdraw
        vm.prank(spender);
        deth.withdrawFrom(address(this), spender, depositAmount);
        
        // Check balances
        assertEq(address(deth).balance, 0, "Contract should have zero balance");
        assertEq(deth.balanceOf(address(this)), 0, "User should have zero dETH");
        assertEq(spender.balance, depositAmount, "ETH should be withdrawn to spender");
        assertEq(deth.allowance(address(this), spender), 0, "Allowance should be consumed");
    }

    function testFuzz_PartialWithdrawFrom(address spender, uint256 amount) public {
        vm.assume(spender != address(0) && spender != address(this));
        uint256 depositAmount = bound(amount, 1, 1000 ether);
        
        // Deposit first
        deth.deposit{value: depositAmount}();
        
        // Approve spender
        deth.approve(spender, depositAmount);
        
        // Withdraw partial amount
        uint256 withdrawAmount = bound(_random(), 1, depositAmount);
        
        // Switch to spender's context and withdraw
        vm.prank(spender);
        deth.withdrawFrom(address(this), spender, withdrawAmount);
        
        // Check balances
        assertEq(address(deth).balance, depositAmount - withdrawAmount, "Contract balance should be reduced");
        assertEq(spender.balance, withdrawAmount, "ETH should be partially withdrawn to spender");
        assertEq(deth.allowance(address(this), spender), depositAmount - withdrawAmount, "Allowance should be reduced");
    }

    function testFuzz_FailWithdrawFromInsufficientAllowance(address spender, uint256 amount) public {
        vm.assume(spender != address(0));
        uint256 depositAmount = bound(amount, 1, 1000 ether);
        
        // Deposit first
        deth.deposit{value: depositAmount}();
        
        // Approve less than deposit amount
        uint256 allowance = bound(_random(), 0, depositAmount - 1);
        deth.approve(spender, allowance);
        
        // Try to withdraw more than allowed
        vm.prank(spender);
        vm.expectRevert();
        deth.withdrawFrom(address(this), spender, depositAmount);
    }

    function testFailWithdrawFromZero(address spender) public {
        vm.assume(spender != address(0));
        deth.approve(spender, 1 ether);
        
        vm.prank(spender);
        vm.expectRevert();
        deth.withdrawFrom(address(this), spender, 0);
    }

    receive() external payable {} // Allow contract to receive ETH
}
