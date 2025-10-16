// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {RWASovereignRollup} from "../src/RWASovereignRollup.sol";

contract DeployRollupScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        RWASovereignRollup rollup = new RWASovereignRollup();

        vm.stopBroadcast();

        console.log("RWASovereignRollup deployed at:", address(rollup));
        console.log(
            "DocumentRegistry deployed at:",
            address(rollup.documentRegistry())
        );
        console.log(" Fase 2 - Rollup Soberano desplegado exitosamente!");
        console.log(" DocumentRegistry:", address(rollup.documentRegistry()));
        console.log(" Integration Celestia DA: Simulada");
    }
}
