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

    uint8 internal constant BETSIZE1 = 10;
    uint8 internal constant BETSIZE2 = 25;
    uint8 internal constant BETSIZE3 = 50;
    uint8 internal constant BETSIZE4 = 75;
    uint8 internal constant BETSIZE5 = 100;

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

    /*//////////////////////////////////////////////////////////////
    //  Game States
    //////////////////////////////////////////////////////////////*/

    function test_initialState() public {
        assertState(player, EVMBlackjack.GameState.READY_FOR_BET);
    }

    // Place Bet

    function test_placeBet_whenState_readyForBet() public withChip(player, 1000) withApproval(player) {
        vm.prank(player);
        evmbj.placeBet(10);

        assertState(player, EVMBlackjack.GameState.WAITING_FOR_RANDOMNESS);
    }

    function testRevert_placeBet_whenState_waitingForRandomness() public {
        // TODO
    }

    function testRevert_placeBet_whenState_readyForInsurance() public {
        // TODO
    }

    function testRevert_placeBet_whenState_readyForPlayerAction() public {
        // TODO
    }

    function testRevert_placeBet_whenState_dealerAction() public {
        // TODO
    }

    // Fulfill Randomness

    function test_fulfillRandomness_whenState_waitingForRandomness() public withChip(player, 1000) withApproval(player) {
        vm.prank(player);
        evmbj.placeBet(10);

        evmbj.fulfillRandomness(player, keccak256("hey"));

        assertState(player, EVMBlackjack.GameState.READY_FOR_INSURANCE);                
    }

    function testRevert_fulfillRandomness_whenState_readyForBet() public {
        vm.expectRevert(EVMBlackjack.InvalidStateTransition.selector);
        evmbj.fulfillRandomness(player, keccak256("hey"));
    }

    function testRevert_fulfillRandomness_whenState_readyForInsurance() public {
        // TODO
    }

    function testRevert_fulfillRandomness_whenState_readyForPlayerAction() public {
        // TODO
    }

    function testRevert_fulfillRandomness_whenState_dealerAction() public {
        // TODO
    }

    // Take Insurance / Decline Insurance

    function test_takeInsurance_whenState_readyForInsurance() public withChip(player, 1000) withApproval(player) {
        vm.prank(player);
        evmbj.placeBet(10);

        evmbj.fulfillRandomness(player, keccak256("hey"));

        vm.prank(player);
        evmbj.takeInsurance(true);

        assertState(player, EVMBlackjack.GameState.READY_FOR_PLAYER_ACTION);
    }

    // TODO testRevert_takeInsurance_whenDealerDoesNotShowAnAce
    // TODO testRevert_declineInsurance_whenDealerDoesNotShowAnAce

    function testRevert_takeInsurance_whenState_readyForBet() public {
        vm.expectRevert(EVMBlackjack.InvalidStateTransition.selector);

        vm.prank(player);
        evmbj.takeInsurance(true);
    }

    function testRevert_takeInsurance_whenState_waitingForRandomness() public withChip(player, 1000) withApproval(player) {
        vm.prank(player);
        evmbj.placeBet(10);

        vm.expectRevert(EVMBlackjack.InvalidStateTransition.selector);

        vm.prank(player);
        evmbj.takeInsurance(true);
    }

    function testRevert_takeInsurance_whenState_readyForPlayerAction() public withChip(player, 1000) withApproval(player) {
        // TODO
    }

    function testRevert_takeInsurance_whenState_dealerAction() public withChip(player, 1000) withApproval(player) {
        // TODO
    }

    function test_declineInsurance_whenState_readyForInsurance() public withChip(player, 1000) withApproval(player) {
        vm.prank(player);
        evmbj.placeBet(10);

        evmbj.fulfillRandomness(player, keccak256("hey"));

        vm.prank(player);
        evmbj.takeInsurance(false);

        assertState(player, EVMBlackjack.GameState.READY_FOR_PLAYER_ACTION);
    }

    function testRevert_declineInsurance_whenState_readyForBet() public {
        vm.expectRevert(EVMBlackjack.InvalidStateTransition.selector);

        vm.prank(player);
        evmbj.takeInsurance(false);
    }

    function testRevert_declineInsurance_whenState_waitingForRandomness() public withChip(player, 1000) withApproval(player) {
        vm.prank(player);
        evmbj.placeBet(10);

        vm.expectRevert(EVMBlackjack.InvalidStateTransition.selector);

        vm.prank(player);
        evmbj.takeInsurance(false);
    }

    function testRevert_declineInsurance_whenState_readyForPlayerAction() public withChip(player, 1000) withApproval(player) {
        // TODO
    }

    function testRevert_declineInsurance_whenState_dealerAction() public withChip(player, 1000) withApproval(player) {
        // TODO
    }

    // Split Aces

    function test_splitAces_whenState_readyForPlayerAction_andPlayerHasAA() public withChip(player, 1000) withApproval(player) {
        vm.prank(player);
        evmbj.placeBet(10);

        evmbj.fulfillRandomness(player, "");
        evmbj.cheatInitialPlayerHand(player, 0, EVMBlackjack.Card.ACE_SPADES, EVMBlackjack.Card.ACE_CLUBS);

        vm.prank(player);
        // 
    }

    /*//////////////////////////////////////////////////////////////
    //  Cards
    //////////////////////////////////////////////////////////////*/

    function test_convertCardToValue(uint8 _input) public {
        vm.assume(_input < 52);

        uint8 raw = _input % 13 + 1;
        uint8 expected = (raw >= 10) ? 10 : raw;

        EVMBlackjack.Card card = EVMBlackjack.Card(_input);
        assertEq(evmbj.convertCardToValue(card), expected);
    }

    /*//////////////////////////////////////////////////////////////
    //  Ready for Bet
    //////////////////////////////////////////////////////////////*/

    // function test_player_placeBet() public {
    //     vm.startPrank(player);
    //     chip.approve(address(evmbj), type(uint256).max);

    //     evmbj.sit();

    //     evmbj.placeBet(BETSIZE1);
    //     vm.stopPrank();

    //     assertEq(chip.balanceOf(player), PLAYER_STARTING_BALANCE - BETSIZE1, "Player CHIP balance");
    //     assertEq(
    //         chip.balanceOf(address(evmbj)),
    //         HOUSE_STARTING_BALANCE - PLAYER_STARTING_BALANCE + BETSIZE1,
    //         "House CHIP balance"
    //     );
    //     assertGame(player, EVMBlackjack.GameState.READY_FOR_BET, SHOE_STARTING_COUNT, BETSIZE1, true);
    // }

    // function testRevert_player_placeBet_whenInsufficientApprovalGranted() public {
    //     vm.startPrank(player);
    //     evmbj.sit();

    //     vm.expectRevert(stdError.arithmeticError);

    //     evmbj.placeBet(10);
    //     vm.stopPrank();
    // }

    // function testRevert_player_placeBet_whenBelowMinimumBetSize() public {
    //     vm.startPrank(player);
    //     evmbj.sit();

    //     vm.expectRevert(abi.encodeWithSelector(EVMBlackjack.InvalidBetSize.selector, BETSIZE1 - 1));

    //     evmbj.placeBet(BETSIZE1 - 1);
    //     vm.stopPrank();
    // }

    // function testRevert_player_placeBet_whenBelowMaximumBetSize() public {
    //     vm.startPrank(player);
    //     evmbj.sit();

    //     vm.expectRevert(abi.encodeWithSelector(EVMBlackjack.InvalidBetSize.selector, BETSIZE5 + 1));

    //     evmbj.placeBet(BETSIZE5 + 1);
    //     vm.stopPrank();
    // }

    // function test_player_placeBet_andFulfillEntropy() public {
    //     vm.startPrank(player);
    //     chip.approve(address(evmbj), type(uint256).max);

    //     evmbj.sit();

    //     evmbj.placeBet(BETSIZE1);
    //     assertGame(player, EVMBlackjack.GameState.READY_FOR_BET, SHOE_STARTING_COUNT, BETSIZE1, true);

    //     evmbj.fulfillEntropy();

    //     assertGame(player, EVMBlackjack.GameState.PLAYER_ACTION, SHOE_STARTING_COUNT - 4, BETSIZE1, false);
    // }

    /*//////////////////////////////////////////////////////////////
    //  Test Helpers
    //////////////////////////////////////////////////////////////*/

    function assertState(address _player, EVMBlackjack.GameState _state) internal {
        (EVMBlackjack.GameState state,) = evmbj.games(_player);
        assertEq(uint256(state), uint256(_state), "Game state");
    }

    // function assertEq(EVMBlackjack.GameState a, EVMBlackjack.GameState b, string memory reason) internal {
    //     assertEq(uint256(a), uint256(b), reason);
    // }

    // function assertEq(EVMBlackjack.GameState a, EVMBlackjack.GameState b, string memory reason) internal {
    //     assertEq(uint256(a), uint256(b), reason);
    // }

    // function assertState(address _player, EVMBlackjack.GameState _state) internal {
    //     (EVMBlackjack.GameState state,,,) = evmbj.gamez(_player);
    //     assertEq(state, _state, "Game state");
    // }

    // function assertGame(
    //     address _player,
    //     EVMBlackjack.GameState _state,
    //     uint16 _remainingCardsInShoe,
    //     uint8 _bet,
    //     bool _waitingForEntropy
    // ) internal {
    //     (EVMBlackjack.GameState state, EVMBlackjack.Shoe memory shoe, uint8 bet, bool waitingForEntropy) =
    //         evmbj.gamez(_player);

    //     assertEq(state, _state, "Game state");
    //     assertEq(shoe.remainingCardsInShoe, _remainingCardsInShoe, "Shoe count");
    //     assertEq(bet, _bet, "Player bet");
    //     if (_waitingForEntropy) {
    //         assertTrue(waitingForEntropy, "Waiting for entropy");
    //     } else {
    //         assertTrue(!waitingForEntropy, "Waiting for entropy");
    //     }
    // }
}
