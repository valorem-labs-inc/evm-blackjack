// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/utils/ChainlinkRandomRequester.sol";

contract RevertingRandomRequester is RandomRequester {
    function requestRandom(function (uint256, uint256) internal returns (uint256) f) internal override returns (uint256) {
        revert("Random revert");
    }
}

// necessary for testing since forge does not support mockCallRevert yet
contract RevertingCoordinator is VRFCoordinatorV2Interface {
    function getRequestConfig()
    external
    view
    returns (
      uint16,
      uint32,
      bytes32[] memory
    ) {
        revert("getRequestConfig");
    }

    function requestRandomWords(
        bytes32 keyHash,
        uint64 subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external returns (uint256 requestId) {
        revert("requestRandomWords");
    }

    function createSubscription() external returns (uint64 subId) {
        revert("createSubscription");
    }

    function getSubscription(uint64 subId)
    external
    view
    returns (
        uint96 balance,
        uint64 reqCount,
        address owner,
        address[] memory consumers
    ) {
        revert("getSubscription");
    }

    function requestSubscriptionOwnerTransfer(uint64 subId, address newOwner) external {
        revert("requestSubscriptionOwnerTransfer");
    }

    function acceptSubscriptionOwnerTransfer(uint64 subId) external {
        revert("acceptSubscriptionOwnerTransfer");
    }

    function addConsumer(uint64 subId, address consumer) external {
        revert("addConsumer");
    }

    function removeConsumer(uint64 subId, address consumer) external {
        revert("removeConsumer");
    }

    function cancelSubscription(uint64 subId, address to) external {
        revert("cancelSubscription");
    }

    function pendingRequestExists(uint64 subId) external view returns (bool) {
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
        VRFCoordinatorV2Interface mockCoordinator = VRFCoordinatorV2Interface(mockCoordinatorAddress);
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
