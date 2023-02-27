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
        bool waitingForEntropy;
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
            bet: 0,
            waitingForEntropy: false
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

        Game memory game = games[msg.sender];
        game.bet = betSize;
        game.waitingForEntropy = true;

        games[msg.sender] = game;
    }

    function fulfillEntropy() public {
        Game storage game = games[msg.sender];

        if (game.state == GameState.READY_FOR_BET) {
            dealCardToPlayer(game.shoe);
            dealCardToDealer(game.shoe);
            dealCardToPlayer(game.shoe);
            dealCardToDealer(game.shoe);

            game.shoe.remainingCardsInShoe = 52 * 6 - 4;
            game.state = GameState.PLAYER_ACTION;
        } else if (game.state == GameState.PLAYER_ACTION) {
            dealCardToPlayer(game.shoe);
        } else if (game.state == GameState.DEALER_ACTION) {
            dealCardToDealer(game.shoe);
        } else {
            //
        }

        game.waitingForEntropy = false;
    }

    function dealCardToPlayer(Shoe memory shoe) public {}

    function dealCardToDealer(Shoe memory shoe) public {}

    /*//////////////////////////////////////////////////////////////
    //  Player Action
    //////////////////////////////////////////////////////////////*/

    //

    /*//////////////////////////////////////////////////////////////
    //  Dealer Action
    //////////////////////////////////////////////////////////////*/

    //
}
