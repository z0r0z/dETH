// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {dETH} from "../dETH.sol";
import {Test} from "@forge/Test.sol";

contract dETHTest is Test {
    dETH internal deth;

    function setUp() public payable {
        // vm.createSelectFork(vm.rpcUrl('main')); // Ethereum mainnet fork.
        // vm.createSelectFork(vm.rpcUrl('base')); // Base OptimismL2 fork.
        // vm.createSelectFork(vm.rpcUrl('poly')); // Polygon network fork.
        // vm.createSelectFork(vm.rpcUrl('opti')); // Optimism EthL2 fork.
        // vm.createSelectFork(vm.rpcUrl('arbi')); // Arbitrum EthL2 fork.
        deth = new dETH();
    }

    function test() public {}
}
