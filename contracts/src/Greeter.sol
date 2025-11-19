// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Greeter {
    string public greeting;

    constructor(string memory _greeting) {
        greeting = _greeting;
    }

    function setGreeting(string memory _greeting) external {
        greeting = _greeting;
    }
}
