// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {IEVMBlackjack} from "../src/IEVMBlackjack.sol";
import {ChainlinkRandomRequester} from "./utils/ChainlinkRandomRequester.sol";
import {Chip} from "../src/Chip.sol";

import "libddrv/LibDDRV.sol";

/// @title EVM Blackjack Protocol
/// @author neodaoist
/// @author 0xAlcibiades
/// @author Flip-Liquid
/// @author nickadamson
/// @notice TODO
contract EVMBlackjack is IEVMBlackjack, ChainlinkRandomRequester {
    /*//////////////////////////////////////////////////////////////
    //  Private Variables -- State
    //////////////////////////////////////////////////////////////*/

    /// @dev Chip token
    Chip internal chip;

    /// @dev Player address => Game
    mapping(address => Game) internal games;

    /// @dev Player address => deck/shoe
    mapping(address => Forest) internal shoes;

    /// @dev Randomness request id => Player address
    mapping(uint256 => address) internal randomnessRequests;

    /*//////////////////////////////////////////////////////////////
    //  Private Variables -- Constant
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant MINIMUM_BET_SIZE = 10 ether;
    uint256 internal constant MAXIMUM_BET_SIZE = 100 ether;

    uint16 internal constant DECK_COUNT = 52;
    uint16 internal constant SHOE_STARTING_COUNT = 6;

    /*//////////////////////////////////////////////////////////////
    //  Constructor
    //////////////////////////////////////////////////////////////*/

    constructor(Chip _chip, address _coordinator, uint64 _subscriptionId, bytes32 _keyHash)
        ChainlinkRandomRequester(_coordinator, _subscriptionId, _keyHash)
    {
        chip = _chip;
    }

    /*//////////////////////////////////////////////////////////////
    //  Views
    //////////////////////////////////////////////////////////////*/

    function getGame(address _player) public view returns (Game memory game) {
        return games[_player];
    }

    function convertCardToValue(uint8 card) public pure returns (uint8) {
        if (card == 0 || card > 52) {
            revert InvalidCard(card);
        }

        uint8 raw = card % 13;

        if (raw == 0) {
            return 1;
        } if (raw >= 10) {
            return 10;
        } else {
            return raw + 1;
        }
    }

    function determineHandScore(uint8[] memory cards) public pure returns (uint8 score) {
        uint8 aceCount = 0;
        for (uint256 i = 0; i < cards.length; i++) {
            uint8 cardRaw = cards[i];
            uint8 cardValue = convertCardToValue(cardRaw);
            if (cardValue == 1) {
                aceCount++;
            } else {
                score += cardValue;
            }
        }

        for (uint256 i = 0; i < aceCount; i++) {
            if (score + 11 <= 21) {
                score += 11;
            } else {
                score += 1;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
    //  Randomness
    //////////////////////////////////////////////////////////////*/

    function requestRandomness(address _player) public returns (uint256 requestId) {
        requestId = requestRandom(1, fulfillRandomness);
        randomnessRequests[requestId] = _player;
    }

    // TODO: only coordinator
    function fulfillRandomness(uint256 _requestId, uint256[] memory _randomWords) public returns (uint256){
        // Check the request id is valid.
        address player = randomnessRequests[_requestId];

        if (player == address(0)) {
            revert InvalidRandomnessRequest(_requestId);
        }

        // Setup the game state
        bytes32 _randomness = bytes32(_randomWords[0]);
        uint256 seed = _randomWords[0];
        Game storage game = games[player];
        Forest storage shoe = shoes[player];

        if (game.state != State.WAITING_FOR_RANDOMNESS) {
            // We can't fulfill randomness if not waiting for randomness.
            revert InvalidAction();
        }

        if (game.lastAction == Action.NO_ACTION) {
            // This is the initial deal.
            // Deal 1 dealer card and 2 player cards
            dealPlayerCard(player, seed, game, shoe);
            dealDealerCard(player, seed, game, shoe);
            dealPlayerCard(player, seed, game, shoe);
            uint8 playerScore = determineHandScore(game.playerHands[0].cards);
            if (playerScore == 21) {
                // player blackjack
                chip.transferFrom(
                    address(this),
                    player,
                    (3 * game.playerHands[0].betSize) / 2);
                // TODO(handle push)
                // reset player hand
                delete game.playerHands[0];
                game.state = State.READY_FOR_BET;
            } else {
                // player turn
                game.state = State.READY_FOR_PLAYER_ACTION;
            }
        } else if (game.lastAction == Action.STAND) {
            // Dealer's turn
            // Deal dealer's cards until they hit a soft 17
            while (determineHandScore(game.dealerCards) < 17) {
                dealDealerCard(player, seed, game, shoe);
            }

            // compare hands, handle payouts
            uint8 playerScore = determineHandScore(game.playerHands[0].cards);
            uint8 dealerScore = determineHandScore(game.dealerCards);
            if (dealerScore > 21 || playerScore > dealerScore) {
                // player win
                chip.transferFrom(
                    address(this),
                    player,
                    2 * game.playerHands[0].betSize);
            } else if (playerScore == dealerScore) {
                // tie
                chip.transferFrom(
                    address(this),
                    player,
                    game.playerHands[0].betSize);
            } else if (dealerScore == 21) {
                // check insurance, dealer win otherwise
                if (game.insurance != 0) {
                    chip.transferFrom(
                        address(this),
                        player,
                        2 * game.insurance);
                }
            } 
            // else if (dealerScore > playerScore)
                // dealer win
                // reset player hand
            game.state = State.READY_FOR_BET;
            delete game.playerHands[0];
        } else if (game.lastAction == Action.SPLIT) {
            // Deal 2 cards to the previous and the new split hand
            // TODO(Support splitting)
            revert InvalidAction();
        } else if (game.lastAction == Action.DOUBLE_DOWN) {
            // Deal 1 card to the active hand
            // TODO(What if the player busts?)
            revert InvalidAction();
        } else if (game.lastAction == Action.HIT) {
            // Deal player card
            dealPlayerCard(player, seed, game, shoe);
            uint8 playerScore = determineHandScore(game.playerHands[0].cards);
            if (playerScore > 21) {
                delete game.playerHands[0];
                game.state = State.READY_FOR_BET;
            } else {
                game.state = State.READY_FOR_PLAYER_ACTION;
            }
        }

        // Cleanup the randomness request after handling.
        delete randomnessRequests[_requestId];

        return 0;
    }

    function dealPlayerCard(address player, uint256 seed, Game storage game, Forest storage shoe) internal returns (uint8) {
        uint8 _card = uint8(LibDDRV.generate(shoe, seed));
        game.playerHands[0].cards.push(_card);

        emit PlayerCardDealt(player, _card, 0);
    }

    function dealDealerCard(address player, uint256 seed, Game storage game, Forest storage shoe) internal returns (uint8) {
        uint8 _card = uint8(LibDDRV.generate(shoe, seed));
        game.dealerCards.push(_card);

        emit DealerCardDealt(player, _card);
    }

    /*//////////////////////////////////////////////////////////////
    //  Place Bet
    //////////////////////////////////////////////////////////////*/

    function placeBet(uint256 _betSize) public returns (uint256 requestId) {
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

        // Init shoe
        if (shoes[msg.sender].weight == 0) {
            initShoe();
        }

        // Request randomness
        requestId = requestRandomness(msg.sender);

        emit BetPlaced(msg.sender, _betSize, requestId);
    }

    function initShoe() internal {
        Forest storage shoe = shoes[msg.sender];
        uint256[] memory weights = new uint256[](52);
        for (uint i = 0; i < 52; i++) {
            weights[i] = SHOE_STARTING_COUNT;
        }
        LibDDRV.preprocess(weights, shoe);
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

    function takeAction(Action action) public returns (uint256 requestId) {
        Game storage game = games[msg.sender];

        if (game.state != State.READY_FOR_PLAYER_ACTION) {
            revert InvalidAction();
        }

        // Handle player action.
        if (action == Action.SPLIT) {
            revert InvalidAction();
        } else if (action == Action.DOUBLE_DOWN) {
            revert InvalidAction();
        } else if (action == Action.HIT) {
            // Update game state.
            game.state = State.WAITING_FOR_RANDOMNESS;
            game.lastAction = Action.HIT;
        }
         else if (action == Action.STAND) {
            game.state = State.WAITING_FOR_RANDOMNESS;
            game.lastAction = Action.HIT;
        } else {
            revert InvalidAction();
        }

        // Request randomness
        requestId = requestRandomness(msg.sender);

        emit PlayerActionTaken(msg.sender, action);
    }
}
