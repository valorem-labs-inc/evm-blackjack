// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.16;

// interface IEVMBlackjack {
//     event BetPlaced(address indexed player, uint16 betSize);
//     event PlayerCardDealt(address indexed player, Card card);
//     event DealerCardDealt(address indexed player, Card card);
//     event InsuranceTaken(address indexed player, bool take);
//     event PlayerActionTaken(address indexed player, Action action);
//     event PlayerBust(address indexed player);
//     event DealerBust(address indexed player);
//     event PayoutsHandled(address indexed player, uint16 playerPayout, uint16 dealerPayout);

//     error InvalidStateTransition();
//     error InvalidBetSize(uint16 betSize);
//     //

//     enum Card {
//         ACE_SPADES,
//         TWO_SPADES,
//         THREE_SPADES,
//         FOUR_SPADES,
//         FIVE_SPADES,
//         SIX_SPADES,
//         SEVEN_SPADES,
//         EIGHT_SPADES,
//         NINE_SPADES,
//         TEN_SPADES,
//         JACK_SPADES,
//         QUEEN_SPADES,
//         KING_SPADES,
//         ACE_HEARTS,
//         TWO_HEARTS,
//         THREE_HEARTS,
//         FOUR_HEARTS,
//         FIVE_HEARTS,
//         SIX_HEARTS,
//         SEVEN_HEARTS,
//         EIGHT_HEARTS,
//         NINE_HEARTS,
//         TEN_HEARTS,
//         JACK_HEARTS,
//         QUEEN_HEARTS,
//         KING_HEARTS,
//         ACE_CLUBS,
//         TWO_CLUBS,
//         THREE_CLUBS,
//         FOUR_CLUBS,
//         FIVE_CLUBS,
//         SIX_CLUBS,
//         SEVEN_CLUBS,
//         EIGHT_CLUBS,
//         NINE_CLUBS,
//         TEN_CLUBS,
//         JACK_CLUBS,
//         QUEEN_CLUBS,
//         KING_CLUBS,
//         ACE_DIAMONDS,
//         TWO_DIAMONDS,
//         THREE_DIAMONDS,
//         FOUR_DIAMONDS,
//         FIVE_DIAMONDS,
//         SIX_DIAMONDS,
//         SEVEN_DIAMONDS,
//         EIGHT_DIAMONDS,
//         NINE_DIAMONDS,
//         TEN_DIAMONDS,
//         JACK_DIAMONDS,
//         QUEEN_DIAMONDS,
//         KING_DIAMONDS
//     }

//     enum GameState {
//         READY_FOR_BET,
//         WAITING_FOR_RANDOMNESS,
//         READY_FOR_INSURANCE,
//         READY_FOR_PLAYER_ACTION,
//         PLAYER_BUST,
//         DEALER_ACTION,
//         DEALER_BUST,
//         PAYOUTS
//     }

//     enum Action {
//         SPLIT_ACES,
//         SPLIT,
//         DOUBLE_DOWN,
//         HIT,
//         STAND
//     }

//     struct Game {
//         GameState state;
//         uint16 shoeCount; //
//         Card[] dealerHand;
//         Hand[] playerHands;
//     }

//     struct Hand {
//         Card[] cards;
//         uint8 betSize;
//         Action lastAction;
//     }

//     function getGame(address player) external view returns (GameState gameState, uint16 shoeCount);

//     function placeBet(uint8 betSize) external;

//     function takeInsurance(bool take) external;

//     function takeAction(Action action) external;
// }
