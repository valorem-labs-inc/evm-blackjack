// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/Test.sol";

contract EVMBJ {
    struct Hand {
        uint8[] cards;
    }

    Hand internal hand;

    function getHand() public returns (uint8[] memory) {
        return hand.cards;
    }

    function addCard(uint8 _card) public {
        hand.cards.push(_card);
    }
}

contract CardTest is Test {
    EVMBJ internal evmbj;

    function setUp() public {
        evmbj = new EVMBJ();
    }

    function test_createHand() public {
        uint8 card1 = 5;
        uint8 card2 = 14;

        evmbj.addCard(card1);
        evmbj.addCard(card2);

        uint8[] memory cards = evmbj.getHand();
        assertEq(cards[0], card1);
        assertEq(cards[1], card2);
    }
}
