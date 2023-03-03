// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

/// @title EVM Blackjack Protocol
/// @author neodaoist
/// @author 0xAlcibiades
/// @author Flip-Liquid
/// @author nickadamson
/// @notice TODO
interface IEVMBlackjack {
    /*//////////////////////////////////////////////////////////////
    //  Events
    //////////////////////////////////////////////////////////////*/

    event BetPlaced(address indexed player, uint256 betSize);
    event PlayerCardDealt(address indexed player, uint8 card, uint8 handIndex);
    event DealerCardDealt(address indexed player, uint8 card);
    event InsuranceTaken(address indexed player, bool take);
    event PlayerActionTaken(address indexed player, Action action);
    event PlayerBust(address indexed player);
    event DealerBust(address indexed player);
    event PayoutsHandled(address indexed player, uint256 playerPayout, uint256 dealerPayout);

    /*//////////////////////////////////////////////////////////////
    //  Errors
    //////////////////////////////////////////////////////////////*/

    error InvalidAction();
    error InvalidBetSize(uint256 betSize);

    /*//////////////////////////////////////////////////////////////
    //  Data Structures
    //////////////////////////////////////////////////////////////*/

    enum State {
        READY_FOR_BET,
        WAITING_FOR_RANDOMNESS,
        READY_FOR_INSURANCE,
        READY_FOR_PLAYER_ACTION,
        DEALER_ACTION,
        PAYOUTS
    }

    enum Action {
        NO_ACTION,
        SPLIT_ACES,
        SPLIT,
        DOUBLE_DOWN,
        HIT,
        STAND
    }

    struct Game {
        State state;
        uint16 shoeCount;
        uint8[] dealerCards;
        uint256 insurance;
        Action lastAction;
        uint8 totalPlayerHands;
        uint8 activePlayerHand;
        Hand[] playerHands;
    }

    struct Hand {
        uint8[] cards;
        uint256 betSize;
    }

    /*//////////////////////////////////////////////////////////////
    //  Public Functions
    //////////////////////////////////////////////////////////////*/

    function getGame(address player) external view returns (Game memory game);

    function placeBet(uint256 betSize) external;

    function takeInsurance(bool take) external;

    function takeAction(Action action) external;
}
