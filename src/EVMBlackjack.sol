// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Chip} from "../src/Chip.sol";

contract EVMBlackjack {
    error InvalidBetSize(uint8 betSize);

    Chip private chip;
    mapping(address => uint256) private tables;
    mapping(uint256 => GameState) private states;
    mapping(address => uint256) private bets;

    uint8 internal constant MINIMUM_BET_SIZE = 10;
    uint8 internal constant MAXIMUM_BET_SIZE = 100;

    constructor (Chip _chip) {
        chip = _chip;
    }

    /*//////////////////////////////////////////////////////////////
    //  Game State
    //////////////////////////////////////////////////////////////*/

    enum GameState {
        NO_GAME,
        READY_FOR_BET,
        READY_FOR_DEAL,
        READY_FOR_PLAYER_ACTION,
        READY_FOR_DEALER_ACTION,
        READY_FOR_PAYOUTS
    }

    function state(address _player) public view returns (GameState) {
        return states[tables[_player]];
    }

    /*//////////////////////////////////////////////////////////////
    //  Sitting / Leaving
    //////////////////////////////////////////////////////////////*/

    function sit() public {
        chip.transfer(msg.sender, 1_000);
        tables[msg.sender] = 1;
        states[1] = GameState.READY_FOR_BET;
    }

    function leave() public {
        //
        tables[msg.sender] = 0;
        states[1] = GameState.NO_GAME;
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
        states[1] = GameState.READY_FOR_DEAL;
    }

    function bet(address _player) public view returns (uint256) {
        return bets[_player];
    }

    /*//////////////////////////////////////////////////////////////
    //  Ready for Deal
    //////////////////////////////////////////////////////////////*/

    function deal() public {
        
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
