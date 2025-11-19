// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ROSCA} from "../src/ROSCA.sol";

contract DemoROSCAScript is Script {
    ROSCA public rosca;

    address public alice = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // Default Anvil account 0
    address public bob = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Default Anvil account 1
    address public charlie = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // Default Anvil account 2

    function setUp() public {
        // Deploy ROSCA contract if not already deployed
        rosca = new ROSCA();
        console.log("ROSCA deployed at:", address(rosca));
    }

    function run() public {
        // Demo script to show ROSCA functionality
        // Deploy ROSCA contract
        vm.startBroadcast();
        rosca = new ROSCA();
        vm.stopBroadcast();

        // Create a demo group
        console.log("\n=== Creating Demo Group ===");
        uint256 groupId = rosca.createGroup("Demo Savings Circle", 0.1 ether, 3);
        console.log("Group created with ID:", groupId);

        vm.stopBroadcast();

        // Switch to Bob to join the group
        vm.startBroadcast(bob);
        rosca.joinGroup(groupId);
        console.log("Bob joined the group");
        vm.stopBroadcast();

        // Switch to Charlie to join the group
        vm.startBroadcast(charlie);
        rosca.joinGroup(groupId);
        console.log("Charlie joined the group");
        vm.stopBroadcast();

        // Show group info
        console.log("\n=== Group Information ===");
        (
            string memory name,
            uint256 monthlyAmount,
            uint256 duration,
            uint256 startTime,
            uint256 memberCount,
            uint256 currentMonth,
            bool isActive,
            uint256 totalContributions
        ) = rosca.getGroupInfo(groupId);

        console.log("Name:", name);
        console.log("Monthly Amount:", monthlyAmount);
        console.log("Duration:", duration);
        console.log("Member Count:", memberCount);
        console.log("Current Month:", currentMonth);
        console.log("Is Active:", isActive);
        console.log("Total Contributions:", totalContributions);

        // Show members
        address[] memory members = rosca.getGroupMembers(groupId);
        console.log("\n=== Members ===");
        for (uint256 i = 0; i < members.length; i++) {
            console.log("Member", i, ":", members[i]);
        }

        console.log("\n=== Demo Complete ===");
        console.log("Frontend can now connect to contract at:", address(rosca));
        console.log("Update CONTRACT_ADDRESS in frontend/app.js to:", address(rosca));
    }
}
