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

        // We will write the deployed addresses and contract names to a JSON file
        // for easier parsing by other scripts.
        string memory json = string(
            abi.encodePacked(
                "{\n",
                "  \"DocumentRegistry\": {\n",
                "    \"address\": \"", vm.toString(address(registry)), "\",\n",
                "    \"abiPath\": \"out/DocumentRegistry.sol/DocumentRegistry.json\"\n",
                "  },\n",
                "  \"AssetToken\": {\n",
                "    \"address\": \"", vm.toString(address(token)), "\",\n",
                "    \"abiPath\": \"out/AssetToken.sol/AssetToken.json\"\n",
                "  },\n",
                "  \"RWASovereignRollup\": {\n",
                "    \"address\": \"", vm.toString(address(rwa)), "\",\n",
                "    \"abiPath\": \"out/RWASovereignRollup.sol/RWASovereignRollup.json\"\n",
                "  }\n",
                "}\n"
            )
        );

        vm.writeFile("./deployed-contracts.json", json);

        console2.log("Deployment complete. Contract details written to deployed-contracts.json");
        console2.log("RWASovereignRollup deployed at:", address(rwa));
        console2.log("DocumentRegistry (from rollup) deployed at:", address(registry));
        console2.log("AssetToken deployed at:", address(token));
    }
}
