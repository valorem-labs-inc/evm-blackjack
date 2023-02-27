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

    /*//////////////////////////////////////////////////////////////
    //  Sitting / Leaving
    //////////////////////////////////////////////////////////////*/

    function test_player_sit() public {
        assertEq(chip.balanceOf(player), 0);
        assertEq(chip.balanceOf(address(evmbj)), HOUSE_STARTING_BALANCE);
        assertState(player, EVMBlackjack.GameState.NO_GAME);

        vm.prank(player);
        evmbj.sit();

        assertEq(chip.balanceOf(player), PLAYER_STARTING_BALANCE, "Player CHIP balance");
        assertEq(chip.balanceOf(address(evmbj)), HOUSE_STARTING_BALANCE - PLAYER_STARTING_BALANCE, "House CHIP balance");        
        assertGame(player, EVMBlackjack.GameState.READY_FOR_BET, SHOE_STARTING_COUNT, 0);
    }

    // TODO sad path, check that Player isn't already sitting at a table

    function test_player_leave() public {
        assertState(player, EVMBlackjack.GameState.NO_GAME);

        vm.startPrank(player);
        evmbj.sit();
        assertState(player, EVMBlackjack.GameState.READY_FOR_BET);

        evmbj.leave();
        vm.stopPrank();

        assertState(player, EVMBlackjack.GameState.NO_GAME);
    }

    // TODO sad path, check that Player isn't involved in a hand

    /*//////////////////////////////////////////////////////////////
    //  Ready for Bet
    //////////////////////////////////////////////////////////////*/

    function test_player_placeBet() public {
        vm.startPrank(player);
        chip.approve(address(evmbj), type(uint256).max);

        evmbj.sit();

        evmbj.placeBet(BETSIZE1);
        vm.stopPrank();

        assertEq(chip.balanceOf(player), PLAYER_STARTING_BALANCE - BETSIZE1, "Player CHIP balance");
        assertEq(
            chip.balanceOf(address(evmbj)),
            HOUSE_STARTING_BALANCE - PLAYER_STARTING_BALANCE + BETSIZE1,
            "House CHIP balance"
        );
        assertGame(player, EVMBlackjack.GameState.PLAYER_ACTION, SHOE_STARTING_COUNT, BETSIZE1);
    }

    function testRevert_player_placeBet_whenInsufficientApprovalGranted() public {
        vm.startPrank(player);
        evmbj.sit();

        vm.expectRevert(stdError.arithmeticError);

        evmbj.placeBet(10);
        vm.stopPrank();
    }

    function testRevert_player_placeBet_whenBelowMinimumBetSize() public {
        vm.startPrank(player);
        evmbj.sit();

        vm.expectRevert(abi.encodeWithSelector(EVMBlackjack.InvalidBetSize.selector, BETSIZE1 - 1));

        evmbj.placeBet(BETSIZE1 - 1);
        vm.stopPrank();
    }

    function testRevert_player_placeBet_whenBelowMaximumBetSize() public {
        vm.startPrank(player);
        evmbj.sit();

        vm.expectRevert(abi.encodeWithSelector(EVMBlackjack.InvalidBetSize.selector, BETSIZE5 + 1));

        evmbj.placeBet(BETSIZE5 + 1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
    //  Test Helpers
    //////////////////////////////////////////////////////////////*/

    function assertEq(EVMBlackjack.GameState a, EVMBlackjack.GameState b, string memory reason) internal {
        assertEq(uint256(a), uint256(b), reason);
    }

    function assertState(address _player, EVMBlackjack.GameState _state) internal {
        (EVMBlackjack.GameState state, ,) = evmbj.games(_player);

        assertEq(state, _state, "Game state");
    }

    function assertGame(address _player, EVMBlackjack.GameState _state, uint16 _remainingCardsInShoe, uint8 _bet) internal {
        (EVMBlackjack.GameState state, EVMBlackjack.Shoe memory shoe, uint8 bet) = evmbj.games(_player);

        assertEq(state, _state, "Game state");
        assertEq(shoe.remainingCardsInShoe, _remainingCardsInShoe, "Shoe count");
        assertEq(bet, _bet, "Player bet");
    }
}
