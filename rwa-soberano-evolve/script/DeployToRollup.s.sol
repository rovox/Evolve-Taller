// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

import {DocumentRegistry} from "../src/DocumentRegistry.sol";
import {AssetToken} from "../src/AssetToken.sol";
import {RWASovereignRollup} from "../src/RWASovereignRollup.sol";

contract DeployToRollup is Script {
    function run() external {
        bytes32 privateKeyBytes = vm.envBytes32("PRIVATE_KEY");
        uint256 deployerPrivateKey = uint256(privateKeyBytes);

        vm.startBroadcast(deployerPrivateKey);

        RWASovereignRollup rwa = new RWASovereignRollup();
        DocumentRegistry registry = rwa.documentRegistry();
        AssetToken token = new AssetToken();
        
        // Wire up the AssetToken to the RWA contract
        rwa.setAssetToken(address(token));

        vm.stopBroadcast();

        string memory addresses = string(
            abi.encodePacked(
                "REGISTRY_ADDRESS=", vm.toString(address(registry)), "\n",
                "TOKEN_ADDRESS=", vm.toString(address(token)), "\n",
                "RWA_ADDRESS=", vm.toString(address(rwa)), "\n"
            )
        );
        vm.writeFile("./deployed-addresses.env", addresses);

        console2.log("RWASovereignRollup deployed at", address(rwa));
        console2.log(
            "DocumentRegistry (from rollup) deployed at",
            address(registry)
        );
        console2.log("AssetToken deployed at", address(token));
    }
}
