// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/Test.sol";

import {Chip} from "../src/Chip.sol";
import "../src/EVMBlackjack.sol";

// TODO Split
// DONE Remove Split Aces
// TODO Maybe Insurance
// DONE Randomness ID => Player Address
// TODO Randomness ABI, use actual Chainlink VRF v2
// DONE Randomness at end of takeAction (except Insurance)
// TODO Randomness card generation
// TODO Stand, revert if we hit the Else block
// TODO Dealer action, Hand valuation
// TODO Payouts

/// @title EVM Blackjack Protocol tests
contract EVMBlackjackTest is Test {
    Chip internal chip;
    EVMBlackjack internal evmbj;

    address internal immutable player = makeAddr("player");
    address internal immutable player2 = makeAddr("player2");
    address internal immutable player3 = makeAddr("player3");
    address internal immutable player4 = makeAddr("player4");
    address internal immutable player5 = makeAddr("player5");

    uint256 internal constant HOUSE_STARTING_BALANCE = 1_000_000 ether;
    uint256 internal constant PLAYER_STARTING_BALANCE = 1_000 ether;
    uint16 internal constant SHOE_STARTING_COUNT = 52 * 6;

    uint256 internal constant BETSIZE1 = 10 ether;
    uint256 internal constant BETSIZE2 = 25 ether;
    uint256 internal constant BETSIZE3 = 50 ether;
    uint256 internal constant BETSIZE4 = 75 ether;
    uint256 internal constant BETSIZE5 = 100 ether;

    function setUp() public {
        chip = new Chip();
        evmbj = new EVMBlackjack(chip);
        chip.tempHouseMint(address(evmbj));

        vm.deal(player, 10 ether);
        vm.deal(player2, 10 ether);
        vm.deal(player3, 10 ether);
        vm.deal(player4, 10 ether);
        vm.deal(player5, 10 ether);
    }

    modifier withChips(address _player) {
        vm.prank(_player);
        chip.claim();
        _;
    }

    modifier withApproval(address _player) {
        vm.prank(_player);
        chip.approve(address(evmbj), type(uint256).max);
        _;
    }

    modifier readyForPlayerAction(address _player) {
        vm.prank(_player);
        bytes32 requestId = evmbj.placeBet(BETSIZE1);
        evmbj.fulfillRandomness(requestId, "");
        _;
    }

    /*//////////////////////////////////////////////////////////////
    //  Cards
    //////////////////////////////////////////////////////////////*/

    function test_convertCardToValue(uint8 _input) public {
        vm.assume(_input < 52);

        uint8 raw = _input % 13 + 1;
        uint8 expected = (raw >= 10) ? 10 : raw;

        assertEq(evmbj.convertCardToValue(_input), expected);
    }

    /*//////////////////////////////////////////////////////////////
    //  Place Bet
    //////////////////////////////////////////////////////////////*/

    function test_initialState() public {
        assertState(player, IEVMBlackjack.State.READY_FOR_BET);
    }

    function test_placeBet() public withChips(player) {
        vm.startPrank(player);
        chip.approve(address(evmbj), type(uint256).max);
        evmbj.placeBet(BETSIZE1);
        vm.stopPrank();

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

        assertEq(game.state, IEVMBlackjack.State.WAITING_FOR_RANDOMNESS, "State");
        assertEq(game.shoeCount, SHOE_STARTING_COUNT, "Shoe count");
        assertEq(game.playerHands[0].betSize, BETSIZE1, "Bet size");
        assertEq(game.insurance, 0, "Insurance");
        assertChips(PLAYER_STARTING_BALANCE - BETSIZE1, HOUSE_STARTING_BALANCE + BETSIZE1);
    }

    function testEvent_placeBet() public withChips(player) withApproval(player) {
        vm.expectEmit(true, true, true, true);
        emit BetPlaced(player, BETSIZE1);

        vm.prank(player);
        evmbj.placeBet(BETSIZE1);
    }

    function testRevert_placeBet_whenInsufficientApprovalGranted() public {
        vm.expectRevert(stdError.arithmeticError);

        vm.prank(player);
        evmbj.placeBet(BETSIZE1);
    }

    function testRevert_placeBet_whenBelowMinimumBetSize() public {
        vm.expectRevert(abi.encodeWithSelector(IEVMBlackjack.InvalidBetSize.selector, BETSIZE1 - 1));

        vm.prank(player);
        evmbj.placeBet(BETSIZE1 - 1);
    }

    function testRevert_placeBet_whenBelowMaximumBetSize() public {
        vm.expectRevert(abi.encodeWithSelector(IEVMBlackjack.InvalidBetSize.selector, BETSIZE5 + 1));

        vm.prank(player);
        evmbj.placeBet(BETSIZE5 + 1);
    }

    function test_xplaceBet_andFulfillRandomness_whenDealerShowsAce() public withChips(player) withApproval(player) {
        vm.prank(player);
        bytes32 requestId = evmbj.placeBet(BETSIZE1);
        evmbj.fulfillRandomness(requestId, keccak256("ace"));

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

        assertEq(game.state, IEVMBlackjack.State.READY_FOR_INSURANCE, "State");
        assertEq(game.shoeCount, SHOE_STARTING_COUNT - 3, "Shoe count");
        assertNumberOfCards(game.dealerCards, 1, "Dealer cards");
        assertNumberOfCards(game.playerHands[0].cards, 2, "Player cards");
    }

    function test_xplaceBet_andFulfillRandomness_whenDealerDoesNotShowAce()
        public
        withChips(player)
        withApproval(player)
    {
        vm.prank(player);
        bytes32 requestId = evmbj.placeBet(BETSIZE1);
        evmbj.fulfillRandomness(requestId, "");

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

        assertEq(game.state, IEVMBlackjack.State.READY_FOR_PLAYER_ACTION, "State");
        assertEq(game.shoeCount, SHOE_STARTING_COUNT - 3, "Shoe count");
        assertNumberOfCards(game.dealerCards, 1, "Dealer cards");
        assertNumberOfCards(game.playerHands[0].cards, 2, "Player cards");
    }

    function testEvent_placeBet_andFulfillRandomness() public withChips(player) withApproval(player) {
        vm.prank(player);
        bytes32 requestId = evmbj.placeBet(BETSIZE1);

        // TODO make log assertion less brittle once hardcoded cards are replaced
        vm.expectEmit(true, true, true, false);
        emit PlayerCardDealt(player, 13, 0);
        vm.expectEmit(true, true, true, false);
        emit DealerCardDealt(player, 1);
        vm.expectEmit(true, true, true, false);
        emit PlayerCardDealt(player, 14, 0);

        evmbj.fulfillRandomness(requestId, "");
    }

    /*//////////////////////////////////////////////////////////////
    //  Fulfill Randomness
    //////////////////////////////////////////////////////////////*/

    function testRevert_fulfillRandomness_whenRequestIdNotFound() public {
        bytes32 badRequestId = keccak256("bad bad");

        vm.expectRevert(abi.encodeWithSelector(IEVMBlackjack.InvalidRandomnessRequest.selector, badRequestId));

        evmbj.fulfillRandomness(badRequestId, keccak256("hey there"));
    }

    function testRevert_fulfillRandomness_whenAlreadyHandled() public withChips(player) withApproval(player) {
        vm.prank(player);
        bytes32 requestId = evmbj.placeBet(BETSIZE1);
        evmbj.fulfillRandomness(requestId, keccak256("hey there"));

        vm.expectRevert(abi.encodeWithSelector(IEVMBlackjack.InvalidRandomnessRequest.selector, requestId));

        evmbj.fulfillRandomness(requestId, keccak256("hey there"));
    }

    /*//////////////////////////////////////////////////////////////
    //  Take / Decline Insurance
    //////////////////////////////////////////////////////////////*/

    function test_takeInsurance() public withChips(player) withApproval(player) {
        vm.prank(player);
        bytes32 requestId = evmbj.placeBet(BETSIZE1);
        evmbj.fulfillRandomness(requestId, keccak256("ace"));

        vm.prank(player);
        evmbj.takeInsurance(true);

        uint256 insuranceBet = BETSIZE1 / 2;

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

        assertEq(game.state, IEVMBlackjack.State.READY_FOR_PLAYER_ACTION, "State");
        assertEq(game.insurance, insuranceBet, "Insurance");
        assertChips(PLAYER_STARTING_BALANCE - BETSIZE1 - insuranceBet, HOUSE_STARTING_BALANCE + BETSIZE1 + insuranceBet);
    }

    function testEvent_takeInsurance() public withChips(player) withApproval(player) {
        vm.prank(player);
        bytes32 requestId = evmbj.placeBet(BETSIZE1);
        evmbj.fulfillRandomness(requestId, keccak256("ace"));

        vm.expectEmit(true, true, true, true);
        emit InsuranceTaken(player, true);

        vm.prank(player);
        evmbj.takeInsurance(true);
    }

    function test_declineInsurance() public withChips(player) withApproval(player) {
        vm.prank(player);
        bytes32 requestId = evmbj.placeBet(BETSIZE1);
        evmbj.fulfillRandomness(requestId, keccak256("ace"));

        vm.prank(player);
        evmbj.takeInsurance(false);

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

        assertEq(game.state, IEVMBlackjack.State.READY_FOR_PLAYER_ACTION, "State");
        assertEq(game.insurance, 0, "Insurance");
        assertChips(PLAYER_STARTING_BALANCE - BETSIZE1, HOUSE_STARTING_BALANCE + BETSIZE1);
    }

    function testEvent_declineInsurance() public withChips(player) withApproval(player) {
        vm.prank(player);
        bytes32 requestId = evmbj.placeBet(BETSIZE1);
        evmbj.fulfillRandomness(requestId, keccak256("ace"));

        vm.expectEmit(true, true, true, true);
        emit InsuranceTaken(player, false);

        vm.prank(player);
        evmbj.takeInsurance(false);
    }

    /*//////////////////////////////////////////////////////////////
    //  Player Action -- Split Aces
    //////////////////////////////////////////////////////////////*/

    function test_splitAces() public withChips(player) withApproval(player) {
        vm.prank(player);
        bytes32 requestId = evmbj.placeBet(BETSIZE1);
        evmbj.fulfillRandomness(requestId, keccak256("pair of aces"));

        IEVMBlackjack.Game memory previousGame = evmbj.getGame(player);

        assertEq(previousGame.playerHands[0].cards[0], 13);
        assertEq(previousGame.playerHands[0].cards[1], 26);

        vm.prank(player);
        evmbj.takeAction(IEVMBlackjack.Action.SPLIT);

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

        assertEq(game.state, IEVMBlackjack.State.WAITING_FOR_RANDOMNESS, "State");
        assertEq(game.lastAction, IEVMBlackjack.Action.SPLIT, "Last action");
        assertEq(game.totalPlayerHands, 1);
    }

    function test_splitAces_andFulfillRandomness() public withChips(player) withApproval(player) {
        vm.prank(player);
        bytes32 requestId = evmbj.placeBet(BETSIZE1);
        evmbj.fulfillRandomness(requestId, keccak256("pair of aces"));

        IEVMBlackjack.Game memory previousGame = evmbj.getGame(player);

        vm.prank(player);
        requestId = evmbj.takeAction(IEVMBlackjack.Action.SPLIT);
        evmbj.fulfillRandomness(requestId, keccak256(""));

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

        assertEq(game.state, IEVMBlackjack.State.DEALER_ACTION, "State");
        assertEq(game.shoeCount, previousGame.shoeCount - 2);
    }

    /*//////////////////////////////////////////////////////////////
    //  Player Action -- Split
    //////////////////////////////////////////////////////////////*/

    function test_split() public withChips(player) withApproval(player) {
        vm.prank(player);
        bytes32 requestId = evmbj.placeBet(BETSIZE1);
        evmbj.fulfillRandomness(requestId, keccak256("pair"));

        IEVMBlackjack.Game memory previousGame = evmbj.getGame(player);

        assertEq(previousGame.playerHands[0].cards[0], 6);
        assertEq(previousGame.playerHands[0].cards[1], 19);

        vm.prank(player);
        evmbj.takeAction(IEVMBlackjack.Action.SPLIT);

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

        assertEq(game.state, IEVMBlackjack.State.WAITING_FOR_RANDOMNESS, "State");
        assertEq(game.lastAction, IEVMBlackjack.Action.SPLIT, "Last action");
        assertEq(game.totalPlayerHands, 1);
    }

    function test_split_andFulfillRandomness() public withChips(player) withApproval(player) {
        vm.prank(player);
        bytes32 requestId = evmbj.placeBet(BETSIZE1);
        evmbj.fulfillRandomness(requestId, keccak256("pair"));

        IEVMBlackjack.Game memory previousGame = evmbj.getGame(player);

        vm.prank(player);
        requestId = evmbj.takeAction(IEVMBlackjack.Action.SPLIT);
        evmbj.fulfillRandomness(requestId, keccak256(""));

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

        assertEq(game.state, IEVMBlackjack.State.READY_FOR_PLAYER_ACTION, "State");
        assertEq(game.shoeCount, previousGame.shoeCount - 2);
    }

    /*//////////////////////////////////////////////////////////////
    //  Player Action -- Double Down
    //////////////////////////////////////////////////////////////*/

    function test_doubleDown() public withChips(player) withApproval(player) readyForPlayerAction(player) {
        vm.prank(player);
        evmbj.takeAction(IEVMBlackjack.Action.DOUBLE_DOWN);

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

        uint256 doubleDownBet = BETSIZE1 * 2;

        assertEq(game.state, IEVMBlackjack.State.WAITING_FOR_RANDOMNESS, "State");
        assertEq(game.lastAction, IEVMBlackjack.Action.DOUBLE_DOWN, "Last action");
        assertEq(game.playerHands[0].betSize, doubleDownBet, "Bet size"); // doubled bet size
        assertChips(PLAYER_STARTING_BALANCE - doubleDownBet, HOUSE_STARTING_BALANCE + doubleDownBet);
    }

    function testEvent_doubleDown() public withChips(player) withApproval(player) readyForPlayerAction(player) {
        vm.expectEmit(true, true, true, true);
        emit PlayerActionTaken(player, IEVMBlackjack.Action.DOUBLE_DOWN);

        vm.prank(player);
        evmbj.takeAction(IEVMBlackjack.Action.DOUBLE_DOWN);
    }

    function test_doubleDown_andFulfillRandomness()
        public
        withChips(player)
        withApproval(player)
        readyForPlayerAction(player)
    {
        vm.prank(player);
        bytes32 requestId = evmbj.takeAction(IEVMBlackjack.Action.DOUBLE_DOWN);

        IEVMBlackjack.Game memory previousGame = evmbj.getGame(player);

        evmbj.fulfillRandomness(requestId, "");

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

        assertEq(game.state, IEVMBlackjack.State.DEALER_ACTION, "State");
        assertEq(game.shoeCount, previousGame.shoeCount - 1, "Shoe count");
        assertNumberOfCards(game.playerHands[0].cards, 3, "Player cards"); // one more card
    }

    function testEvent_doubleDown_andFulfillRandomness()
        public
        withChips(player)
        withApproval(player)
        readyForPlayerAction(player)
    {
        vm.prank(player);
        bytes32 requestId = evmbj.takeAction(IEVMBlackjack.Action.DOUBLE_DOWN);

        // TODO make less brittle re log assertion and hardcoded card
        vm.expectEmit(true, true, true, false);
        emit PlayerCardDealt(player, 15, 0);

        evmbj.fulfillRandomness(requestId, "");
    }

    /*//////////////////////////////////////////////////////////////
    //  Player Action -- Hit
    //////////////////////////////////////////////////////////////*/

    function test_hit() public withChips(player) withApproval(player) readyForPlayerAction(player) {
        vm.prank(player);
        evmbj.takeAction(IEVMBlackjack.Action.HIT);

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

        assertEq(game.state, IEVMBlackjack.State.WAITING_FOR_RANDOMNESS, "State");
        assertEq(game.lastAction, IEVMBlackjack.Action.HIT, "Last action");
        assertEq(game.playerHands[0].betSize, BETSIZE1, "Bet size"); // no change
    }

    function testEvent_hit() public withChips(player) withApproval(player) readyForPlayerAction(player) {
        vm.expectEmit(true, true, true, true);
        emit PlayerActionTaken(player, IEVMBlackjack.Action.HIT);

        vm.prank(player);
        evmbj.takeAction(IEVMBlackjack.Action.HIT);
    }

    function test_hit_andFulfillRandomness()
        public
        withChips(player)
        withApproval(player)
        readyForPlayerAction(player)
    {
        vm.prank(player);
        bytes32 requestId = evmbj.takeAction(IEVMBlackjack.Action.HIT);

        IEVMBlackjack.Game memory previousGame = evmbj.getGame(player);

        evmbj.fulfillRandomness(requestId, "");

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

        assertEq(game.state, IEVMBlackjack.State.READY_FOR_PLAYER_ACTION, "State");
        assertEq(game.shoeCount, previousGame.shoeCount - 1, "Shoe count");
        assertNumberOfCards(game.playerHands[0].cards, 3, "Player cards"); // one more card
    }

    function testEvent_hit_andFulfillRandomness()
        public
        withChips(player)
        withApproval(player)
        readyForPlayerAction(player)
    {
        vm.prank(player);
        bytes32 requestId = evmbj.takeAction(IEVMBlackjack.Action.HIT);

        // TODO make less brittle re log assertion and hardcoded card
        vm.expectEmit(true, true, true, false);
        emit PlayerCardDealt(player, 25, 0);

        evmbj.fulfillRandomness(requestId, "");
    }

    /*//////////////////////////////////////////////////////////////
    //  Player Action -- Stand
    //////////////////////////////////////////////////////////////*/

    function test_stand() public withChips(player) withApproval(player) readyForPlayerAction(player) {
        IEVMBlackjack.Game memory previousGame = evmbj.getGame(player);

        vm.prank(player);
        evmbj.takeAction(IEVMBlackjack.Action.STAND);

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

        assertEq(game.state, IEVMBlackjack.State.DEALER_ACTION, "State");
        assertEq(game.lastAction, IEVMBlackjack.Action.STAND, "Last action");
        assertEq(game.shoeCount, previousGame.shoeCount, "Shoe count"); // no change
        assertNumberOfCards(game.playerHands[0].cards, 2, "Player cards"); // no change
        assertEq(game.playerHands[0].betSize, BETSIZE1, "Bet size"); // no change
    }

    function testEvent_stand() public withChips(player) withApproval(player) readyForPlayerAction(player) {
        vm.expectEmit(true, true, true, true);
        emit PlayerActionTaken(player, IEVMBlackjack.Action.STAND);

        vm.prank(player);
        evmbj.takeAction(IEVMBlackjack.Action.STAND);
    }

    /*//////////////////////////////////////////////////////////////
    //  Test Helpers
    //////////////////////////////////////////////////////////////*/

    function assertState(address _player, IEVMBlackjack.State expectedState) internal {
        IEVMBlackjack.Game memory game = evmbj.getGame(_player);
        assertEq(game.state, expectedState, "State");
    }

    function assertEq(IEVMBlackjack.State a, IEVMBlackjack.State b, string memory reason) internal {
        assertEq(uint256(a), uint256(b), reason);
    }

    function assertEq(IEVMBlackjack.Action a, IEVMBlackjack.Action b, string memory reason) internal {
        assertEq(uint256(a), uint256(b), reason);
    }

    function assertNumberOfCards(uint8[] memory _cards, uint8 expectedNumberOfCards, string memory reason) internal {
        uint256 numberOfCards;
        assembly {
            numberOfCards := mload(add(_cards, 0))
        }
        assertEq(numberOfCards, expectedNumberOfCards, reason);
    }

    function assertChips(uint256 playerChipBalance, uint256 houseChipBalance) internal {
        assertEq(chip.balanceOf(player), playerChipBalance, "Player CHIP balance");
        assertEq(chip.balanceOf(address(evmbj)), houseChipBalance, "House CHIP balance");
    }

    /*//////////////////////////////////////////////////////////////
    //  Events
    //////////////////////////////////////////////////////////////*/

    event BetPlaced(address indexed player, uint256 betSize);
    event PlayerCardDealt(address indexed player, uint8 card, uint8 handIndex);
    event DealerCardDealt(address indexed player, uint8 card);
    event InsuranceTaken(address indexed player, bool take);
    event PlayerActionTaken(address indexed player, IEVMBlackjack.Action action);
    event PlayerBust(address indexed player);
    event DealerBust(address indexed player);
    event PayoutsHandled(address indexed player, uint256 playerPayout, uint256 dealerPayout);

    /*//////////////////////////////////////////////////////////////
    //  Game States OLD
    //////////////////////////////////////////////////////////////*/

    // // Place Bet

    // function test_placeBet_whenState_readyForBet() public withChips(player) withApproval(player) {
    //     vm.prank(player);
    //     evmbj.placeBet(10);

    //     assertState(player, EVMBlackjack.State.WAITING_FOR_RANDOMNESS);
    // }

    // function testRevert_placeBet_whenState_waitingForRandomness() public {
    //     // TODO
    // }

    // function testRevert_placeBet_whenState_readyForInsurance() public {
    //     // TODO
    // }

    // function testRevert_placeBet_whenState_readyForPlayerAction() public {
    //     // TODO
    // }

    // function testRevert_placeBet_whenState_dealerAction() public {
    //     // TODO
    // }

    // // Fulfill Randomness

    // function test_fulfillRandomness_whenState_waitingForRandomness() public withChips(player) withApproval(player) {
    //     vm.prank(player);
    //     evmbj.placeBet(10);

    //     evmbj.fulfillRandomness(player, keccak256("hey"));

    //     assertState(player, EVMBlackjack.State.READY_FOR_INSURANCE);
    // }

    // function testRevert_fulfillRandomness_whenState_readyForBet() public {
    //     vm.expectRevert(EVMBlackjack.InvalidAction.selector);
    //     evmbj.fulfillRandomness(player, keccak256("hey"));
    // }

    // function testRevert_fulfillRandomness_whenState_readyForInsurance() public {
    //     // TODO
    // }

    // function testRevert_fulfillRandomness_whenState_readyForPlayerAction() public {
    //     // TODO
    // }

    // function testRevert_fulfillRandomness_whenState_dealerAction() public {
    //     // TODO
    // }

    // // Take Insurance / Decline Insurance

    // function test_takeInsurance_whenState_readyForInsurance() public withChips(player) withApproval(player) {
    //     vm.prank(player);
    //     evmbj.placeBet(10);

    //     evmbj.fulfillRandomness(player, keccak256("hey"));

    //     vm.prank(player);
    //     evmbj.takeInsurance(true);

    //     assertState(player, EVMBlackjack.State.READY_FOR_PLAYER_ACTION);
    // }

    // // TODO testRevert_takeInsurance_whenDealerDoesNotShowAnAce
    // // TODO testRevert_declineInsurance_whenDealerDoesNotShowAnAce

    // function testRevert_takeInsurance_whenState_readyForBet() public {
    //     vm.expectRevert(EVMBlackjack.InvalidAction.selector);

    //     vm.prank(player);
    //     evmbj.takeInsurance(true);
    // }

    // function testRevert_takeInsurance_whenState_waitingForRandomness() public withChips(player) withApproval(player) {
    //     vm.prank(player);
    //     evmbj.placeBet(10);

    //     vm.expectRevert(EVMBlackjack.InvalidAction.selector);

    //     vm.prank(player);
    //     evmbj.takeInsurance(true);
    // }

    // function testRevert_takeInsurance_whenState_readyForPlayerAction() public withChips(player) withApproval(player) {
    //     // TODO
    // }

    // function testRevert_takeInsurance_whenState_dealerAction() public withChips(player) withApproval(player) {
    //     // TODO
    // }

    // function test_declineInsurance_whenState_readyForInsurance() public withChips(player) withApproval(player) {
    //     vm.prank(player);
    //     evmbj.placeBet(10);

    //     evmbj.fulfillRandomness(player, keccak256("hey"));

    //     vm.prank(player);
    //     evmbj.takeInsurance(false);

    //     assertState(player, EVMBlackjack.State.READY_FOR_PLAYER_ACTION);
    // }

    // function testRevert_declineInsurance_whenState_readyForBet() public {
    //     vm.expectRevert(EVMBlackjack.InvalidAction.selector);

    //     vm.prank(player);
    //     evmbj.takeInsurance(false);
    // }

    // function testRevert_declineInsurance_whenState_waitingForRandomness() public withChips(player) withApproval(player) {
    //     vm.prank(player);
    //     evmbj.placeBet(10);

    //     vm.expectRevert(EVMBlackjack.InvalidAction.selector);

    //     vm.prank(player);
    //     evmbj.takeInsurance(false);
    // }

    // function testRevert_declineInsurance_whenState_readyForPlayerAction() public withChips(player) withApproval(player) {
    //     // TODO
    // }

    // function testRevert_declineInsurance_whenState_dealerAction() public withChips(player) withApproval(player) {
    //     // TODO
    // }

    // // Split Aces

    // function test_splitAces_whenState_readyForPlayerAction_andPlayerHasAA() public withChips(player) withApproval(player) {
    //     vm.prank(player);
    //     evmbj.placeBet(10);

    //     evmbj.fulfillRandomness(player, "");
    //     // evmbj.cheatInitialPlayerHand(player, 0, EVMBlackjack.Card.ACE_SPADES, EVMBlackjack.Card.ACE_CLUBS);

    //     vm.prank(player);
    //     //
    // }
}
