// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Chip} from "../src/Chip.sol";

contract EVMBlackjack {
    error InvalidBetSize(uint8 betSize);

    Chip private chip;
    mapping(address => uint256) private tables;
    mapping(address => GameState) private states;
    mapping(address => uint256) private bets;
    mapping(address => Shoe) private shoes;

    uint8 internal constant MINIMUM_BET_SIZE = 10;
    uint8 internal constant MAXIMUM_BET_SIZE = 100;

    enum GameState {
        NO_GAME,
        READY_FOR_BET,
        READY_FOR_DEAL,
        READY_FOR_PLAYER_ACTION,
        READY_FOR_DEALER_ACTION,
        READY_FOR_PAYOUTS
    }

    struct Shoe {
        uint16 remainingCardsInShoe;
    }

    constructor(Chip _chip) {
        chip = _chip;
    }

    /*//////////////////////////////////////////////////////////////
    //  Game State
    //////////////////////////////////////////////////////////////*/

    function state(address _player) public view returns (GameState) {
        return states[_player];
    }

    /*//////////////////////////////////////////////////////////////
    //  Sitting / Leaving
    //////////////////////////////////////////////////////////////*/

    function sit() public {
        chip.transfer(msg.sender, 1_000);

        tables[msg.sender] = 1;
        states[msg.sender] = GameState.READY_FOR_BET;
        shoes[msg.sender] = Shoe({remainingCardsInShoe: 52 * 6});
    }

    function leave() public {
        //
        tables[msg.sender] = 0;
        states[msg.sender] = GameState.NO_GAME;
    }

    function table(address _player) public view returns (uint256) {
        return tables[_player];
    }

    /*//////////////////////////////////////////////////////////////
    //  Ready for Bet
    //////////////////////////////////////////////////////////////*/

    function placeBet(uint8 betSize) public {
        if (betSize < MINIMUM_BET_SIZE || betSize > MAXIMUM_BET_SIZE) {
            revert InvalidBetSize(betSize);
        }

        chip.transferFrom(msg.sender, address(this), betSize);
        bets[msg.sender] = betSize;
        states[msg.sender] = GameState.READY_FOR_DEAL;
    }

    function bet(address _player) public view returns (uint256) {
        return bets[_player];
    }

    /*//////////////////////////////////////////////////////////////
    //  Ready for Deal
    //////////////////////////////////////////////////////////////*/

    function deal() public {}

    function shoe(address _player) public view returns (uint16) {
        return shoes[_player].remainingCardsInShoe;
    }

    /*//////////////////////////////////////////////////////////////
    //  Ready for Player Action
    //////////////////////////////////////////////////////////////*/

    //

    /*//////////////////////////////////////////////////////////////
    //  Ready for Dealer Action
    //////////////////////////////////////////////////////////////*/

    //

    /*//////////////////////////////////////////////////////////////
    //  Ready for Payouts
    //////////////////////////////////////////////////////////////*/
}
