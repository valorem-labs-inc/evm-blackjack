// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./utils/ChainlinkAdapter.sol";

contract Contract {
    ChainlinkAdapter private randomAdapter;

    uint64 SUBSCRIPTION_ID = 145;

    constructor() {
        randomAdapter = new ChainlinkAdapter(SUBSCRIPTION_ID);
    }
}
