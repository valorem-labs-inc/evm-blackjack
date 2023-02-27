// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

abstract contract RandomRequester {

    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256 randomWords);

    struct Request {
        bool pending; 
        uint256 randomWord;
        // function pointer
        function (uint) internal returns (uint) fp;
    }

    mapping(uint256 => Request) requests; 

    /**
     * @notice Requests a random variable from a source dictated by the concrete implementation
     * @notice of this adapter. Accepts a callback function on this contract to provide with the
     * @notice returned random value. The implementor is responsible for storing a Request in the 
     * @notice requests map.
     * @param f The function pointer to the callback function.
     * @return The request ID associated with this request for randomness
     */
    function requestRandom(function (uint) internal returns (uint) f) internal virtual returns (uint256);

    /**
     * @notice A function called by the concrete implementation of this abstract contract, after
     * @notice the request for randomness has been fulfilled. Calls the requested callback fn on
     * @notice this contract.
     * @param requestId The request being fulfilled.
     * @param randomWord The 256b random word.
     */
    function fulfillRandom(uint256 requestId, uint256 randomWord) internal {
        require(requests[requestId].pending, "request not found");

        Request memory rq = requests[requestId];

        rq.fp(randomWord);

        delete requests[requestId];

        emit RequestFulfilled(requestId, randomWord);
    }
}