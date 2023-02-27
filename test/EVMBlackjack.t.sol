// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/Test.sol";

import {Chip} from "../src/Chip.sol";
import {EVMBlackjack} from "../src/EVMBlackjack.sol";

contract EVMBlackjackTest is Test {
    Chip internal chip;
    EVMBlackjack internal game;

    address internal constant player = address(0xA);
    address internal constant dealer = address(0xB);

    uint256 internal constant HOUSE_STARTING_BALANCE = 1_000_000;
    uint256 internal constant PLAYER_STARTING_BALANCE = 1_000;
    uint256 internal constant SHOE_STARTING_COUNT = 52 * 6;

    uint8 internal constant BETSIZE1 = 10;
    uint8 internal constant BETSIZE2 = 25;
    uint8 internal constant BETSIZE3 = 50;
    uint8 internal constant BETSIZE4 = 75;
    uint8 internal constant BETSIZE5 = 100;

    function setUp() public {
        chip = new Chip();
        game = new EVMBlackjack(chip);
        chip.mint(address(game), HOUSE_STARTING_BALANCE);

        vm.deal(player, 10 ether);
        vm.deal(dealer, 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
    //  Sitting / Leaving
    //////////////////////////////////////////////////////////////*/

    function test_player_sit() public {
        assertEq(chip.balanceOf(player), 0);
        assertEq(chip.balanceOf(address(game)), HOUSE_STARTING_BALANCE);
        assertEq(game.table(player), 0);

        vm.prank(player);
        game.sit();

        assertEq(chip.balanceOf(player), PLAYER_STARTING_BALANCE, "Player CHIP balance");
        assertEq(chip.balanceOf(address(game)), HOUSE_STARTING_BALANCE - PLAYER_STARTING_BALANCE, "House CHIP balance");
        assertEq(game.table(player), 1, "Player table");
        assertEq(game.state(player), EVMBlackjack.GameState.READY_FOR_BET, "Player table state");
        assertEq(game.shoe(player), SHOE_STARTING_COUNT, "Shoe starting count");
    }

    // TODO sad path, check that Player isn't already sitting at a table

    function test_player_leave() public {
        assertEq(game.table(player), 0);

        vm.startPrank(player);
        game.sit();
        assertEq(game.table(player), 1, "Player table");

        game.leave();
        vm.stopPrank();

        assertEq(game.table(player), 0, "Player table");
        assertEq(game.state(player), EVMBlackjack.GameState.NO_GAME, "Player table state");
    }

    // TODO sad path, check that Player isn't involved in a hand

    /*//////////////////////////////////////////////////////////////
    //  Ready for Bet
    //////////////////////////////////////////////////////////////*/

    function test_player_placeBet() public {
        vm.startPrank(player);
        chip.approve(address(game), type(uint256).max);

        game.sit();

        game.placeBet(BETSIZE1);
        vm.stopPrank();

        assertEq(chip.balanceOf(player), PLAYER_STARTING_BALANCE - BETSIZE1, "Player CHIP balance");
        assertEq(
            chip.balanceOf(address(game)),
            HOUSE_STARTING_BALANCE - PLAYER_STARTING_BALANCE + BETSIZE1,
            "House CHIP balance"
        );
        assertEq(game.state(player), EVMBlackjack.GameState.READY_FOR_DEAL, "Player table state");
        assertEq(game.bet(player), BETSIZE1, "Player bet size");
    }

    function testRevert_player_placeBet_whenInsufficientApprovalGranted() public {
        vm.startPrank(player);
        game.sit();

        vm.expectRevert(stdError.arithmeticError);

        game.placeBet(10);
        vm.stopPrank();
    }

    function testRevert_player_placeBet_whenBelowMinimumBetSize() public {
        vm.startPrank(player);
        game.sit();

        vm.expectRevert(abi.encodeWithSelector(EVMBlackjack.InvalidBetSize.selector, BETSIZE1 - 1));

        game.placeBet(BETSIZE1 - 1);
        vm.stopPrank();
    }

    function testRevert_player_placeBet_whenBelowMaximumBetSize() public {
        vm.startPrank(player);
        game.sit();

        vm.expectRevert(abi.encodeWithSelector(EVMBlackjack.InvalidBetSize.selector, BETSIZE5 + 1));

        game.placeBet(BETSIZE5 + 1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
    //  Test Helpers
    //////////////////////////////////////////////////////////////*/

    function assertEq(EVMBlackjack.GameState a, EVMBlackjack.GameState b, string memory reason) internal {
        assertEq(uint256(a), uint256(b), reason);
    }
}
