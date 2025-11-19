// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ROSCA} from "../src/ROSCA.sol";

contract SimulateDemoScript is Script {
    function run() public {
        // Private keys: try env vars, otherwise fallback to common Anvil default keys for local dev
        uint256 pkA = vm.envOr("PRIVATE_KEY", uint256(0));
        uint256 pkB = vm.envOr("PRIVATE_KEY_B", uint256(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d));
        uint256 pkC = vm.envOr("PRIVATE_KEY_C", uint256(0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a));

        // Use pkA if provided, otherwise vm.startBroadcast() will use --private-key flag
        if (pkA != 0) vm.startBroadcast(pkA);
        else vm.startBroadcast();

        // Deploy a fresh ROSCA for demo
        ROSCA rosca = new ROSCA();
        console.log("Deployed ROSCA at", address(rosca));

        // Optionally seed the contract with extra ETH to avoid edge-case OutOfFunds in demo
        (bool seeded, ) = payable(address(rosca)).call{value: 1 ether}("");
        require(seeded, "Seeding contract failed");

        // Create group as deployer (account A)
        uint256 monthly = 0.01 ether;
        uint256 duration = 3;
        uint256 groupId = rosca.createGroup("Demo Group", monthly, duration);
        console.log("Created groupId:", groupId);

        vm.stopBroadcast();

        // Bob joins
        vm.startBroadcast(pkB);
        rosca.joinGroup(groupId);
        console.log("Bob joined");
        vm.stopBroadcast();

        // Charlie joins
        vm.startBroadcast(pkC);
        rosca.joinGroup(groupId);
        console.log("Charlie joined");
        vm.stopBroadcast();

        // Contributions: A, B, C each month
        for (uint256 m = 0; m < duration; m++) {
            if (pkA != 0) vm.startBroadcast(pkA); else vm.startBroadcast();
            rosca.contribute{value: monthly}(groupId);
            console.log("A contributed month", m);
            vm.stopBroadcast();

            vm.startBroadcast(pkB);
            rosca.contribute{value: monthly}(groupId);
            console.log("B contributed month", m);
            vm.stopBroadcast();

            vm.startBroadcast(pkC);
            rosca.contribute{value: monthly}(groupId);
            console.log("C contributed month", m);
            vm.stopBroadcast();

            // Advance time by 30 days to move to next month
            vm.warp(block.timestamp + 30 days);
        }

        console.log("Demo completed. Contract balance:", address(rosca).balance);
    }
}
