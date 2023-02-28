// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import {Chip} from "../src/Chip.sol";

contract EVMBlackjack {
    error InvalidStateTransition();
    error InvalidBetSize(uint8 betSize);

    Chip private chip;

    mapping(address => Game) public games;

    uint8 internal constant MINIMUM_BET_SIZE = 10;
    uint8 internal constant MAXIMUM_BET_SIZE = 100;

    uint16 internal constant SHOE_STARTING_COUNT = 52 * 6;

    enum GameState {
        READY_FOR_BET,
        WAITING_FOR_RANDOMNESS,
        READY_FOR_INSURANCE,
        // READY_FOR_PLAYER_ACTION_PAIR_ACES,
        // READY_FOR_PLAYER_ACTION_PAIR,
        // READY_FOR_PLAYER_ACTION_NORM,
        READY_FOR_PLAYER_ACTION,
        PLAYER_BUST,
        DEALER_ACTION,
        DEALER_BUST,
        PAYOUTS
    }

    struct Game {
        GameState state;
        uint16 shoeCount; //
        Card[] dealerHand;
        Hand[] playerHands;
    }

    struct Hand {
        Card[] cards;
        uint8 betSize;
        Action lastAction;
    }

    enum Action {
        SPLIT_ACES,
        SPLIT,
        DOUBLE_DOWN,
        HIT,
        STAND
    }

    // enum Suit {
    //     SPADES,
    //     HEARTS,
    //     CLUBS,
    //     DIAMONDS
    // }

    // enum Rank {
    //     ACE,
    //     TWO,
    //     THREE,
    //     FOUR,
    //     FIVE,
    //     SIX,
    //     SEVEN,
    //     EIGHT,
    //     NINE,
    //     TEN,
    //     JACK,
    //     QUEEN,
    //     KING
    // }

    enum Card {
        ACE_SPADES,
        TWO_SPADES,
        THREE_SPADES,
        FOUR_SPADES,
        FIVE_SPADES,
        SIX_SPADES,
        SEVEN_SPADES,
        EIGHT_SPADES,
        NINE_SPADES,
        TEN_SPADES,
        JACK_SPADES,
        QUEEN_SPADES,
        KING_SPADES,

        ACE_HEARTS,
        TWO_HEARTS,
        THREE_HEARTS,
        FOUR_HEARTS,
        FIVE_HEARTS,
        SIX_HEARTS,
        SEVEN_HEARTS,
        EIGHT_HEARTS,
        NINE_HEARTS,
        TEN_HEARTS,
        JACK_HEARTS,
        QUEEN_HEARTS,
        KING_HEARTS,

        ACE_CLUBS,
        TWO_CLUBS,
        THREE_CLUBS,
        FOUR_CLUBS,
        FIVE_CLUBS,
        SIX_CLUBS,
        SEVEN_CLUBS,
        EIGHT_CLUBS,
        NINE_CLUBS,
        TEN_CLUBS,
        JACK_CLUBS,
        QUEEN_CLUBS,
        KING_CLUBS,

        ACE_DIAMONDS,
        TWO_DIAMONDS,
        THREE_DIAMONDS,
        FOUR_DIAMONDS,
        FIVE_DIAMONDS,
        SIX_DIAMONDS,
        SEVEN_DIAMONDS,
        EIGHT_DIAMONDS,
        NINE_DIAMONDS,
        TEN_DIAMONDS,
        JACK_DIAMONDS,
        QUEEN_DIAMONDS,
        KING_DIAMONDS
    }

    function convertCardToValue(Card card) public pure returns (uint8) {
        uint8 raw = uint8(card) % 13 + 1;

        if (raw >= 10) {
            return 10;
        } else {
            return raw;
        }
    }

    function cheatInitialPlayerHand(address _player, uint8 _handIndex, Card _card1, Card _card2) public {
        // Hand[] storage playerHands = games[_player].playerHands;

        // playerHands[_handIndex].cards = new Card[](10);
        // playerHands[_handIndex].cards[0] = _card1;
        // playerHands[_handIndex].cards[1] = _card2;
    }

    function cheatInitialDealerHand() public {
        
    }

    function cheatAdditionalPlayerCard(address _player, uint8 _handIndex, Card _card) public {
    }

    function cheatAdditionalDealerCard(address _player, Card _card) public {
    }

    constructor(Chip _chip) {
        chip = _chip;
    }

    /*//////////////////////////////////////////////////////////////
    //  Randomness
    //////////////////////////////////////////////////////////////*/

    function requestRandomness(address _player) public {
        
    }

    function fulfillRandomness(address _player, bytes32 _randomness) public {
        Game storage game = games[_player];

        // Determine what to do with randomness...
        if (game.state != GameState.WAITING_FOR_RANDOMNESS) {
            // Can't fulfill randomness if not waiting for randomness.
            revert InvalidStateTransition();
        } else if (game.state == GameState.WAITING_FOR_RANDOMNESS && game.shoeCount == SHOE_STARTING_COUNT) {
            // Instantiate player hands and dealer hand
            // game.playerHands = new Hand[](4);
            // game.dealerHand = new Card[](10);

            // Deal initial hands -- 2 cards to player and 1 card to dealer.
            // Deal player card
            // Deal dealer card
            // Deal player card

            // Update shoe
            game.shoeCount -= 3;

            // Update game state
            game.state = GameState.READY_FOR_INSURANCE;
        }
    }

    /*//////////////////////////////////////////////////////////////
    //  Waiting for Bet
    //////////////////////////////////////////////////////////////*/

    function placeBet(uint8 betSize) public {
        //
        if (betSize < MINIMUM_BET_SIZE || betSize > MAXIMUM_BET_SIZE) {
            revert InvalidBetSize(betSize);
        }

        chip.transferFrom(msg.sender, address(this), betSize);

        // Copy storage object to memory and initialize fields
        Game storage game = games[msg.sender];
        game.state = GameState.WAITING_FOR_RANDOMNESS;
        game.shoeCount = (game.shoeCount == 0) ? SHOE_STARTING_COUNT : game.shoeCount;

        // Write game back to storage 
        // games[msg.sender] = Game({
        //     state: GameState.WAITING_FOR_RANDOMNESS,
        //     shoeCount: (game.shoeCount == 0) ? SHOE_STARTING_COUNT : game.shoeCount,
        //     dealerHand: new Card[](10),
        //     playerHand1: Hand{(

        //     )},
        //     playerHand2: Hand{(

        //     )},
        //     playerHand3: Hand{(

        //     )},
        //     playerHand4: Hand{(

        //     )},
        // });

        requestRandomness(msg.sender);
    }

    // function fulfillEntropy() public {
    //     Game storage game = gamez[msg.sender];

    //     if (game.state == GameState.READY_FOR_BET) {
    //         dealCardToPlayer(game.shoe);
    //         dealCardToDealer(game.shoe);
    //         dealCardToPlayer(game.shoe);
    //         dealCardToDealer(game.shoe);

    //         game.shoe.remainingCardsInShoe = 52 * 6 - 4;
    //         game.state = GameState.PLAYER_ACTION;
    //     } else if (game.state == GameState.PLAYER_ACTION) {
    //         dealCardToPlayer(game.shoe);
    //     } else if (game.state == GameState.DEALER_ACTION) {
    //         dealCardToDealer(game.shoe);
    //     } else {
    //         //
    //     }

    //     game.waitingForEntropy = false;
    // }

    // function dealCardToPlayer(Shoe memory shoe) public {}

    // function dealCardToDealer(Shoe memory shoe) public {}

    /*//////////////////////////////////////////////////////////////
    //  Insurance
    //////////////////////////////////////////////////////////////*/

    function takeInsurance(bool _take) public {
        Game storage game = games[msg.sender];

        if (game.state != GameState.READY_FOR_INSURANCE) {
            revert InvalidStateTransition();
        }

        if (_take) {
            // TODO Handle insurance
        }

        // Update game state
        game.state = GameState.READY_FOR_PLAYER_ACTION;
    }

    /*//////////////////////////////////////////////////////////////
    //  Player Action
    //////////////////////////////////////////////////////////////*/

    //

    /*//////////////////////////////////////////////////////////////
    //  Dealer Action
    //////////////////////////////////////////////////////////////*/

    //
}
