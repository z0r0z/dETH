// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC20, WETH} from "@solady/src/tokens/WETH.sol";

/// @notice Delayed ethereum token
/// @author z0r0z.eth for nani.eth
/// @custom:coauthor tabshaikh.eth
contract dETH is WETH {
    event Log(bytes32 transferId);

    uint256 constant public DELAY = 1 days;

    error TransferFinalized();

    struct PendingTransfer {
        address from;
        address to;
        uint160 amount;
        uint96 timestamp;
    }

    mapping(bytes32 transferId => PendingTransfer) public pendingTransfers;

    constructor() payable {}

    function name() public pure override(WETH) returns (string memory) {
        return "Delayed Ether";
    }

    function symbol() public pure override(WETH) returns (string memory) {
        return "dETH";
    }

    function depositTo(address to) public payable {
        bytes32 transferId = keccak256(
            abi.encodePacked(msg.sender, to, msg.value, block.timestamp)
        );
        
        _updatePendingTransfer(transferId, msg.sender, to, msg.value, block.timestamp);

        emit Log(transferId);

        _mint(to, msg.value);
    }

    function withdrawFrom(address from, address to, uint256 amount) public {
        if (msg.sender != from) 
            _spendAllowance(from, msg.sender, amount);

        _burn(from, amount);
        
        /// @solidity memory-safe-assembly
        assembly {
            // Transfer the ETH and check if it succeeded or not.
            if iszero(call(gas(), to, amount, codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    function transfer(address to, uint256 amount) public override(ERC20) returns (bool) {
        bytes32 transferId = keccak256(
            abi.encodePacked(msg.sender, to, amount, block.timestamp)
        );
        
        _updatePendingTransfer(transferId, msg.sender, to, amount, block.timestamp);

        emit Log(transferId);

        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override(ERC20) returns (bool) {
        bytes32 transferId = keccak256(
            abi.encodePacked(from, to, amount, block.timestamp)
        );
        
        _updatePendingTransfer(transferId, from, to, amount, block.timestamp);

        emit Log(transferId);

        return super.transferFrom(from, to, amount);
    }

    function reverse(bytes32 transferId) public {
        unchecked {
            PendingTransfer storage pt = pendingTransfers[transferId];
            
            if (block.timestamp > pt.timestamp + DELAY) 
                revert TransferFinalized();
            if (msg.sender != pt.from) 
                _spendAllowance(pt.from, msg.sender, pt.amount);

            _transfer(pt.to, pt.from, pt.amount);
            
            delete pendingTransfers[transferId];
        }
    }

    function _updatePendingTransfer(bytes32 transferId, address from, address to, uint256 amount, uint256 timestamp) internal {
        unchecked {
            PendingTransfer storage pt = pendingTransfers[transferId];
            pt.from = from;
            pt.to = to;
            pt.amount += uint160(amount);
            pt.timestamp = uint96(timestamp);
        }
    }
}
