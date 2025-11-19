// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {ROSCA} from "../src/ROSCA.sol";

contract SimulateMultiMonth is Test {
    ROSCA public rosca;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);

    uint256 public constant MONTHLY_AMOUNT = 1 ether;
    uint256 public constant DURATION = 3; // 3 months

    function setUp() public {
        rosca = new ROSCA();
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
    }

    function testSimulateFullCycle() public {
        vm.prank(alice);
        uint256 groupId = rosca.createGroup("Sim Group", MONTHLY_AMOUNT, DURATION);
        console.log("Created groupId:", groupId);

        vm.prank(bob);
        rosca.joinGroup(groupId);
        console.log("Bob joined");

        vm.prank(charlie);
        rosca.joinGroup(groupId);
        console.log("Charlie joined");

        // For each month, have all members contribute
        for (uint256 m = 0; m < DURATION; m++) {
            // Debug: print contract balance and totalContributions
            {
                (string memory n,,,,, , , uint256 total) = rosca.getGroupInfo(groupId);
                uint256 bal = address(rosca).balance;
                console.log('Before month contributions, contract balance:', bal);
                console.log('Group totalContributions:', total);
            }

            vm.prank(alice);
            try rosca.contribute{value: MONTHLY_AMOUNT}(groupId) {
                console.log('Alice contributed for month', m);
            } catch Error(string memory reason) {
                console.log('Alice revert:', reason);
                revert(reason);
            } catch (bytes memory low) {
                console.logBytes(low);
                revert('Alice low-level revert');
            }

            vm.prank(bob);
            try rosca.contribute{value: MONTHLY_AMOUNT}(groupId) {
                console.log('Bob contributed for month', m);
            } catch Error(string memory reason) {
                console.log('Bob revert:', reason);
                revert(reason);
            } catch (bytes memory low) {
                console.logBytes(low);
                revert('Bob low-level revert');
            }

            vm.prank(charlie);
            try rosca.contribute{value: MONTHLY_AMOUNT}(groupId) {
                console.log('Charlie contributed for month', m);
            } catch Error(string memory reason) {
                console.log('Charlie revert:', reason);
                revert(reason);
            } catch (bytes memory low) {
                console.logBytes(low);
                revert('Charlie low-level revert');
            }

            // Check there is a monthly winner recorded
            address winner = rosca.getMonthlyWinner(groupId, m);
            assertTrue(winner != address(0), "Winner should be set for month");

            // Advance time by 30 days to simulate month passing for next iteration
            vm.warp(block.timestamp + 30 days);
        }

        // After full duration, every member should have received exactly one payout (contract logic ensures no repeats)
        assertTrue(rosca.hasReceivedPayout(groupId, alice));
        assertTrue(rosca.hasReceivedPayout(groupId, bob));
        assertTrue(rosca.hasReceivedPayout(groupId, charlie));
    }

    receive() external payable {}
}
