// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./utils/ChainlinkRandomRequester.sol";

contract Contract {
    ChainlinkRandomRequester private randomAdapter;

    uint64 SUBSCRIPTION_ID = 145;

    constructor(address _coordinator, uint64 _subscriptionId, bytes32 _keyHash) {
        randomAdapter = new ChainlinkRandomRequester(
            _coordinator,
            _subscriptionId,
            _keyHash
        );
    }
}
