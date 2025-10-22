// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/RWAToken.sol";
import "../src/DividendDistributor.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Desplegar RWAToken
        RWAToken rwaToken = new RWAToken("ipfs://QmBase/");
        console.log("RWAToken deployed at:", address(rwaToken));

        // Desplegar DividendDistributor
        DividendDistributor distributor = new DividendDistributor(address(rwaToken));
        console.log("DividendDistributor deployed at:", address(distributor));

        vm.stopBroadcast();
    }
}