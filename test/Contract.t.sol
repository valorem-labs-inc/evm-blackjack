// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "chainlink/interfaces/VRFCoordinatorV2Interface.sol";
import "chainlink/VRFConsumerBaseV2.sol";

import "src/Contract.sol";

contract TestContract is Test {
    Contract c;

    function setUp() public {
    }

    function testBar() public {
        assertEq(uint256(1), uint256(1), "ok");
    }

    function testFoo(uint256 x) public {
        vm.assume(x < type(uint128).max);
        assertEq(x + x, x * 2);
    }
}
