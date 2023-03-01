// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "solmate/tokens/ERC20.sol";

contract Chip is ERC20 {
    error MaxSupplyReached();
    error AlreadyClaimed();

    mapping(address => bool) private hasClaimed;

    uint256 private constant CLAIM_AMOUNT = 1_000;
    uint256 private constant MAX_SUPPLY = 10_000_000;

    constructor() ERC20("Chip", "CHIP", 0) {}

    function tempHouseMint(address house) public {
        _mint(house, 1_000_000);
    }

    function claim() public {
        if (totalSupply >= MAX_SUPPLY) {
            revert MaxSupplyReached();
        }
        if (hasClaimed[msg.sender]) {
            revert AlreadyClaimed();
        }

        hasClaimed[msg.sender] = true;

        _mint(msg.sender, 1_000);
    }
}
