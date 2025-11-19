// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Greeter} from "../src/Greeter.sol";

contract GreeterTest is Test {
    Greeter public greeter;

    function setUp() public {
        greeter = new Greeter("Hello, World!");
    }

    function testGreeting() public {
        assertEq(greeter.greeting(), "Hello, World!");
    }

    function testSetGreeting() public {
        greeter.setGreeting("Hola, Mundo!");
        assertEq(greeter.greeting(), "Hola, Mundo!");
    }
}
