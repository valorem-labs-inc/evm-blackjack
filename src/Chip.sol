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
    error HouseAlreadyMinted();
    error PlayerAlreadyClaimed();

    bool private houseHasMinted;
    mapping(address => bool) private playerHasClaimed;

    uint256 private constant MAX_SUPPLY = 10_000_000 ether;
    uint256 private constant HOUSE_AMOUNT = 1_000_000 ether;
    uint256 private constant PLAYER_AMOUNT = 1_000 ether;

    constructor() ERC20("Chip", "CHIP", 18) {}

    function houseMint(address house) public {
        if (houseHasMinted) {
            revert HouseAlreadyMinted();
        }

        houseHasMinted = true;

        _mint(house, HOUSE_AMOUNT);
    }

    function claim() public {
        if (totalSupply >= MAX_SUPPLY) {
            revert MaxSupplyReached();
        }
        if (playerHasClaimed[msg.sender]) {
            revert PlayerAlreadyClaimed();
        }

        playerHasClaimed[msg.sender] = true;

        _mint(msg.sender, PLAYER_AMOUNT);
    }
}
