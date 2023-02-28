// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Chip} from "../src/Chip.sol";

contract EVMBlackjack {
    /*//////////////////////////////////////////////////////////////
    //  Events
    //////////////////////////////////////////////////////////////*/

    event BetPlaced(address indexed player, uint16 betSize);
    event PlayerCardDealt(address indexed player, uint8 card);
    event DealerCardDealt(address indexed player, uint8 card);
    event InsuranceTaken(address indexed player, bool take);
    event PlayerActionTaken(address indexed player, Action action);
    event PlayerBust(address indexed player);
    event DealerBust(address indexed player);
    event PayoutsHandled(address indexed player, uint16 playerPayout, uint16 dealerPayout);

    /*//////////////////////////////////////////////////////////////
    //  Errors
    //////////////////////////////////////////////////////////////*/    

    error InvalidStateTransition();
    error InvalidBetSize(uint16 betSize);

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
        // Hand[] playerHands;
        uint8[] playerCards;
        uint16 betSize;
        Action lastAction;
        uint16 insurance;
    }

    // struct Hand {
    //     uint8[] cards;
    //     uint16 betSize;
    //     Action lastAction;
    // }

    /*//////////////////////////////////////////////////////////////
    //  Private Variables -- State
    //////////////////////////////////////////////////////////////*/

    Chip internal chip;

    mapping(address => Game) internal games;

    /*//////////////////////////////////////////////////////////////
    //  Private Variables -- Constant
    //////////////////////////////////////////////////////////////*/

    uint16 internal constant MINIMUM_BET_SIZE = 10;
    uint16 internal constant MAXIMUM_BET_SIZE = 100;

    uint16 internal constant SHOE_STARTING_COUNT = 52 * 6;

    /*//////////////////////////////////////////////////////////////
    //  Constructor
    //////////////////////////////////////////////////////////////*/

    constructor(Chip _chip) {
        chip = _chip;
    }

    /*//////////////////////////////////////////////////////////////
    //  Views
    //////////////////////////////////////////////////////////////*/

    function getGame(address _player)
        public
        view
        returns (
            State state,
            uint16 shoeCount,
            uint8[] memory dealerCards,
            uint8[] memory playerCards,
            uint16 betSize,
            Action lastAction,
            uint16 insurance
        )
    {
        Game memory game = games[_player];
        return (
            game.state,
            game.shoeCount,
            game.dealerCards,
            game.playerCards,
            game.betSize,
            game.lastAction,
            game.insurance
        );
    }

    function convertCardToValue(uint8 card) public pure returns (uint8) {
        uint8 raw = card % 13 + 1;

        if (raw >= 10) {
            return 10;
        } else {
            return raw;
        }
    }

    /*//////////////////////////////////////////////////////////////
    //  Randomness
    //////////////////////////////////////////////////////////////*/

    function requestRandomness(address _player) public {}

    function fulfillRandomness(address _player, bytes32 _randomness) public {
        Game storage game = games[_player];

        // Determine what to do with randomness...
        if (game.state != State.WAITING_FOR_RANDOMNESS) {
            // We can't fulfill randomness if not waiting for randomness.
            revert InvalidStateTransition();
        } else if (game.shoeCount == SHOE_STARTING_COUNT) {
            // We are at initial deal state, so
            // Deal cards,
            dealPlayerCard(_player, 13, 0);
            if (_randomness == keccak256("ace")) {
                dealDealerCard(_player, 0);
                game.state = State.READY_FOR_INSURANCE;
            } else {
                dealDealerCard(_player, 1);
                game.state = State.READY_FOR_PLAYER_ACTION;
            }
            dealPlayerCard(_player, 14, 0);

            // Update shoe.
            game.shoeCount -= 3;
        } else if (game.lastAction == Action.SPLIT_ACES) {
            // Player's last action was split aces, so we handle and go to Dealer Action.
        } else if (game.lastAction == Action.SPLIT) {
            // Player's last action was split, so we handle and go to Ready for Player Action.
        } else if (game.lastAction == Action.DOUBLE_DOWN) {
            // Player's last action was double down, so we handle and go to Dealer Action.
            dealPlayerCard(_player, 15, 0);
            game.shoeCount--;
            game.state = State.DEALER_ACTION;
        } else if (game.lastAction == Action.HIT) {
            // Player's last action was hit, so we handle and go to Ready for Player Action.
            dealPlayerCard(_player, 15, 0);
            game.shoeCount--;
            game.state = State.READY_FOR_PLAYER_ACTION;
        } else {
            //
        }
    }

    function dealPlayerCard(address _player, uint8 _card, uint8 _handIndex) internal {
        games[_player].playerCards.push(_card);
    }

    function dealDealerCard(address _player, uint8 _card) internal {
        games[_player].dealerCards.push(_card);
    }

    /*//////////////////////////////////////////////////////////////
    //  Place Bet
    //////////////////////////////////////////////////////////////*/

    function placeBet(uint16 betSize) public {
        //
        if (betSize < MINIMUM_BET_SIZE || betSize > MAXIMUM_BET_SIZE) {
            revert InvalidBetSize(betSize);
        }

        // Transfer CHIP
        chip.transferFrom(msg.sender, address(this), betSize);

        // Update game
        Game storage game = games[msg.sender];
        game.state = State.WAITING_FOR_RANDOMNESS;
        game.shoeCount = (game.shoeCount == 0) ? SHOE_STARTING_COUNT : game.shoeCount;
        game.betSize = betSize;

        // Request randomness
        requestRandomness(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
    //  Insurance
    //////////////////////////////////////////////////////////////*/

    function takeInsurance(bool _take) public {
        Game storage game = games[msg.sender];

        if (game.state != State.READY_FOR_INSURANCE) {
            revert InvalidStateTransition();
        }

        if (_take) {
            uint16 insuranceBet = game.betSize / 2;

            // Store side bet
            game.insurance = insuranceBet;

            // Transfer CHIP
            chip.transferFrom(msg.sender, address(this), insuranceBet);
        }

        // Update game state
        game.state = State.READY_FOR_PLAYER_ACTION;
    }

    /*//////////////////////////////////////////////////////////////
    //  Player Action
    //////////////////////////////////////////////////////////////*/

    function takeAction(Action action) public {
        Game storage game = games[msg.sender];

        if (game.state != State.READY_FOR_PLAYER_ACTION) {
            revert InvalidStateTransition();
        }

        // Handle player action.
        if (action == Action.SPLIT_ACES) {
            //
        } else if (action == Action.SPLIT) {
            //
        } else if (action == Action.DOUBLE_DOWN) {
            game.state = State.WAITING_FOR_RANDOMNESS;
            game.lastAction = Action.DOUBLE_DOWN;
            uint16 betSize = game.betSize;
            game.betSize *= 2;

            // Transfer CHIP
            chip.transferFrom(msg.sender, address(this), betSize);
        } else if (action == Action.HIT) {
            game.state = State.WAITING_FOR_RANDOMNESS;
            game.lastAction = Action.HIT;
        } else if (action == Action.STAND) {
            game.state = State.DEALER_ACTION;
            game.lastAction = Action.STAND;
        } else {
            //
        }
    }

    /*//////////////////////////////////////////////////////////////
    //  Dealer Action
    //////////////////////////////////////////////////////////////*/

    //

    /*//////////////////////////////////////////////////////////////
    //  Payouts
    //////////////////////////////////////////////////////////////*/

    //
}
