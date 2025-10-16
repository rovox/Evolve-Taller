// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AssetToken} from "../src/AssetToken.sol";
import {RWAVault} from "../src/RWAValut.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address underlyingAsset = vm.envAddress("UNDERLYING_ASSET");

        vm.startBroadcast(deployerPrivateKey);

        AssetToken assetToken = new AssetToken();
        RWAVault rwaVault = new RWAVault(underlyingAsset, address(assetToken));

        vm.startBroadcast();

        console.log("AssetToken deployed at:", address(assetToken));
        console.log("RWAVault deployed at:", address(rwaVault));
    }
}
