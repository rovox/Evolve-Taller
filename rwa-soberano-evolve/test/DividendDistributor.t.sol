// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/DividendDistributor.sol";
import "../src/RWAToken.sol";

contract DividendDistributorTest is Test {
    DividendDistributor public distributor;
    RWAToken public rwaToken;
    address public owner;
    address public shareholder1;
    address public shareholder2;
    address public nonShareholder;

    uint256 constant ASSET_ID = 0;
    uint256 constant TOTAL_SHARES = 1000;
    string constant ASSET_NAME = "Test Asset";
    string constant ASSET_DESCRIPTION = "Test Description";
    string constant ASSET_TYPE = "Property";

    event DividendCreated(
        uint256 indexed assetId,
        uint256 totalAmount,
        uint256 timestamp
    );

    event DividendClaimed(
        uint256 indexed assetId,
        address indexed shareholder,
        uint256 amount
    );

    function setUp() public {
        owner = address(this);
        shareholder1 = makeAddr("shareholder1");
        shareholder2 = makeAddr("shareholder2");
        nonShareholder = makeAddr("nonShareholder");

        rwaToken = new RWAToken("ipfs://QmBase/");
        distributor = new DividendDistributor(address(rwaToken));

        // Create asset and mint shares
        rwaToken.createAsset(ASSET_NAME, ASSET_DESCRIPTION, ASSET_TYPE, TOTAL_SHARES, 1000000, "ipfs://metadata");

        // Mint shares to shareholders
        rwaToken.mintShares(shareholder1, ASSET_ID, 600 * 1e18, ""); // 60%
        rwaToken.mintShares(shareholder2, ASSET_ID, 400 * 1e18, ""); // 40%
    }

    function test_Constructor() public {
        assertEq(address(distributor.rwaToken()), address(rwaToken));
        assertEq(distributor.owner(), owner);
    }

    function test_CreateDividend() public {
        uint256 dividendAmount = 1 ether;

        vm.expectEmit(true, true, false, true);
        emit DividendCreated(ASSET_ID, dividendAmount, block.timestamp);

        vm.prank(owner);
        distributor.createDividend{value: dividendAmount}(ASSET_ID);

        DividendDistributor.Dividend[] memory dividends = distributor.getDividends(ASSET_ID);
        assertEq(dividends.length, 1);
        assertEq(dividends[0].assetId, ASSET_ID);
        assertEq(dividends[0].totalAmount, dividendAmount);
        assertEq(dividends[0].distributed, false);
        assertGt(dividends[0].timestamp, 0);
    }

    function test_CreateDividend_RevertIfZeroValue() public {
        vm.prank(owner);
        vm.expectRevert("Dividend amount must be greater than 0");
        distributor.createDividend(ASSET_ID);
    }

    // function test_CreateDividend_RevertIfNotOwner() public {
    //     address distributorOwner = distributor.owner();
    //     assertNotEq(distributorOwner, shareholder1, "Shareholder should not be owner");
        
    //     vm.startPrank(shareholder1);
    //     vm.expectRevert();
    //     distributor.createDividend{value: 1 ether}(ASSET_ID);
    //     vm.stopPrank();
    // }

    function test_ClaimDividend() public {
        uint256 dividendAmount = 1 ether;
        uint256 dividendIndex = 0;

        // Create dividend
        vm.prank(owner);
        distributor.createDividend{value: dividendAmount}(ASSET_ID);

        // Shareholder1 should get 60% = 0.6 ether
        uint256 expectedAmount1 = 0.6 ether;
        uint256 balanceBefore1 = shareholder1.balance;

        vm.expectEmit(true, true, true, true);
        emit DividendClaimed(ASSET_ID, shareholder1, expectedAmount1);

        vm.prank(shareholder1);
        distributor.claimDividend(ASSET_ID, dividendIndex);

        assertEq(shareholder1.balance, balanceBefore1 + expectedAmount1);
        assertEq(distributor.claimedDividends(ASSET_ID, shareholder1), 1);
    }

    function test_ClaimDividend_Shareholder2() public {
        uint256 dividendAmount = 1 ether;
        uint256 dividendIndex = 0;

        // Create dividend
        vm.prank(owner);
        distributor.createDividend{value: dividendAmount}(ASSET_ID);

        // Shareholder2 should get 40% = 0.4 ether
        uint256 expectedAmount2 = 0.4 ether;
        uint256 balanceBefore2 = shareholder2.balance;

        vm.prank(shareholder2);
        distributor.claimDividend(ASSET_ID, dividendIndex);

        assertEq(shareholder2.balance, balanceBefore2 + expectedAmount2);
        assertEq(distributor.claimedDividends(ASSET_ID, shareholder2), 1);
    }

    function test_ClaimDividend_RevertIfNoShares() public {
        uint256 dividendAmount = 1 ether;
        uint256 dividendIndex = 0;

        // Create dividend
        vm.prank(owner);
        distributor.createDividend{value: dividendAmount}(ASSET_ID);

        vm.prank(nonShareholder);
        vm.expectRevert("No shares in this asset");
        distributor.claimDividend(ASSET_ID, dividendIndex);
    }

    function test_ClaimDividend_RevertIfAlreadyClaimed() public {
        uint256 dividendAmount = 1 ether;
        uint256 dividendIndex = 0;

        // Create dividend
        vm.prank(owner);
        distributor.createDividend{value: dividendAmount}(ASSET_ID);

        // Claim once
        vm.prank(shareholder1);
        distributor.claimDividend(ASSET_ID, dividendIndex);

        // Try to claim again
        vm.prank(shareholder1);
        vm.expectRevert("Already claimed");
        distributor.claimDividend(ASSET_ID, dividendIndex);
    }

    function test_ClaimDividend_RevertIfInvalidDividendIndex() public {
        vm.prank(shareholder1);
        vm.expectRevert("Dividend does not exist");
        distributor.claimDividend(ASSET_ID, 0); // No dividends created yet
    }

    function test_GetDividends_Empty() public {
        DividendDistributor.Dividend[] memory dividends = distributor.getDividends(ASSET_ID);
        assertEq(dividends.length, 0);
    }

    function test_GetDividends_AfterCreation() public {
        uint256 dividendAmount = 1 ether;

        vm.prank(owner);
        distributor.createDividend{value: dividendAmount}(ASSET_ID);

        DividendDistributor.Dividend[] memory dividends = distributor.getDividends(ASSET_ID);
        assertEq(dividends.length, 1);
        assertEq(dividends[0].totalAmount, dividendAmount);
    }

    function test_ReceiveEther() public {
        uint256 initialBalance = address(distributor).balance;
        uint256 sendAmount = 1 ether;

        payable(address(distributor)).transfer(sendAmount);

        assertEq(address(distributor).balance, initialBalance + sendAmount);
    }

    function test_MultipleDividends() public {
        // Create first dividend
        vm.prank(owner);
        distributor.createDividend{value: 1 ether}(ASSET_ID);

        // Create second dividend
        vm.prank(owner);
        distributor.createDividend{value: 2 ether}(ASSET_ID);

        DividendDistributor.Dividend[] memory dividends = distributor.getDividends(ASSET_ID);
        assertEq(dividends.length, 2);
        assertEq(dividends[0].totalAmount, 1 ether);
        assertEq(dividends[1].totalAmount, 2 ether);

        // Claim both dividends for shareholder1
        vm.prank(shareholder1);
        distributor.claimDividend(ASSET_ID, 0); // 0.6 ether

        vm.prank(shareholder1);
        distributor.claimDividend(ASSET_ID, 1); // 1.2 ether

        assertEq(shareholder1.balance, 1.8 ether);
        assertEq(distributor.claimedDividends(ASSET_ID, shareholder1), 2);
    }
}