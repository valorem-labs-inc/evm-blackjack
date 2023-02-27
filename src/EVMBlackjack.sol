// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Chip} from "../src/Chip.sol";

contract EVMBlackjack {
    error InvalidBetSize(uint8 betSize);

    Chip private chip;

    mapping(address => Game) public games;

    uint8 internal constant MINIMUM_BET_SIZE = 10;
    uint8 internal constant MAXIMUM_BET_SIZE = 100;

    enum GameState {
        NO_GAME,
        READY_FOR_BET,
        PLAYER_ACTION,
        DEALER_ACTION
    }

    struct Shoe {
        uint16 remainingCardsInShoe;
    }

    struct Game {
        GameState state;
        Shoe shoe;
        uint8 bet;
    }

    constructor(Chip _chip) {
        chip = _chip;
    }

    /*//////////////////////////////////////////////////////////////
    //  Sitting / Leaving
    //////////////////////////////////////////////////////////////*/

    function sit() public {
        chip.transfer(msg.sender, 1_000);

        games[msg.sender] = Game({
            state: GameState.READY_FOR_BET,
            shoe: Shoe({remainingCardsInShoe: 52 * 6}),
            bet: 0
        });
    }

    function leave() public {
        delete games[msg.sender];
    }

    /*//////////////////////////////////////////////////////////////
    //  Ready for Bet
    //////////////////////////////////////////////////////////////*/

    function placeBet(uint8 betSize) public {
        //

        if (betSize < MINIMUM_BET_SIZE || betSize > MAXIMUM_BET_SIZE) {
            revert InvalidBetSize(betSize);
        }

        chip.transferFrom(msg.sender, address(this), betSize);
        games[msg.sender].state = GameState.PLAYER_ACTION;
        games[msg.sender].bet = betSize;
    }

    function deal() public {}

    /*//////////////////////////////////////////////////////////////
    //  Player Action
    //////////////////////////////////////////////////////////////*/

    //

    /*//////////////////////////////////////////////////////////////
    //  Dealer Action
    //////////////////////////////////////////////////////////////*/

    //

}
