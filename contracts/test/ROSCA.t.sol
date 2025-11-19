// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ROSCA} from "../src/ROSCA.sol";

contract ROSCATest is Test {
    ROSCA public rosca;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    address public diana = address(0x4);

    uint256 public constant MONTHLY_AMOUNT = 1 ether;
    uint256 public constant DURATION = 4; // 4 months
    string public constant GROUP_NAME = "Test ROSCA Group";

    function setUp() public {
        rosca = new ROSCA();

        // Give test accounts some ETH
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
        vm.deal(diana, 10 ether);
    }

    function testCreateGroup() public {
        uint256 groupId = rosca.createGroup("Test Group", 1 ether, 6);
        assertEq(groupId, 0);
    }

    function testCreateGroupWithInvalidParams() public {
        vm.prank(alice);

        // Test empty name
        vm.expectRevert("Group name cannot be empty");
        rosca.createGroup("", MONTHLY_AMOUNT, DURATION);

        // Test zero monthly amount
        vm.expectRevert("Monthly amount must be greater than 0");
        rosca.createGroup(GROUP_NAME, 0, DURATION);

        // Test zero duration
        vm.expectRevert("Duration must be greater than 0");
        rosca.createGroup(GROUP_NAME, MONTHLY_AMOUNT, 0);
    }

    function testJoinGroup() public {
        // Alice creates group
        vm.prank(alice);
        uint256 groupId = rosca.createGroup(GROUP_NAME, MONTHLY_AMOUNT, DURATION);

        // Bob joins group
        vm.prank(bob);
        rosca.joinGroup(groupId);

        address[] memory members = rosca.getGroupMembers(groupId);
        assertEq(members.length, 2);
        assertEq(members[1], bob);

        (,,,, uint256 memberCount,,,) = rosca.getGroupInfo(groupId);
        assertEq(memberCount, 2);
    }

    function testJoinGroupRestrictions() public {
        vm.prank(alice);
        uint256 groupId = rosca.createGroup(GROUP_NAME, MONTHLY_AMOUNT, DURATION);

        // Test joining non-existent group
        vm.prank(bob);
        vm.expectRevert("Group does not exist");
        rosca.joinGroup(999);

        // Test joining twice
        vm.prank(bob);
        rosca.joinGroup(groupId);

        vm.prank(bob);
        vm.expectRevert("Already a member");
        rosca.joinGroup(groupId);
    }

    function testContribution() public {
        // Create group and add members
        vm.prank(alice);
        uint256 groupId = rosca.createGroup(GROUP_NAME, MONTHLY_AMOUNT, DURATION);

        vm.prank(bob);
        rosca.joinGroup(groupId);

        vm.prank(charlie);
        rosca.joinGroup(groupId);

        vm.prank(diana);
        rosca.joinGroup(groupId);

        // Alice contributes
        vm.prank(alice);
        rosca.contribute{value: MONTHLY_AMOUNT}(groupId);

        uint256 aliceContribution = rosca.getMemberContribution(groupId, alice);
        assertEq(aliceContribution, MONTHLY_AMOUNT);

        (,,,,,,, uint256 totalContributions) = rosca.getGroupInfo(groupId);
        assertEq(totalContributions, MONTHLY_AMOUNT);
    }

    function testContributionRestrictions() public {
        vm.prank(alice);
        uint256 groupId = rosca.createGroup(GROUP_NAME, MONTHLY_AMOUNT, DURATION);

        // Test non-member contribution
        vm.prank(bob);
        vm.expectRevert("Not a member of this group");
        rosca.contribute{value: MONTHLY_AMOUNT}(groupId);

        // Test incorrect amount
        vm.prank(alice);
        vm.expectRevert("Incorrect contribution amount");
        rosca.contribute{value: MONTHLY_AMOUNT - 1}(groupId);
    }

    function testFullCycleWithPayout() public {
        // Create group with 3 members
        vm.prank(alice);
        uint256 groupId = rosca.createGroup(GROUP_NAME, MONTHLY_AMOUNT, 3);

        vm.prank(bob);
        rosca.joinGroup(groupId);

        vm.prank(charlie);
        rosca.joinGroup(groupId);

        uint256 contractBalanceBefore = address(rosca).balance;

        // All members contribute for month 0
        vm.prank(alice);
        rosca.contribute{value: MONTHLY_AMOUNT}(groupId);

        vm.prank(bob);
        rosca.contribute{value: MONTHLY_AMOUNT}(groupId);

        // Charlie's contribution should trigger payout
        uint256 charlieBalanceBefore = charlie.balance;
        uint256 bobBalanceBefore = bob.balance;
        uint256 aliceBalanceBefore = alice.balance;

        vm.prank(charlie);
        rosca.contribute{value: MONTHLY_AMOUNT}(groupId);

        // Check that contract balance decreased by payout amount
        uint256 contractBalanceAfter = address(rosca).balance;
        uint256 expectedPayout = MONTHLY_AMOUNT * 3;
        assertEq(contractBalanceBefore + (MONTHLY_AMOUNT * 3) - expectedPayout, contractBalanceAfter);

        // Check that someone received the payout
        address winner = rosca.getMonthlyWinner(groupId, 0);
        assertTrue(winner != address(0));
        assertTrue(rosca.hasReceivedPayout(groupId, winner));

        // Verify winner received payout
        if (winner == alice) {
            assertEq(alice.balance, aliceBalanceBefore - MONTHLY_AMOUNT + expectedPayout);
        } else if (winner == bob) {
            assertEq(bob.balance, bobBalanceBefore - MONTHLY_AMOUNT + expectedPayout);
        } else if (winner == charlie) {
            assertEq(charlie.balance, charlieBalanceBefore - MONTHLY_AMOUNT + expectedPayout);
        }
    }

    function testCurrentMonth() public {
        vm.prank(alice);
        uint256 groupId = rosca.createGroup(GROUP_NAME, MONTHLY_AMOUNT, DURATION);

        assertEq(rosca.getCurrentMonth(groupId), 0);

        // Advance time by 30 days
        vm.warp(block.timestamp + 30 days);
        assertEq(rosca.getCurrentMonth(groupId), 1);

        // Advance time by another 30 days
        vm.warp(block.timestamp + 30 days);
        assertEq(rosca.getCurrentMonth(groupId), 2);
    }

    function testMultipleGroups() public {
        // Alice creates first group
        vm.prank(alice);
        uint256 groupId1 = rosca.createGroup("Group 1", MONTHLY_AMOUNT, DURATION);

        // Bob creates second group
        vm.prank(bob);
        uint256 groupId2 = rosca.createGroup("Group 2", MONTHLY_AMOUNT * 2, DURATION + 2);

        assertEq(groupId1, 0);
        assertEq(groupId2, 1);
        assertEq(rosca.groupCounter(), 2);

        (string memory name1, uint256 amount1,,,,,,) = rosca.getGroupInfo(groupId1);
        (string memory name2, uint256 amount2,,,,,,) = rosca.getGroupInfo(groupId2);

        assertEq(name1, "Group 1");
        assertEq(amount1, MONTHLY_AMOUNT);
        assertEq(name2, "Group 2");
        assertEq(amount2, MONTHLY_AMOUNT * 2);
    }

    function testEventEmissions() public {
        // Test GroupCreated event
        vm.prank(alice);
        vm.expectEmit(true, false, false, true);
        emit ROSCA.GroupCreated(0, GROUP_NAME, MONTHLY_AMOUNT, DURATION, alice);
        uint256 groupId = rosca.createGroup(GROUP_NAME, MONTHLY_AMOUNT, DURATION);

        // Test MemberJoined event
        vm.prank(bob);
        vm.expectEmit(true, true, false, false);
        emit ROSCA.MemberJoined(groupId, bob);
        rosca.joinGroup(groupId);

        // Test ContributionMade event
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit ROSCA.ContributionMade(groupId, alice, MONTHLY_AMOUNT, 0);
        rosca.contribute{value: MONTHLY_AMOUNT}(groupId);
    }

    receive() external payable {}
}
