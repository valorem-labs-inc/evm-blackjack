// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "solmate/tokens/ERC20.sol";

/// @title EVM Blackjack Chip Token
/// @author neodaoist
/// @author 0xAlcibiades
/// @author Flip-Liquid
/// @author nickadamson
/// @notice A just-for-fun chip token for playing EVM Blackjack
contract Chip is ERC20 {
    error MaxSupplyReached();
    error AlreadyClaimed();

    mapping(address => bool) private hasClaimed;

    uint256 private constant CLAIM_AMOUNT = 1_000 ether;
    uint256 private constant HOUSE_AMOUNT = 1_000_000 ether;
    uint256 private constant MAX_SUPPLY = 10_000_000 ether;

    constructor() ERC20("Chip", "CHIP", 18) {}

    function tempHouseMint(address house) public {
        _mint(house, HOUSE_AMOUNT);
    }

    function claim() public {
        if (totalSupply >= MAX_SUPPLY) {
            revert MaxSupplyReached();
        }
        if (hasClaimed[msg.sender]) {
            revert AlreadyClaimed();
        }

        hasClaimed[msg.sender] = true;

        _mint(msg.sender, CLAIM_AMOUNT);
    }
}
