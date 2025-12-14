// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {Greeter} from "../src/Greeter.sol";

contract DeployGreeter is Script {
    function run() external {
        vm.startBroadcast();

        Greeter greeter = new Greeter("Hello Evolve Demo!");

        console2.log("Greeter deployed at:", address(greeter));

        vm.stopBroadcast();
    }
}
