// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/Test.sol";

import {Chip} from "../src/Chip.sol";
import {EVMBlackjack} from "../src/EVMBlackjack.sol";

contract EVMBlackjackTest is Test {
    Chip internal chip;
    EVMBlackjack internal evmbj;

    address internal constant player = address(0xA);
    address internal constant player2 = address(0xB);
    address internal constant player3 = address(0xC);
    address internal constant player4 = address(0xD);
    address internal constant player5 = address(0xE);

    uint256 internal constant HOUSE_STARTING_BALANCE = 1_000_000;
    uint256 internal constant PLAYER_STARTING_BALANCE = 1_000;
    uint16 internal constant SHOE_STARTING_COUNT = 52 * 6;

    uint16 internal constant BETSIZE1 = 10;
    uint16 internal constant BETSIZE2 = 25;
    uint16 internal constant BETSIZE3 = 50;
    uint16 internal constant BETSIZE4 = 75;
    uint16 internal constant BETSIZE5 = 100;

    function setUp() public {
        chip = new Chip();
        evmbj = new EVMBlackjack(chip);
        chip.mint(address(evmbj), HOUSE_STARTING_BALANCE);

        vm.deal(player, 10 ether);
        vm.deal(player2, 10 ether);
        vm.deal(player3, 10 ether);
        vm.deal(player4, 10 ether);
        vm.deal(player5, 10 ether);
    }

    modifier withChip(address _player, uint256 _amount) {
        chip.mint(_player, _amount);
        _;
    }

    modifier withApproval(address _player) {
        vm.prank(_player);
        chip.approve(address(evmbj), type(uint256).max);
        _;
    }

    modifier readyForPlayerAction(address _player) {
        vm.prank(player);
        evmbj.placeBet(BETSIZE1);
        evmbj.fulfillRandomness(player, "");
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
        assertState(player, EVMBlackjack.State.READY_FOR_BET);
    }

    function test_placeBet() public withChip(player, 1000) {
        vm.startPrank(player);
        chip.approve(address(evmbj), type(uint256).max);
        evmbj.placeBet(BETSIZE1);
        vm.stopPrank();

        (
            EVMBlackjack.State state,
            uint16 shoeCount,
            uint8[] memory dealerCards,
            uint8[] memory playerCards,
            uint16 betSize,
            EVMBlackjack.Action lastAction,
            uint16 insurance
        ) = evmbj.getGame(player);

        assertEq(state, EVMBlackjack.State.WAITING_FOR_RANDOMNESS, "State");
        assertEq(shoeCount, SHOE_STARTING_COUNT, "Shoe count");
        assertEq(betSize, BETSIZE1, "Bet size");
        assertEq(insurance, 0, "Insurance");
        assertChips(PLAYER_STARTING_BALANCE - BETSIZE1, HOUSE_STARTING_BALANCE + BETSIZE1);
    }

    function testRevert_placeBet_whenInsufficientApprovalGranted() public {
        vm.expectRevert(stdError.arithmeticError);

        vm.prank(player);
        evmbj.placeBet(10);
    }

    function testRevert_placeBet_whenBelowMinimumBetSize() public {
        vm.expectRevert(abi.encodeWithSelector(EVMBlackjack.InvalidBetSize.selector, BETSIZE1 - 1));

        vm.prank(player);
        evmbj.placeBet(BETSIZE1 - 1);
    }

    function testRevert_placeBet_whenBelowMaximumBetSize() public {
        vm.expectRevert(abi.encodeWithSelector(EVMBlackjack.InvalidBetSize.selector, BETSIZE5 + 1));

        vm.prank(player);
        evmbj.placeBet(BETSIZE5 + 1);
    }

    function test_placeBet_andFulfillRandomness_whenDealerShowsAce()
        public
        withChip(player, 1000)
        withApproval(player)
    {
        vm.prank(player);
        evmbj.placeBet(BETSIZE1);

        evmbj.fulfillRandomness(player, keccak256("ace"));

        (
            EVMBlackjack.State state,
            uint16 shoeCount,
            uint8[] memory dealerCards,
            uint8[] memory playerCards,
            uint16 betSize,
            EVMBlackjack.Action lastAction,
        ) = evmbj.getGame(player);

        assertEq(state, EVMBlackjack.State.READY_FOR_INSURANCE, "State");
        assertEq(shoeCount, SHOE_STARTING_COUNT - 3, "Shoe count");
        assertNumberOfCards(dealerCards, 1, "Dealer cards");
        assertNumberOfCards(playerCards, 2, "Player cards");
    }

    function test_placeBet_andFulfillRandomness_whenDealerDoesNotShowAce()
        public
        withChip(player, 1000)
        withApproval(player)
    {
        vm.prank(player);
        evmbj.placeBet(BETSIZE1);

        evmbj.fulfillRandomness(player, "");

        (
            EVMBlackjack.State state,
            uint16 shoeCount,
            uint8[] memory dealerCards,
            uint8[] memory playerCards,
            uint16 betSize,
            EVMBlackjack.Action lastAction,
        ) = evmbj.getGame(player);

        assertEq(state, EVMBlackjack.State.READY_FOR_PLAYER_ACTION, "State");
        assertEq(shoeCount, SHOE_STARTING_COUNT - 3, "Shoe count");
        assertNumberOfCards(dealerCards, 1, "Dealer cards");
        assertNumberOfCards(playerCards, 2, "Player cards");
    }

    /*//////////////////////////////////////////////////////////////
    //  Take / Decline Insurance
    //////////////////////////////////////////////////////////////*/

    function test_takeInsurance() public withChip(player, 1000) withApproval(player) {
        vm.prank(player);
        evmbj.placeBet(BETSIZE1);
        evmbj.fulfillRandomness(player, keccak256("ace"));

        vm.prank(player);
        evmbj.takeInsurance(true);

        uint16 insuranceBet = BETSIZE1 / 2;

        (
            EVMBlackjack.State state,
            uint16 shoeCount,
            uint8[] memory dealerCards,
            uint8[] memory playerCards,
            uint16 betSize,
            EVMBlackjack.Action lastAction,
            uint16 insurance
        ) = evmbj.getGame(player);

        assertEq(state, EVMBlackjack.State.READY_FOR_PLAYER_ACTION, "State");
        assertEq(insurance, insuranceBet, "Insurance");
        assertChips(PLAYER_STARTING_BALANCE - BETSIZE1 - insuranceBet, HOUSE_STARTING_BALANCE + BETSIZE1 + insuranceBet);
    }

    function test_declineInsurance() public withChip(player, 1000) withApproval(player) {
        vm.prank(player);
        evmbj.placeBet(BETSIZE1);
        evmbj.fulfillRandomness(player, keccak256("ace"));

        vm.prank(player);
        evmbj.takeInsurance(false);

        (
            EVMBlackjack.State state,
            uint16 shoeCount,
            uint8[] memory dealerCards,
            uint8[] memory playerCards,
            uint16 betSize,
            EVMBlackjack.Action lastAction,
            uint16 insurance
        ) = evmbj.getGame(player);

        assertEq(state, EVMBlackjack.State.READY_FOR_PLAYER_ACTION, "State");
        assertEq(insurance, 0, "Insurance");
        assertChips(PLAYER_STARTING_BALANCE - BETSIZE1, HOUSE_STARTING_BALANCE + BETSIZE1);
    }

    /*//////////////////////////////////////////////////////////////
    //  Player Action -- Split Aces
    //////////////////////////////////////////////////////////////*/

    //

    /*//////////////////////////////////////////////////////////////
    //  Player Action -- Split
    //////////////////////////////////////////////////////////////*/

    //

    /*//////////////////////////////////////////////////////////////
    //  Player Action -- Double Down
    //////////////////////////////////////////////////////////////*/

    function test_doubleDown() public withChip(player, 1000) withApproval(player) readyForPlayerAction(player) {
        vm.prank(player);
        evmbj.takeAction(EVMBlackjack.Action.DOUBLE_DOWN);

        (
            EVMBlackjack.State state,
            uint16 shoeCount,
            uint8[] memory dealerCards,
            uint8[] memory playerCards,
            uint16 betSize,
            EVMBlackjack.Action lastAction,
            uint16 insurance
        ) = evmbj.getGame(player);

        uint16 doubleDownBet = BETSIZE1 * 2;

        assertEq(state, EVMBlackjack.State.WAITING_FOR_RANDOMNESS, "State");
        assertEq(lastAction, EVMBlackjack.Action.DOUBLE_DOWN, "Last action");
        assertEq(betSize, doubleDownBet, "Bet size"); // doubled bet size
        assertChips(PLAYER_STARTING_BALANCE - doubleDownBet, HOUSE_STARTING_BALANCE + doubleDownBet);
    }

    function test_doubleDown_fulfillRandomness()
        public
        withChip(player, 1000)
        withApproval(player)
        readyForPlayerAction(player)
    {
        vm.prank(player);
        evmbj.takeAction(EVMBlackjack.Action.DOUBLE_DOWN);

        (, uint16 previousShoeCount,,,,,) = evmbj.getGame(player);

        evmbj.fulfillRandomness(player, "");

        (
            EVMBlackjack.State state,
            uint16 shoeCount,
            uint8[] memory dealerCards,
            uint8[] memory playerCards,
            uint16 betSize,
            EVMBlackjack.Action lastAction,
            uint16 insurance
        ) = evmbj.getGame(player);

        assertEq(state, EVMBlackjack.State.DEALER_ACTION, "State");
        assertEq(shoeCount, previousShoeCount - 1, "Shoe count");
        assertNumberOfCards(playerCards, 3, "Player cards"); // one more card
    }

    /*//////////////////////////////////////////////////////////////
    //  Player Action -- Hit
    //////////////////////////////////////////////////////////////*/

    function test_hit() public withChip(player, 1000) withApproval(player) readyForPlayerAction(player) {
        vm.prank(player);
        evmbj.takeAction(EVMBlackjack.Action.HIT);

        (
            EVMBlackjack.State state,
            uint16 shoeCount,
            uint8[] memory dealerCards,
            uint8[] memory playerCards,
            uint16 betSize,
            EVMBlackjack.Action lastAction,
            uint16 insurance
        ) = evmbj.getGame(player);

        assertEq(state, EVMBlackjack.State.WAITING_FOR_RANDOMNESS, "State");
        assertEq(lastAction, EVMBlackjack.Action.HIT, "Last action");
        assertEq(betSize, BETSIZE1, "Bet size"); // no change
    }

    function test_hit_fulfillRandomness()
        public
        withChip(player, 1000)
        withApproval(player)
        readyForPlayerAction(player)
    {
        vm.prank(player);
        evmbj.takeAction(EVMBlackjack.Action.HIT);

        (, uint16 previousShoeCount,,,,,) = evmbj.getGame(player);

        evmbj.fulfillRandomness(player, "");

        (
            EVMBlackjack.State state,
            uint16 shoeCount,
            uint8[] memory dealerCards,
            uint8[] memory playerCards,
            uint16 betSize,
            EVMBlackjack.Action lastAction,
            uint16 insurance
        ) = evmbj.getGame(player);

        assertEq(state, EVMBlackjack.State.READY_FOR_PLAYER_ACTION, "State");
        assertEq(shoeCount, previousShoeCount - 1, "Shoe count");
        assertNumberOfCards(playerCards, 3, "Player cards"); // one more card
    }

    /*//////////////////////////////////////////////////////////////
    //  Player Action -- Stand
    //////////////////////////////////////////////////////////////*/

    function test_stand() public withChip(player, 1000) withApproval(player) readyForPlayerAction(player) {
        (, uint16 previousShoeCount,,,,,) = evmbj.getGame(player);

        vm.prank(player);
        evmbj.takeAction(EVMBlackjack.Action.STAND);

        (
            EVMBlackjack.State state,
            uint16 shoeCount,
            uint8[] memory dealerCards,
            uint8[] memory playerCards,
            uint16 betSize,
            EVMBlackjack.Action lastAction,
            uint16 insurance
        ) = evmbj.getGame(player);

        assertEq(state, EVMBlackjack.State.DEALER_ACTION, "State");
        assertEq(lastAction, EVMBlackjack.Action.STAND, "Last action");
        assertEq(shoeCount, previousShoeCount, "Shoe count"); // no change
        assertNumberOfCards(playerCards, 2, "Player cards"); // no change
        assertEq(betSize, BETSIZE1, "Bet size"); // no change
    }

    /*//////////////////////////////////////////////////////////////
    //  Test Helpers
    //////////////////////////////////////////////////////////////*/

    function assertState(address _player, EVMBlackjack.State expectedState) internal {
        (EVMBlackjack.State state,,,,,,) = evmbj.getGame(_player);
        assertEq(state, expectedState, "State");
    }

    function assertEq(EVMBlackjack.State a, EVMBlackjack.State b, string memory reason) internal {
        assertEq(uint256(a), uint256(b), reason);
    }

    function assertEq(EVMBlackjack.Action a, EVMBlackjack.Action b, string memory reason) internal {
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
    //  Game States OLD
    //////////////////////////////////////////////////////////////*/

    // // Place Bet

    // function test_placeBet_whenState_readyForBet() public withChip(player, 1000) withApproval(player) {
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

    // function test_fulfillRandomness_whenState_waitingForRandomness() public withChip(player, 1000) withApproval(player) {
    //     vm.prank(player);
    //     evmbj.placeBet(10);

    //     evmbj.fulfillRandomness(player, keccak256("hey"));

    //     assertState(player, EVMBlackjack.State.READY_FOR_INSURANCE);
    // }

    // function testRevert_fulfillRandomness_whenState_readyForBet() public {
    //     vm.expectRevert(EVMBlackjack.InvalidStateTransition.selector);
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

    // function test_takeInsurance_whenState_readyForInsurance() public withChip(player, 1000) withApproval(player) {
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
    //     vm.expectRevert(EVMBlackjack.InvalidStateTransition.selector);

    //     vm.prank(player);
    //     evmbj.takeInsurance(true);
    // }

    // function testRevert_takeInsurance_whenState_waitingForRandomness() public withChip(player, 1000) withApproval(player) {
    //     vm.prank(player);
    //     evmbj.placeBet(10);

    //     vm.expectRevert(EVMBlackjack.InvalidStateTransition.selector);

    //     vm.prank(player);
    //     evmbj.takeInsurance(true);
    // }

    // function testRevert_takeInsurance_whenState_readyForPlayerAction() public withChip(player, 1000) withApproval(player) {
    //     // TODO
    // }

    // function testRevert_takeInsurance_whenState_dealerAction() public withChip(player, 1000) withApproval(player) {
    //     // TODO
    // }

    // function test_declineInsurance_whenState_readyForInsurance() public withChip(player, 1000) withApproval(player) {
    //     vm.prank(player);
    //     evmbj.placeBet(10);

    //     evmbj.fulfillRandomness(player, keccak256("hey"));

    //     vm.prank(player);
    //     evmbj.takeInsurance(false);

    //     assertState(player, EVMBlackjack.State.READY_FOR_PLAYER_ACTION);
    // }

    // function testRevert_declineInsurance_whenState_readyForBet() public {
    //     vm.expectRevert(EVMBlackjack.InvalidStateTransition.selector);

    //     vm.prank(player);
    //     evmbj.takeInsurance(false);
    // }

    // function testRevert_declineInsurance_whenState_waitingForRandomness() public withChip(player, 1000) withApproval(player) {
    //     vm.prank(player);
    //     evmbj.placeBet(10);

    //     vm.expectRevert(EVMBlackjack.InvalidStateTransition.selector);

    //     vm.prank(player);
    //     evmbj.takeInsurance(false);
    // }

    // function testRevert_declineInsurance_whenState_readyForPlayerAction() public withChip(player, 1000) withApproval(player) {
    //     // TODO
    // }

    // function testRevert_declineInsurance_whenState_dealerAction() public withChip(player, 1000) withApproval(player) {
    //     // TODO
    // }

    // // Split Aces

    // function test_splitAces_whenState_readyForPlayerAction_andPlayerHasAA() public withChip(player, 1000) withApproval(player) {
    //     vm.prank(player);
    //     evmbj.placeBet(10);

    //     evmbj.fulfillRandomness(player, "");
    //     // evmbj.cheatInitialPlayerHand(player, 0, EVMBlackjack.Card.ACE_SPADES, EVMBlackjack.Card.ACE_CLUBS);

    //     vm.prank(player);
    //     //
    // }
}
