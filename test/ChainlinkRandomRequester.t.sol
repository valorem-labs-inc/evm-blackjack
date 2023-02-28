// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/utils/ChainlinkRandomRequester.sol";

contract RevertingRandomRequester is RandomRequester {
    function requestRandom(uint16, function (uint256, uint256[] memory) internal returns (uint256))
        internal
        pure
        override
        returns (uint256)
    {
        revert("Random revert");
    }
}

// necessary for testing since forge does not support mockCallRevert yet
contract RevertingCoordinator is VRFCoordinatorV2Interface {
    function getRequestConfig() external pure returns (uint16, uint32, bytes32[] memory) {
        revert("getRequestConfig");
    }

    function requestRandomWords(bytes32, uint64, uint16, uint32, uint32) external pure returns (uint256) {
        revert("requestRandomWords");
    }

    function createSubscription() external pure returns (uint64) {
        revert("createSubscription");
    }

    function getSubscription(uint64) external pure returns (uint96, uint64, address, address[] memory) {
        revert("getSubscription");
    }

    function requestSubscriptionOwnerTransfer(uint64, address) external pure {
        revert("requestSubscriptionOwnerTransfer");
    }

    function acceptSubscriptionOwnerTransfer(uint64) external pure {
        revert("acceptSubscriptionOwnerTransfer");
    }

    function addConsumer(uint64, address) external pure {
        revert("addConsumer");
    }

    function removeConsumer(uint64, address) external pure {
        revert("removeConsumer");
    }

    function cancelSubscription(uint64, address) external pure {
        revert("cancelSubscription");
    }

    function pendingRequestExists(uint64) external pure returns (bool) {
        revert("pendingRequestExists");
    }
}

contract ChainlinkRandomRequesterTest is Test {
    address coordinatorAddress;
    VRFCoordinatorV2Interface vrfc;
    uint32 chainlinkSubscriptionId;
    ChainlinkRandomRequester c;

    function setUp() public {
        coordinatorAddress = address(0xFFFF);
        vrfc = VRFCoordinatorV2Interface(coordinatorAddress);
    }

    function testChainlinkRandomRequesterCtor() public {
        // returns 1 min confirmation
        vm.mockCall(
            coordinatorAddress,
            abi.encodeWithSelector(VRFCoordinatorV2Interface.getRequestConfig.selector),
            abi.encode(1, 0, 0, 0)
        );
        c = new ChainlinkRandomRequester(coordinatorAddress, 0, 0);

        // TODO: assert state set in ctor

        // expect revert if getConfig reverts
        address mockCoordinatorAddress = address(new RevertingCoordinator());
        vm.expectRevert(bytes("getRequestConfig"));
        c = new ChainlinkRandomRequester(mockCoordinatorAddress, 0, 0);
    }

    function testBar() public {
        assertEq(uint256(1), uint256(1), "ok");
    }

    function testFoo(uint256 x) public {
        vm.assume(x < type(uint128).max);
        assertEq(x + x, x * 2);
    }
}
