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


contract TestRandomRequester is ChainlinkRandomRequester {
    event LogRand(uint256 requestId, uint256[] randWords);

    constructor(address _coordinator, uint64 _subscriptionId, bytes32 _keyHash) 
        ChainlinkRandomRequester(_coordinator, _subscriptionId, _keyHash) 
    {}

    function requestRandomEmission(uint16 numRandom) public returns (uint256) {
        return requestRandom(numRandom, testCallback);
    }

    function testCallback(uint256 requestId, uint256[] memory randWords) internal returns (uint256) {
        emit LogRand(requestId, randWords);
        return 0;
    }
}

contract ChainlinkRandomRequesterTest is Test {
    event LogRand(uint256 requestId, uint256[] randWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event RequestSent(uint256 requestId, uint32 numWords);

    address coordinatorAddress;
    VRFCoordinatorV2Interface vrfc;
    uint32 chainlinkSubscriptionId;
    TestRandomRequester t;

    modifier withInit {
        vm.mockCall(
            coordinatorAddress,
            abi.encodeWithSelector(VRFCoordinatorV2Interface.getRequestConfig.selector),
            abi.encode(1, 0, 0, 0)
        );
        t = new TestRandomRequester(coordinatorAddress, 0, 0);
        _;
    }

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
        ChainlinkRandomRequester c = new ChainlinkRandomRequester(coordinatorAddress, 0, 0);

        // TODO: assert state set in ctor

        // expect revert if getConfig reverts
        address mockCoordinatorAddress = address(new RevertingCoordinator());
        vm.expectRevert(bytes("getRequestConfig"));
        c = new ChainlinkRandomRequester(mockCoordinatorAddress, 0, 0);
    }

    function testRequestReceive() public withInit {
        uint256[] memory randVal = new uint256[](1);
        randVal[0] = uint256(0xDEADBEEF);
        // enqueue a request for a single random word 
        uint256 mockRequestId = uint256(0x1234);
        vm.mockCall(
            coordinatorAddress,
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector,
                0, //keyhash
                0, //subscription id
                1, // request confirmations
                100000, // gas limit
                1 //num words
            ),
            abi.encode(mockRequestId)
        );
        uint256 requestId = t.requestRandomEmission(1);

        // assert that the request was stored and fields are correct
        assertEq(requestId, mockRequestId);
        // TODO: more fields as necessary in the request

        // prank the callback from the coordinatoor
        vm.prank(coordinatorAddress);

        // expect emission of the "rand" values
        vm.expectEmit(true, true, true, true);
        emit LogRand(mockRequestId, randVal);
        t.rawFulfillRandomWords(mockRequestId, randVal);

        mockRequestId++;
        // inc request id, assert RequestFulfilled is emitted
        vm.mockCall(
            coordinatorAddress,
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector,
                0, //keyhash
                0, //subscription id
                1, // request confirmations
                100000, // gas limit
                1 //num words
            ),
            abi.encode(mockRequestId)
        );
        requestId = t.requestRandomEmission(1);

        vm.prank(coordinatorAddress);
        vm.expectEmit(true, true, true, true);
        emit RequestFulfilled(mockRequestId, randVal);
        t.rawFulfillRandomWords(mockRequestId, randVal);
    }
}
