// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

abstract contract RandomRequester {
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct Request {
        bool pending;
        // TODO: other state for status checking? e.g. Enqueue time?
        // function pointer
        function (uint256, uint256[] memory) internal returns (uint256) fp;
    }

    mapping(uint256 => Request) requests;

    /**
     * @notice Requests a random variable from a source dictated by the concrete implementation
     * @notice of this adapter. Accepts a callback function on this contract to provide with the
     * @notice returned random value. The implementor is responsible for storing a Request in the
     * @notice requests map.
     * @param numWords The number of uint256 words to request.
     * @param f The function pointer to the callback function. Accepts two uint arguments for
     * the request id, and the fulfilled randomness request.
     * @return The request ID associated with this request for randomness
     */
    function requestRandom(uint16 numWords, function (uint256, uint256[] memory) internal returns (uint256) f)
        internal
        virtual
        returns (uint256);

    /**
     * @notice A function called by the concrete implementation of this abstract contract, after
     * @notice the request for randomness has been fulfilled. Calls the requested callback fn on
     * @notice this contract.
     * @param requestId The request being fulfilled.
     * @param randomWords The array of 256b random words.
     */
    function fulfillRandom(uint256 requestId, uint256[] memory randomWords) internal {
        require(requests[requestId].pending, "request not found");

        Request memory rq = requests[requestId];

        rq.fp(requestId, randomWords);

        delete requests[requestId];

        emit RequestFulfilled(requestId, randomWords);
    }
}
