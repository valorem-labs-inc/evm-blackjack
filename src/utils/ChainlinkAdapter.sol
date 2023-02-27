// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.13;

import "chainlink/interfaces/VRFCoordinatorV2Interface.sol";
import "chainlink/VRFConsumerBaseV2.sol";
import "chainlink/ConfirmedOwner.sol";

import "./RandomRequestResponse.sol";

contract ChainlinkAdapter is VRFConsumerBaseV2, ConfirmedOwner, RandomRequestResponse {

    VRFCoordinatorV2Interface COORDINATOR;

    // Your subscription ID.
    uint64 subscriptionId;

    // past requests Id.
    uint256 public lastRequestId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2/subscription/supported-networks/#configurations
    bytes32 keyHash =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 2;

    /**
     * HARDCODED FOR SEPOLIA
     * COORDINATOR: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
     */
    constructor(
        uint64 _subscriptionId
    )
        VRFConsumerBaseV2(0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625)
        ConfirmedOwner(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(
            0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625
        );
        subscriptionId = _subscriptionId;
    }

    // Assumes the subscription is funded sufficiently.
    function requestRandom(function (uint) internal returns (uint) f)
        internal
        override
        onlyOwner
        returns (uint256 requestId)
    {
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        requests[requestId] = Request({
            randomWord: 0,
            pending: true,
            fp: f
        });
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        fulfillRandom(_requestId, _randomWords[0]);
    }

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool) {
        require(requests[_requestId].pending, "request not found");
        Request memory request = requests[_requestId];
        return (request.pending);
    }
}
