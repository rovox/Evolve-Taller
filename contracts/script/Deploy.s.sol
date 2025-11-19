// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {ROSCA} from "../src/ROSCA.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        ROSCA rosca = new ROSCA();

        console2.log("ROSCA deployed at:", address(rosca));

        vm.stopBroadcast();
    }
}
