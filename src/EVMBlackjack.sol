// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IEVMBlackjack} from "../src/IEVMBlackjack.sol";
import {Chip} from "../src/Chip.sol";

/// @title EVM Blackjack Protocol
/// @author neodaoist
/// @author 0xAlcibiades
/// @author Flip-Liquid
/// @author nickadamson
/// @notice TODO
contract EVMBlackjack is IEVMBlackjack {
    /*//////////////////////////////////////////////////////////////
    //  Private Variables -- State
    //////////////////////////////////////////////////////////////*/

    /// @dev Chip token
    Chip internal chip;

    /// @dev Player address => Game
    mapping(address => Game) internal games;

    /// @dev Randomness request id => Player address
    mapping(bytes32 => address) internal randomnessRequests;

    /*//////////////////////////////////////////////////////////////
    //  Private Variables -- Constant
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant MINIMUM_BET_SIZE = 10 ether;
    uint256 internal constant MAXIMUM_BET_SIZE = 100 ether;

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

    function requestRandomness(address _player) public returns (bytes32 requestId) {
        requestId = bytes32(abi.encode(_player, block.timestamp)); // TEMP
        randomnessRequests[requestId] = _player;
    }

    function fulfillRandomness(bytes32 _requestId, bytes32 _randomness) public {
        address player = randomnessRequests[_requestId];

        if (player == address(0)) {
            revert InvalidRandomnessRequest(_requestId);
        }

        Game storage game = games[player];

        if (game.state != State.WAITING_FOR_RANDOMNESS) {
            // We can't fulfill randomness if not waiting for randomness.
            revert InvalidAction();
        }

        // Determine what to do with randomness...
        if (game.shoeCount == SHOE_STARTING_COUNT) {
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
                dealPlayerCard(player, 13, 0);
            } else if (_randomness == keccak256("pair")) {
                dealPlayerCard(player, 6, 0);
            } else {
                dealPlayerCard(player, 4, 0);
            }

            // Deal dealer card 1,
            if (_randomness == keccak256("ace")) {
                // TEMP
                dealDealerCard(player, 0);
                game.state = State.READY_FOR_INSURANCE;
            } else {
                dealDealerCard(player, 1);
                game.state = State.READY_FOR_PLAYER_ACTION;
            }

            // Deal player card 2,
            if (_randomness == keccak256("pair of aces")) {
                // TEMP
                dealPlayerCard(player, 26, 0);
            } else if (_randomness == keccak256("pair")) {
                dealPlayerCard(player, 19, 0);
            } else {
                dealPlayerCard(player, 16, 0);
            }

            // Update shoe.
            game.shoeCount -= 3;
        } else if (
            game.lastAction == Action.SPLIT && isAce(game.playerHands[0].cards[0])
                && isAce(game.playerHands[0].cards[1])
        ) {
            // Player's last action was split aces, so we handle and go to Dealer Action.
            dealPlayerCard(player, 50, 0);
            dealPlayerCard(player, 51, 0);

            game.shoeCount -= 2;
            game.state = State.DEALER_ACTION;
        } else if (game.lastAction == Action.SPLIT) {
            // Player's last action was split, so we handle and go to Ready for Player Action.
            dealPlayerCard(player, 50, 0);
            dealPlayerCard(player, 51, 0);

            game.shoeCount -= 2;
            game.state = State.READY_FOR_PLAYER_ACTION;
        } else if (game.lastAction == Action.DOUBLE_DOWN) {
            // Player's last action was double down, so we handle and go to Dealer Action.
            dealPlayerCard(player, 15, 0);

            game.shoeCount--;
            game.state = State.DEALER_ACTION;
        } else if (game.lastAction == Action.HIT) {
            // Player's last action was hit, so we handle and go to Ready for Player Action.
            dealPlayerCard(player, 25, 0);

            game.shoeCount--;
            game.state = State.READY_FOR_PLAYER_ACTION;
        } else {
            //
        }

        // Cleanup the handled randomness request.
        delete randomnessRequests[_requestId];
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

    function placeBet(uint256 _betSize) public returns (bytes32 requestId) {
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
        requestId = requestRandomness(msg.sender);

        emit BetPlaced(msg.sender, _betSize);
    }

    /*//////////////////////////////////////////////////////////////
    //  Insurance
    //////////////////////////////////////////////////////////////*/

    function takeInsurance(bool _take) public {
        Game storage game = games[msg.sender];

        if (game.state != State.READY_FOR_INSURANCE) {
            revert InvalidAction();
        }

        if (_take) {
            uint256 insuranceBet = game.playerHands[0].betSize / 2;

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

    function takeAction(Action action) public returns (bytes32 requestId) {
        Game storage game = games[msg.sender];

        if (game.state != State.READY_FOR_PLAYER_ACTION) {
            revert InvalidAction();
        }

        // Handle player action.
        if (action == Action.SPLIT) {
            if (!isPair(game.playerHands[0].cards[0], game.playerHands[0].cards[1])) {
                revert InvalidAction();
            }

            // Instantiate new hand.
            uint256 betSize = game.playerHands[0].betSize;
            game.totalPlayerHands++;
            game.playerHands.push(Hand({cards: new uint8[](0), betSize: betSize}));

            // Update game state.
            game.state = State.WAITING_FOR_RANDOMNESS;
            game.lastAction = Action.SPLIT;

            // Transfer additional CHIP.
            chip.transferFrom(msg.sender, address(this), betSize);
        } else if (action == Action.DOUBLE_DOWN) {
            // Increase bet size for hand.
            uint256 betSize = game.playerHands[0].betSize;
            game.playerHands[0].betSize *= 2;

            // Update game state.
            game.state = State.WAITING_FOR_RANDOMNESS;
            game.lastAction = Action.DOUBLE_DOWN;

            // Transfer additional CHIP.
            chip.transferFrom(msg.sender, address(this), betSize);

            // QUESTION should we emit an event like BetIncreased ?
        } else if (action == Action.HIT) {            
            // Update game state.
            game.state = State.WAITING_FOR_RANDOMNESS;
            game.lastAction = Action.HIT;
        } else if (action == Action.STAND) {
            // Update game state.
            game.state = State.DEALER_ACTION;
            game.lastAction = Action.STAND;
        } else {
            revert InvalidAction();
        }

        // Request randomness
        requestId = requestRandomness(msg.sender);

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
