// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "chainlink/interfaces/VRFCoordinatorV2Interface.sol";
import "chainlink/VRFConsumerBaseV2.sol";
import "chainlink/ConfirmedOwner.sol";

import "./RandomRequester.sol";

contract ChainlinkRandomRequester is VRFConsumerBaseV2, ConfirmedOwner, RandomRequester {
    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 subscriptionId;

    // past requests Id.
    uint256 public lastRequestId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 keyHash;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 100000;

    uint16 requestConfirmations;

    constructor(address _coordinator, uint64 _subscriptionId, bytes32 _keyHash)
        VRFConsumerBaseV2(_coordinator)
        ConfirmedOwner(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(_coordinator);

        (uint16 minimumRequestConfirmations,,) = COORDINATOR.getRequestConfig();

        requestConfirmations = minimumRequestConfirmations;

        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
    }

    // Assumes the subscription is funded sufficiently.
    function requestRandom(uint16 numWords, function (uint256, uint256[] memory) internal returns (uint256) f)
        internal
        override
        onlyOwner
        returns (uint256 requestId)
    {
        // Will revert if subscription is not set and funded.
        requestId =
            COORDINATOR.requestRandomWords(keyHash, subscriptionId, requestConfirmations, callbackGasLimit, numWords);
        requests[requestId] = Request({pending: true, fp: f});
        lastRequestId = requestId;
        emit RequestSent(requestId, 1);
        return requestId;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        fulfillRandom(requestId, randomWords);
    }
}
