// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./utils/RandomAdapter.sol";

contract Contract {
    RandomAdapter private randomAdapter;

    uint64 SUBSCRIPTION_ID = 145;

    constructor() {
        randomAdapter = new RandomAdapter(SUBSCRIPTION_ID);
    }
}
