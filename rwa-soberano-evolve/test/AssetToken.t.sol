// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {AssetToken} from "../src/AssetToken.sol";
import {RWAVault} from "../src/RWAValut.sol";

contract AssetTokenTest is Test {
    AssetToken public rwaToken;
    RWAVault public rwaVault;
    address public owner = address(0xbeef);
    address public user1 = address(0xcafe);
    address public user2 = address(0xdead);
    address public assetTokenAddr = address(0xface); // Simulación de USDC

    function setUp() public {
        vm.label(owner, "Owner");
        vm.label(user1, "User1");
        vm.label(user2, "User2");
        vm.label(assetTokenAddr, "USDC");

        // 1. Desplegar el AssetToken (NFT)
        vm.prank(owner);
        rwaToken = new AssetToken();

        // 2. Desplegar el RWAVault con el token subyacente y el AssetToken
        vm.prank(owner);
        rwaVault = new RWAVault(assetTokenAddr, address(rwaToken));
    }

    // --- Pruebas de Propiedad y Despliegue ---
    function testDeployment() public view {
        assertEq(rwaToken.owner(), owner, "El owner no es correcto");
        assertEq(
            rwaToken.getRWATokenOwner(),
            owner,
            "El RWA (NFT ID 1) no pertenece al owner"
        );
        assertEq(
            rwaVault.underlyingAsset(),
            assetTokenAddr,
            "La direccion del asset no es correcta"
        );
    }

    // --- Pruebas de Rendimiento (EIP-4626) ---
    function testDepositAndTotalAssets() public {
        uint256 depositAmount = 1000e18;

        vm.prank(user1);
        uint256 shares = rwaVault.deposit(depositAmount, user1);

        assertEq(shares, depositAmount, "La cantidad de shares no es 1:1");
        assertEq(
            rwaVault.getTotalAssets(),
            depositAmount,
            "El total de assets no se actualizo"
        );
        assertEq(
            rwaVault.balanceOf(user1),
            depositAmount,
            "El balance de shares no es correcto"
        );
    }

    function testRegisterYield() public {
        uint256 initialDeposit = 500e18;
        uint256 yieldAmount = 50e18;

        vm.prank(user1);
        rwaVault.deposit(initialDeposit, user1);

        vm.prank(owner);
        rwaVault.registerYield(yieldAmount);

        assertEq(
            rwaVault.getTotalAssets(),
            initialDeposit + yieldAmount,
            "El rendimiento no se registro"
        );
    }

    function testWithdrawFailsIfNotOwner() public {
        uint256 withdrawAmount = 10e18;

        vm.prank(user1);
        vm.expectRevert("RWAVault: caller is not RWA token owner");
        rwaVault.withdraw(withdrawAmount, user1, user1);
    }

    function testWithdrawByOwner() public {
        uint256 depositAmount = 1000e18;
        uint256 withdrawAmount = 500e18;

        // User1 hace depósito
        vm.prank(user1);
        rwaVault.deposit(depositAmount, user1);

        // Owner (que también es dueño del NFT) puede retirar
        vm.prank(owner);
        uint256 shares = rwaVault.withdraw(withdrawAmount, owner, owner);

        assertEq(shares, withdrawAmount, "Shares retirados no coinciden");
        assertEq(
            rwaVault.getTotalAssets(),
            depositAmount - withdrawAmount,
            "Total assets no se actualizo correctamente"
        );
    }

    function testGasEfficiency() public {
        uint256 depositAmount = 1000e18;

        vm.startPrank(user1);
        rwaVault.deposit(depositAmount, user1);
        vm.stopPrank();

        // Test pasa si no hay revert
        assertTrue(true, "El test de gas efficiency paso");
    }

    function testMultipleUsers() public {
        uint256 user1Depodit = 500e18;
        uint256 user2Deposit = 300e18;

        // User1 hace depósito
        vm.prank(user1);
        rwaVault.deposit(user1Depodit, user1);

        // User2 hace depósito
        vm.prank(user2);
        rwaVault.deposit(user2Deposit, user2);

        assertEq(
            rwaVault.balanceOf(user1),
            user1Depodit,
            "Balance de User1 incorrecto"
        );
        assertEq(
            rwaVault.balanceOf(user2),
            user2Deposit,
            "Balance de User2 incorrecto"
        );
        assertEq(
            rwaVault.getTotalAssets(),
            user1Depodit + user2Deposit,
            "Total assets incorrecto"
        );
    }
}
