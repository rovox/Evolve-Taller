// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {ROSCA} from "../src/ROSCA.sol";

contract DeployROSCAScript is Script {
    function run() public {
        // Try to read PRIVATE_KEY from environment; if not provided, use startBroadcast() without args
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        if (deployerPrivateKey != 0) {
            vm.startBroadcast(deployerPrivateKey);
        } else {
            // If user passed --private-key to forge, vm.startBroadcast() without args will use it
            vm.startBroadcast();
        }

        ROSCA rosca = new ROSCA();

        vm.stopBroadcast();
    }
}
