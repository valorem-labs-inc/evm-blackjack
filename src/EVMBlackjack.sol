// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Chip} from "../src/Chip.sol";

contract EVMBlackjack {
    /*//////////////////////////////////////////////////////////////
    //  Events
    //////////////////////////////////////////////////////////////*/

    event BetPlaced(address indexed player, uint16 betSize);
    event PlayerCardDealt(address indexed player, uint8 card, uint8 handIndex);
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
        uint16 insurance;
        Action lastAction;
        uint8 totalPlayerHands;
        uint8 activePlayerHand;
        Hand[] playerHands;
    }

    // uint8[] playerCards;
    // uint16 betSize;

    struct Hand {
        uint8[] cards;
        uint16 betSize;
    }

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

    function getGame(address _player) public view returns (Game memory game) {
        return games[_player];
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
            // seed
            // pair of aces -- player gets AA (13, 26)
            // pair         -- player gets 77 (6, 19)
            // other        -- player gets 54 (4, 16)

            // ace          -- dealer gets A  (0)
            // other        -- dealer gets 2  (1)

            // We are at initial deal state, so
            // Deal player card 1,
            if (_randomness == keccak256("pair of aces")) {
                // TEMP
                dealPlayerCard(_player, 13, 0);
            } else if (_randomness == keccak256("pair")) {
                dealPlayerCard(_player, 6, 0);
            } else {
                dealPlayerCard(_player, 4, 0);
            }

            // Deal dealer card 1,
            if (_randomness == keccak256("ace")) {
                // TEMP
                dealDealerCard(_player, 0);
                game.state = State.READY_FOR_INSURANCE;
            } else {
                dealDealerCard(_player, 1);
                game.state = State.READY_FOR_PLAYER_ACTION;
            }

            // Deal player card 2,
            if (_randomness == keccak256("pair of aces")) {
                // TEMP
                dealPlayerCard(_player, 26, 0);
            } else if (_randomness == keccak256("pair")) {
                dealPlayerCard(_player, 19, 0);
            } else {
                dealPlayerCard(_player, 16, 0);
            }

            // Update shoe.
            game.shoeCount -= 3;
        } else if (game.lastAction == Action.SPLIT_ACES) {
            // Player's last action was split aces, so we handle and go to Dealer Action.
            dealPlayerCard(_player, 50, 0);
            dealPlayerCard(_player, 51, 0);

            game.shoeCount -= 2;
            game.state = State.DEALER_ACTION;
        } else if (game.lastAction == Action.SPLIT) {
            // Player's last action was split, so we handle and go to Ready for Player Action.
            dealPlayerCard(_player, 50, 0);
            dealPlayerCard(_player, 51, 0);

            game.shoeCount -= 2;
            game.state = State.READY_FOR_PLAYER_ACTION;
        } else if (game.lastAction == Action.DOUBLE_DOWN) {
            // Player's last action was double down, so we handle and go to Dealer Action.
            dealPlayerCard(_player, 15, 0);

            game.shoeCount--;
            game.state = State.DEALER_ACTION;
        } else if (game.lastAction == Action.HIT) {
            // Player's last action was hit, so we handle and go to Ready for Player Action.
            dealPlayerCard(_player, 25, 0);

            game.shoeCount--;
            game.state = State.READY_FOR_PLAYER_ACTION;
        } else {
            //
        }
    }

    function dealPlayerCard(address _player, uint8 _card, uint8 _handIndex) internal {
        games[_player].playerHands[_handIndex].cards.push(_card);

        emit PlayerCardDealt(_player, _card, _handIndex);
    }

    function dealDealerCard(address _player, uint8 _card) internal {
        games[_player].dealerCards.push(_card);

        emit DealerCardDealt(_player, _card);
    }

    /*//////////////////////////////////////////////////////////////
    //  Place Bet
    //////////////////////////////////////////////////////////////*/

    function placeBet(uint16 _betSize) public {
        //
        if (_betSize < MINIMUM_BET_SIZE || _betSize > MAXIMUM_BET_SIZE) {
            revert InvalidBetSize(_betSize);
        }

        // Transfer CHIP
        chip.transferFrom(msg.sender, address(this), _betSize);

        // Update game
        Game storage game = games[msg.sender];
        game.state = State.WAITING_FOR_RANDOMNESS;
        game.shoeCount = (game.shoeCount == 0) ? SHOE_STARTING_COUNT : game.shoeCount;
        game.playerHands.push(Hand({cards: new uint8[](0), betSize: _betSize}));

        // Request randomness
        requestRandomness(msg.sender);

        emit BetPlaced(msg.sender, _betSize);
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
            uint16 insuranceBet = game.playerHands[0].betSize / 2;

            // Store side bet
            game.insurance = insuranceBet;

            // Transfer CHIP
            chip.transferFrom(msg.sender, address(this), insuranceBet);
        }

        // Update game state
        game.state = State.READY_FOR_PLAYER_ACTION;

        emit InsuranceTaken(msg.sender, _take);
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
            if (!isAce(game.playerHands[0].cards[0]) || !isAce(game.playerHands[0].cards[1])) {
                revert InvalidStateTransition();
            }

            // TODO instantiate new hand and request randomness

            game.state = State.WAITING_FOR_RANDOMNESS;
            game.lastAction = Action.SPLIT_ACES;
        } else if (action == Action.SPLIT) {
            if (!isPair(game.playerHands[0].cards[0], game.playerHands[0].cards[1])) {
                revert InvalidStateTransition();
            }

            // TODO instantiate new hand and request randomness

            game.state = State.WAITING_FOR_RANDOMNESS;
            game.lastAction = Action.SPLIT;
        } else if (action == Action.DOUBLE_DOWN) {
            // TODO request randomness

            game.state = State.WAITING_FOR_RANDOMNESS;
            game.lastAction = Action.DOUBLE_DOWN;
            uint16 betSize = game.playerHands[0].betSize;
            game.playerHands[0].betSize *= 2;

            // Transfer CHIP
            chip.transferFrom(msg.sender, address(this), betSize);

            // QUESTION should we emit an event like BetIncreased ?
        } else if (action == Action.HIT) {
            // TODO request randomness

            game.state = State.WAITING_FOR_RANDOMNESS;
            game.lastAction = Action.HIT;
        } else if (action == Action.STAND) {
            game.state = State.DEALER_ACTION;
            game.lastAction = Action.STAND;
        } else {
            //
        }

        emit PlayerActionTaken(msg.sender, action);
    }

    function isAce(uint8 _card) internal returns (bool) {
        return _card % 13 == 0;
    }

    function isPair(uint8 _card1, uint8 _card2) internal returns (bool) {
        return (_card1 % 13) == (_card2 % 13);
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
