// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/RWAToken.sol";
import "../src/DividendDistributor.sol";
import "../src/libraries/RWAStorage.sol";

contract RWATokenTest is Test {
    RWAToken public rwaToken;
    DividendDistributor public dividendDistributor;
    
    address owner = address(0x1);
    address alice = address(0x2);
    address bob = address(0x3);
    address charlie = address(0x4);

    function setUp() public {
        vm.startPrank(owner);
        rwaToken = new RWAToken("ipfs://QmBase/");
        dividendDistributor = new DividendDistributor(payable(address(rwaToken)));
        vm.stopPrank();
    }

    function testCreateAsset() public {
        vm.startPrank(owner);
        
        uint256 assetId = rwaToken.createAsset(
            "Departamento Lujo",
            "Departamento en zona premium",
            "Departamento",
            1000,
            500000,
            "ipfs://QmHash123"
        );

        RWAStorage.Asset memory asset = rwaToken.getAsset(assetId);
        
        assertEq(asset.name, "Departamento Lujo");
        assertEq(asset.assetType, "Departamento");
        assertEq(asset.totalShares, 1000);
        assertEq(asset.valueInUSD, 500000);
        assertEq(asset.active, true);
        
        vm.stopPrank();
    }

    function testMintShares() public {
        vm.startPrank(owner);
        
        uint256 assetId = rwaToken.createAsset(
            "Obra de Arte",
            "Cuadro famoso",
            "Arte",
            100,
            100000,
            "ipfs://QmHash456"
        );

        uint256 sharesToMint = 50 * 10**18;
        rwaToken.mintShares(alice, assetId, sharesToMint, "");

        uint256 balance = rwaToken.balanceOf(alice, assetId);
        assertEq(balance, sharesToMint);

        uint256 percentage = rwaToken.getShareholderPercentage(assetId, alice);
        assertEq(percentage, 50);

        vm.stopPrank();
    }

    function testMintSharesBatch() public {
        vm.startPrank(owner);
        
        uint256 assetId = rwaToken.createAsset(
            "Auto Deportivo",
            "Ferrari modelo 2024",
            "Auto",
            1000,
            200000,
            "ipfs://QmHash789"
        );

        address[] memory recipients = new address[](3);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = charlie;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 250 * 10**18;
        amounts[1] = 250 * 10**18;
        amounts[2] = 500 * 10**18;

        rwaToken.mintSharesBatch(recipients, assetId, amounts, "");

        assertEq(rwaToken.balanceOf(alice, assetId), 250 * 10**18);
        assertEq(rwaToken.balanceOf(bob, assetId), 250 * 10**18);
        assertEq(rwaToken.balanceOf(charlie, assetId), 500 * 10**18);

        vm.stopPrank();
    }

    function testBurnShares() public {
        vm.startPrank(owner);
        
        uint256 assetId = rwaToken.createAsset(
            "Propiedad",
            "Casa grande",
            "Inmueble",
            1000,
            300000,
            "ipfs://QmHash101"
        );

        uint256 sharesToMint = 100 * 10**18;
        rwaToken.mintShares(alice, assetId, sharesToMint, "");

        assertEq(rwaToken.balanceOf(alice, assetId), sharesToMint);

        rwaToken.burnShares(alice, assetId, 50 * 10**18);
        
        assertEq(rwaToken.balanceOf(alice, assetId), 50 * 10**18);

        vm.stopPrank();
    }

    function testGetShareholderValue() public {
        vm.startPrank(owner);
        
        uint256 assetId = rwaToken.createAsset(
            "Diamante",
            "Joya valiosa",
            "Joya",
            100,
            1000000,
            "ipfs://QmHash102"
        );

        rwaToken.mintShares(alice, assetId, 25 * 10**18, "");

        uint256 value = rwaToken.getShareholderValue(assetId, alice);
        assertEq(value, 250000); // 25% de 1,000,000

        vm.stopPrank();
    }

    function testDividendDistribution() public {
        vm.startPrank(owner);
        
        uint256 assetId = rwaToken.createAsset(
            "Edificio",
            "Renta comercial",
            "Inmueble",
            100,
            1000000,
            "ipfs://QmHash103"
        );

        rwaToken.mintShares(alice, assetId, 50 * 10**18, "");
        rwaToken.mintShares(bob, assetId, 50 * 10**18, "");

        vm.stopPrank();

        // Crear dividendo
        vm.startPrank(owner);
        vm.deal(owner, 10 ether);
        dividendDistributor.createDividend{value: 10 ether}(assetId);
        vm.stopPrank();

        // Reclamar dividendo
        vm.startPrank(alice);
        dividendDistributor.claimDividend(assetId, 0);
        assertEq(alice.balance, 5 ether); // 50% de 10 ether
        vm.stopPrank();

        vm.startPrank(bob);
        dividendDistributor.claimDividend(assetId, 0);
        assertEq(bob.balance, 5 ether);
        vm.stopPrank();
    }

    function testTransactionHistory() public {
        vm.startPrank(owner);
        
        uint256 assetId = rwaToken.createAsset(
            "Reloj Suizo",
            "Rolex de coleccion",
            "Reloj",
            1000,
            50000,
            "ipfs://QmHash104"
        );

        rwaToken.mintShares(alice, assetId, 100 * 10**18, "");
        rwaToken.burnShares(alice, assetId, 50 * 10**18);

        RWAStorage.ShareholderTransaction[] memory history = rwaToken.getTransactionHistory(assetId);
        
        assertEq(history.length, 2);
        assertEq(keccak256(abi.encodePacked(history[0].transactionType)), keccak256(abi.encodePacked("mint")));
        assertEq(keccak256(abi.encodePacked(history[1].transactionType)), keccak256(abi.encodePacked("burn")));

        vm.stopPrank();
    }
}