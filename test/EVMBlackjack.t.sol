// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "chainlink/interfaces/VRFCoordinatorV2Interface.sol";
import "../src/EVMBlackjack.sol";

// DONE Deploy script
// TODO Split
// DONE Remove Split Aces
// DONE Randomness ID => Player Address
// TODO Randomness ABI, use actual Chainlink VRF v2
// DONE Randomness at end of takeAction (except Insurance)
// TODO Integrate LibDDRV
// TODO Randomness card generation
// TODO Stand, revert if we hit the Else block
// TODO Dealer action, Hand valuation
// TODO Payouts
// TODO Replace shoeCount with Shoe struct
// TODO Add cut card functionality
// TODO Reshuffle shoe

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

    address vrfCoordinator = address(0xFFFF);
    uint64 subscriptionId = 111;
    bytes32 keyHash = 0;

    uint256 mockRequestId = 0xDEADBEEF;

    function setUp() public {
        chip = new Chip();

        vm.mockCall(
            vrfCoordinator,
            abi.encodeWithSelector(VRFCoordinatorV2Interface.getRequestConfig.selector),
            abi.encode(1, 0, 0, 0)
        );
        evmbj = new EVMBlackjack(
            chip, 
            vrfCoordinator,
            subscriptionId,
            keyHash);
        chip.houseMint(address(evmbj));

        vm.deal(player, 10 ether);
        vm.deal(player2, 10 ether);
        vm.deal(player3, 10 ether);
        vm.deal(player4, 10 ether);
        vm.deal(player5, 10 ether);

        vm.mockCall(
            vrfCoordinator,
            abi.encodeWithSelector(VRFCoordinatorV2Interface.requestRandomWords.selector),
            abi.encode(mockRequestId)
        );
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
        uint256 requestId = evmbj.placeBet(BETSIZE1);
        uint256[] memory words = new uint256[](1);
        words[0] = uint256(keccak256(""));

        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);
        _;
    }

    /*//////////////////////////////////////////////////////////////
    //  Cards
    //////////////////////////////////////////////////////////////*/

    function test_convertCardToValue(uint8 _input) public {
        vm.assume(_input > 0 && _input <= 52);

        uint8 raw = _input % 13;
        uint8 expected = (raw == 0 || raw >= 10) ? 10 : raw;

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
        vm.expectEmit(true, true, true, false);
        emit BetPlaced(player, BETSIZE1, bytes32(""));

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
        uint256 requestId = evmbj.placeBet(BETSIZE1);
        uint256[] memory words = new uint256[](1);

        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

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
        uint256[] memory words = new uint256[](1);
        words[0] = uint256(keccak256(""));

        vm.prank(player);
        uint256 requestId = evmbj.placeBet(BETSIZE1);

        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

        assertEq(game.state, IEVMBlackjack.State.READY_FOR_PLAYER_ACTION, "State");
        assertEq(game.shoeCount, SHOE_STARTING_COUNT - 3, "Shoe count");
        assertNumberOfCards(game.dealerCards, 1, "Dealer cards");
        assertNumberOfCards(game.playerHands[0].cards, 2, "Player cards");
    }

    function testEvent_placeBet_andFulfillRandomness() public withChips(player) withApproval(player) {
        vm.prank(player);
        uint256 requestId = evmbj.placeBet(BETSIZE1);
        uint256[] memory words = new uint256[](1);
        words[0] = uint256(keccak256(""));

        // TODO make log assertion less brittle once hardcoded cards are replaced
        vm.expectEmit(true, true, true, false);
        emit PlayerCardDealt(player, 13, 0);
        vm.expectEmit(true, true, true, false);
        emit DealerCardDealt(player, 1);
        vm.expectEmit(true, true, true, false);
        emit PlayerCardDealt(player, 14, 0);

        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);
    }

    /*//////////////////////////////////////////////////////////////
    //  Fulfill Randomness
    //////////////////////////////////////////////////////////////*/

    function testRevert_fulfillRandomness_whenRequestIdNotFound() public {
        uint256 badRequestId = uint256(keccak256("bad bad"));
        uint256[] memory words = new uint256[](1);
        words[0] = badRequestId;

        vm.expectRevert(abi.encodeWithSelector(IEVMBlackjack.InvalidRandomnessRequest.selector, badRequestId));
        vm.prank(address(this));
        evmbj.fulfillRandomness(badRequestId, words);
    }

    function testRevert_fulfillRandomness_whenAlreadyHandled() public withChips(player) withApproval(player) {
        vm.prank(player);
        uint256 requestId = evmbj.placeBet(BETSIZE1);
        uint256[] memory words = new uint256[](1);
        words[0] = uint256(keccak256("hey there"));
        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

        vm.expectRevert(abi.encodeWithSelector(IEVMBlackjack.InvalidRandomnessRequest.selector, requestId));

        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);
    }

    /*//////////////////////////////////////////////////////////////
    //  Take / Decline Insurance
    //////////////////////////////////////////////////////////////*/

    function test_takeInsurance() public withChips(player) withApproval(player) {
        vm.prank(player);
        uint256 requestId = evmbj.placeBet(BETSIZE1);
        uint256[] memory words = new uint256[](1);
        words[0] = uint256(keccak256("ace"));
        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

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
        uint256 requestId = evmbj.placeBet(BETSIZE1);
        uint256[] memory words = new uint256[](1);
        words[0] = uint256(keccak256("ace"));
        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

        vm.expectEmit(true, true, true, true);
        emit InsuranceTaken(player, true);

        vm.prank(player);
        evmbj.takeInsurance(true);
    }

    function test_declineInsurance() public withChips(player) withApproval(player) {
        vm.prank(player);
        uint256 requestId = evmbj.placeBet(BETSIZE1);
        uint256[] memory words = new uint256[](1);
        words[0] = uint256(keccak256("ace"));
        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

        vm.prank(player);
        evmbj.takeInsurance(false);

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

        assertEq(game.state, IEVMBlackjack.State.READY_FOR_PLAYER_ACTION, "State");
        assertEq(game.insurance, 0, "Insurance");
        assertChips(PLAYER_STARTING_BALANCE - BETSIZE1, HOUSE_STARTING_BALANCE + BETSIZE1);
    }

    function testEvent_declineInsurance() public withChips(player) withApproval(player) {
        vm.prank(player);
        uint256 requestId = evmbj.placeBet(BETSIZE1);
        uint256[] memory words = new uint256[](1);
        words[0] = uint256(keccak256("ace"));

        emit log_named_address("evmbj owner:", evmbj.owner());
        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

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
        uint256 requestId = evmbj.placeBet(BETSIZE1);
        uint256[] memory words = new uint256[](1);
        words[0] = uint256(keccak256("pair of aces"));
        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

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
        uint256 requestId = evmbj.placeBet(BETSIZE1);
        uint256[] memory words = new uint256[](1);
        words[0] = uint256(keccak256("pair of aces"));
        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

        IEVMBlackjack.Game memory previousGame = evmbj.getGame(player);

        vm.prank(player);
        requestId = evmbj.takeAction(IEVMBlackjack.Action.SPLIT);
        words[0] = uint256(keccak256(""));
        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

        assertEq(game.shoeCount, previousGame.shoeCount - 2);
    }

    // function testRevert_splitAces_whenNotPairOfAces() public {

    // }

    // function testRevert_splitAces_thenSplit() public {

    // }

    /*//////////////////////////////////////////////////////////////
    //  Player Action -- Split
    //////////////////////////////////////////////////////////////*/

    function test_split() public withChips(player) withApproval(player) {
        vm.prank(player);
        uint256 requestId = evmbj.placeBet(BETSIZE1);
        uint256[] memory words = new uint256[](1);
        words[0] = uint256(keccak256("pair"));
        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

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
        uint256 requestId = evmbj.placeBet(BETSIZE1);
        uint256[] memory words = new uint256[](1);
        words[0] = uint256(keccak256("pair"));
        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

        IEVMBlackjack.Game memory previousGame = evmbj.getGame(player);

        vm.prank(player);
        requestId = evmbj.takeAction(IEVMBlackjack.Action.SPLIT);
        words[0] = uint256(keccak256(""));
        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

        assertEq(game.state, IEVMBlackjack.State.READY_FOR_PLAYER_ACTION, "State");
        assertEq(game.shoeCount, previousGame.shoeCount - 2);
    }

    function test_split_thenDD_thenDD() public withChips(player) withApproval(player) {
        vm.prank(player);
        uint256 requestId = evmbj.placeBet(BETSIZE1);
        uint256[] memory words = new uint256[](1);
        words[0] = uint256(keccak256("pair"));
        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

        uint256 expectedShoeCount = SHOE_STARTING_COUNT - 3;

        IEVMBlackjack.Game memory game = evmbj.getGame(player);
        assertEq(game.state, IEVMBlackjack.State.READY_FOR_PLAYER_ACTION, "State after bet");
        assertEq(game.lastAction, IEVMBlackjack.Action.NO_ACTION, "Action after bet");
        assertEq(game.totalPlayerHands, 1, "TPH after bet");
        assertEq(game.activePlayerHand, 0, "APH after bet");
        assertEq(game.shoeCount, expectedShoeCount, "Shoe count after bet");
        assertEq(game.playerHands[0].cards.length, 2, "Hand 1 length after bet");

        vm.prank(player);
        requestId = evmbj.takeAction(IEVMBlackjack.Action.SPLIT);
        words[0] = uint256(keccak256("split"));
        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

        game = evmbj.getGame(player);
        assertEq(game.state, IEVMBlackjack.State.READY_FOR_PLAYER_ACTION, "State after split");
        assertEq(game.lastAction, IEVMBlackjack.Action.SPLIT, "Action after split");
        assertEq(game.totalPlayerHands, 2, "TPH after split");
        assertEq(game.activePlayerHand, 0, "APH after split");
        expectedShoeCount -= 2;
        assertEq(game.shoeCount, expectedShoeCount, "Shoe count after split");
        assertEq(game.playerHands[0].cards.length, 2, "Hand 1 length after split");
        assertEq(game.playerHands[1].cards.length, 2, "Hand 2 length after split");

        vm.prank(player);
        requestId = evmbj.takeAction(IEVMBlackjack.Action.DOUBLE_DOWN);
        words[0] = uint256(keccak256(""));
        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

        game = evmbj.getGame(player);
        assertEq(game.state, IEVMBlackjack.State.READY_FOR_PLAYER_ACTION, "State after double 1");
        assertEq(game.lastAction, IEVMBlackjack.Action.DOUBLE_DOWN, "Action after double 1");
        assertEq(game.totalPlayerHands, 2, "TPH after double 1");
        assertEq(game.activePlayerHand, 1, "APH after double 1");
        expectedShoeCount--;
        assertEq(game.shoeCount, expectedShoeCount, "Shoe count after double 1");
        assertEq(game.playerHands[0].cards.length, 3, "Hand 1 length after double 1");
        assertEq(game.playerHands[1].cards.length, 2, "Hand 2 length after double 1");

        vm.prank(player);
        requestId = evmbj.takeAction(IEVMBlackjack.Action.DOUBLE_DOWN);
        words[0] = uint256(keccak256(""));
        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

        game = evmbj.getGame(player);
        assertEq(game.lastAction, IEVMBlackjack.Action.DOUBLE_DOWN, "Action after double 2");
        assertEq(game.totalPlayerHands, 2, "TPH after double 2");
        assertEq(game.activePlayerHand, 2, "APH after double 2");
        expectedShoeCount--;
        assertEq(game.shoeCount, expectedShoeCount, "Shoe count after double 2");
        assertEq(game.playerHands[0].cards.length, 3, "Hand 1 length after double 2");
        assertEq(game.playerHands[1].cards.length, 3, "Hand 2 length after double 2");
    }

    function test_split_thenStand_thenStand() public withChips(player) withApproval(player) {
        vm.prank(player);
        uint256 requestId = evmbj.placeBet(BETSIZE1);
        uint256[] memory words = new uint256[](1);
        words[0] = uint256(keccak256("pair"));
        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

        uint256 expectedShoeCount = SHOE_STARTING_COUNT - 3;

        IEVMBlackjack.Game memory game = evmbj.getGame(player);
        assertEq(game.state, IEVMBlackjack.State.READY_FOR_PLAYER_ACTION, "State after bet");
        assertEq(game.lastAction, IEVMBlackjack.Action.NO_ACTION, "Action after bet");
        assertEq(game.totalPlayerHands, 1, "TPH after bet");
        assertEq(game.activePlayerHand, 0, "APH after bet");
        assertEq(game.shoeCount, expectedShoeCount, "Shoe count after bet");
        assertEq(game.playerHands[0].cards.length, 2, "Hand 1 length after bet");

        vm.prank(player);
        requestId = evmbj.takeAction(IEVMBlackjack.Action.SPLIT);
        words[0] = uint256(keccak256("split"));
        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

        game = evmbj.getGame(player);
        assertEq(game.state, IEVMBlackjack.State.READY_FOR_PLAYER_ACTION, "State after split");
        assertEq(game.lastAction, IEVMBlackjack.Action.SPLIT, "Action after split");
        assertEq(game.totalPlayerHands, 2, "TPH after split");
        assertEq(game.activePlayerHand, 0, "APH after split");
        expectedShoeCount -= 2;
        assertEq(game.shoeCount, expectedShoeCount, "Shoe count after split");
        assertEq(game.playerHands[0].cards.length, 2, "Hand 1 length after split");
        assertEq(game.playerHands[1].cards.length, 2, "Hand 2 length after split");

        vm.prank(player);
        requestId = evmbj.takeAction(IEVMBlackjack.Action.STAND);

        game = evmbj.getGame(player);
        assertEq(game.state, IEVMBlackjack.State.READY_FOR_PLAYER_ACTION, "State after stand 1");
        assertEq(game.lastAction, IEVMBlackjack.Action.STAND, "Action after stand 1");
        assertEq(game.totalPlayerHands, 2, "TPH after stand 1");
        assertEq(game.activePlayerHand, 1, "APH after stand 1");
        assertEq(game.shoeCount, expectedShoeCount, "Shoe count after stand 1"); // no change
        assertEq(game.playerHands[0].cards.length, 2, "Hand 1 length after stand 1"); // no change
        assertEq(game.playerHands[1].cards.length, 2, "Hand 2 length after stand 1"); // no change

        vm.prank(player);
        requestId = evmbj.takeAction(IEVMBlackjack.Action.STAND);

        game = evmbj.getGame(player);
        assertEq(game.lastAction, IEVMBlackjack.Action.STAND, "Action after stand 2");
        assertEq(game.totalPlayerHands, 2, "TPH after stand 2");
        assertEq(game.activePlayerHand, 2, "APH after stand 2");
        assertEq(game.shoeCount, expectedShoeCount, "Shoe count after stand 2"); // no change
        assertEq(game.playerHands[0].cards.length, 2, "Hand 1 length after stand 2"); // no change
        assertEq(game.playerHands[1].cards.length, 2, "Hand 2 length after stand 2"); // no change
    }

    function test_split_thenHitAndStand_thenHitAndStand() public withChips(player) withApproval(player) {}

    // function test_split_andSplit_thenDD_thenDD_thenDD() public withChips(player) withApproval(player) {
    //     vm.prank(player);
    //     uint256 requestId = evmbj.placeBet(BETSIZE1);
    //      vm.prank(address(this));
    //     evmbj.fulfillRandomness(requestId, keccak256("pair"));

    //     uint256 expectedShoeCount = STARTING_SHOE_COUNT - 3;

    //     IEVMBlackjack.Game memory game = evmbj.getGame(player);
    //     assertEq(game.lastAction, IEVMBlackjack.Action.SPLIT);
    //     assertEq(game.totalPlayerHands, 1);
    //     assertEq(game.activePlayerHand, 0);
    //     assertEq(game.shoeCount, --expectedShoeCount);

    //     vm.prank(player);
    //     requestId = evmbj.takeAction(IEVMBlackjack.Action.SPLIT);
    //     vm.prank(address(this));
    //     evmbj.fulfillRandomness(requestId, keccak256("pair"));

    //     game = evmbj.getGame(player);
    //     assertEq(game.lastAction, IEVMBlackjack.Action.SPLIT);
    //     assertEq(game.totalPlayerHands, 2);
    //     assertEq(game.activePlayerHand, 0);
    //     assertEq(game.shoeCount, --expectedShoeCount);

    //     vm.prank(player);
    //     requestId = evmbj.takeAction(IEVMBlackjack.Action.SPLIT);
    //     vm.prank(address(this));
    //     evmbj.fulfillRandomness(requestId, keccak256("pair"));

    //     game = evmbj.getGame(player);
    //     assertEq(game.lastAction, IEVMBlackjack.Action.SPLIT);
    //     assertEq(game.totalPlayerHands, 3);
    //     assertEq(game.activePlayerHand, 0);
    //     assertEq(game.shoeCount, --expectedShoeCount);

    //     vm.prank(player);
    //     requestId = evmbj.takeAction(IEVMBlackjack.Action.DOUBLE_DOWN);
    //     vm.prank(address(this));
    //     evmbj.fulfillRandomness(requestId, keccak256(""));

    //     game = evmbj.getGame(player);
    //     assertEq(game.lastAction, IEVMBlackjack.Action.DOUBLE_DOWN);
    //     assertEq(game.totalPlayerHands, 3);
    //     assertEq(game.activePlayerHand, 1);
    //     assertEq(game.shoeCount, --expectedShoeCount);
    // }

    // function test_split_andSplit_thenHitAndStand_thenHitAndStand_thenHitAndStand() public withChips(player) withApproval(player) {

    // }

    // function test_split_andSplit_thenStand_thenStand_thenStand() public withChips(player) withApproval(player) {

    // }

    // function test_split_andSplit_andSplit_thenDD_thenDD_thenDD_thenDD() public withChips(player) withApproval(player) {

    // }

    // function test_split_andSplit_andSplit_thenHitAndStand_thenHitAndStand_thenHitAndStand_thenHitAndStand() public withChips(player) withApproval(player) {

    // }

    // function test_split_andSplit_andSplit_thenStand_thenStand_thenStand_thenStand_thenStand() public withChips(player) withApproval(player) {

    // }

    // function testRevert_split_andSplit_andSplit_andSplit_andSplit() public withChips(player) withApproval(player) {

    // }

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
        uint256 requestId = evmbj.takeAction(IEVMBlackjack.Action.DOUBLE_DOWN);
        uint256[] memory words = new uint256[](1);
        words[0] = uint256(keccak256(""));

        IEVMBlackjack.Game memory previousGame = evmbj.getGame(player);

        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

        assertEq(game.shoeCount, previousGame.shoeCount - 1, "Shoe count");
        assertNumberOfCards(game.playerHands[0].cards, 3, "Player cards"); // one more card
    }

    function testEvent_doubleDown_andFulfillRandomness()
        public
        withChips(player)
        withApproval(player)
        readyForPlayerAction(player)
    {
        uint256[] memory words = new uint256[](1);
        words[0] = uint256(keccak256(""));

        vm.prank(player);
        uint256 requestId = evmbj.takeAction(IEVMBlackjack.Action.DOUBLE_DOWN);

        // TODO make less brittle re log assertion and hardcoded card
        vm.expectEmit(true, true, true, false);
        emit PlayerCardDealt(player, 15, 0);

        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);
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
        uint256 requestId = evmbj.takeAction(IEVMBlackjack.Action.HIT);
        uint256[] memory words = new uint256[](1);
        words[0] = uint256(keccak256(""));

        IEVMBlackjack.Game memory previousGame = evmbj.getGame(player);

        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);

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
        uint256[] memory words = new uint256[](1);
        words[0] = uint256(keccak256(""));
        vm.prank(player);
        uint256 requestId = evmbj.takeAction(IEVMBlackjack.Action.HIT);

        // TODO make less brittle re log assertion and hardcoded card
        vm.expectEmit(true, true, true, false);
        emit PlayerCardDealt(player, 25, 0);

        vm.prank(address(this));
        evmbj.fulfillRandomness(requestId, words);
    }

    /*//////////////////////////////////////////////////////////////
    //  Player Action -- Stand
    //////////////////////////////////////////////////////////////*/

    function test_stand() public withChips(player) withApproval(player) readyForPlayerAction(player) {
        IEVMBlackjack.Game memory previousGame = evmbj.getGame(player);

        vm.prank(player);
        evmbj.takeAction(IEVMBlackjack.Action.STAND);

        IEVMBlackjack.Game memory game = evmbj.getGame(player);

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
    //  Dealer Action
    //////////////////////////////////////////////////////////////*/

    //

    /*//////////////////////////////////////////////////////////////
    //  Payouts
    //////////////////////////////////////////////////////////////*/
/*
    function test_determineHandOutcome_playerWins() public {
        // Hand 1: Player Win
        // Player Hand: TT
        // Dealer Hand: T7
        uint8[] memory playerCards1 = new uint8[](2);
        playerCards1[0] = 10;
        playerCards1[1] = 23;
        uint8[] memory dealerCards1 = new uint8[](2);
        dealerCards1[0] = 36;
        dealerCards1[1] = 7;
        (IEVMBlackjack.Outcome outcome1, uint8 p, uint8 d) = evmbj.determineHandOutcome(playerCards1, dealerCards1);
        assertEq(outcome1, IEVMBlackjack.Outcome.PLAYER_WIN, "Hand 1");
    }

    function test_determineHandOutcome_dealerWins() public {
        // Hand 2: Dealer Win
        // Player Hand: T5
        // Dealer Hand: T7
        uint8[] memory playerCards2 = new uint8[](2);
        playerCards2[0] = 12;
        playerCards2[1] = 18;
        uint8[] memory dealerCards2 = new uint8[](2);
        dealerCards2[0] = 36;
        dealerCards2[1] = 7;
        (IEVMBlackjack.Outcome outcome2, uint8 p, uint8 d) = evmbj.determineHandOutcome(playerCards2, dealerCards2);
        assertEq(outcome2, IEVMBlackjack.Outcome.DEALER_WIN, "Hand 2");
    }

    function test_determineHandOutcome_tie() public {
        // Hand 3: Tie
        // Player Hand: T7
        // Dealer Hand: T7
        uint8[] memory playerCards3 = new uint8[](2);
        playerCards3[0] = 13;
        playerCards3[1] = 20;
        uint8[] memory dealerCards3 = new uint8[](2);
        dealerCards3[0] = 7;
        dealerCards3[1] = 36;
        (IEVMBlackjack.Outcome outcome3, uint8 p, uint8 d) = evmbj.determineHandOutcome(playerCards3, dealerCards3);
        assertEq(outcome3, IEVMBlackjack.Outcome.TIE, "Hand 3");
    }

    function test_determineHandOutcome_playerWinsWithManyCards() public {
        // Hand 4: Player Win with many cards
        // Player Hand: 5473
        // Dealer Hand: T7
        uint8[] memory playerCards4 = new uint8[](4);
        playerCards4[0] = 5;
        playerCards4[1] = 4;
        playerCards4[2] = 7;
        playerCards4[3] = 18;
        uint8[] memory dealerCards4 = new uint8[](2);
        dealerCards4[0] = 36;
        dealerCards4[1] = 7;
        (IEVMBlackjack.Outcome outcome4, uint8 p, uint8 d) = evmbj.determineHandOutcome(playerCards4, dealerCards4);
        assertEq(outcome4, IEVMBlackjack.Outcome.PLAYER_WIN, "Hand 4");
    }

    function test_determineHandOutcome_dealerWinsWithManyCards() public {
        // Hand 5: Dealer Win with many cards
        // Player Hand: T6
        // Dealer Hand: T233
        uint8[] memory playerCards5 = new uint8[](2);
        playerCards5[0] = 11;
        playerCards5[1] = 6;
        uint8[] memory dealerCards5 = new uint8[](4);
        dealerCards5[0] = 49;
        dealerCards5[1] = 2;
        dealerCards5[2] = 3;
        dealerCards5[3] = 16;
        (IEVMBlackjack.Outcome outcome5, uint8 p, uint8 d) = evmbj.determineHandOutcome(playerCards5, dealerCards5);
        assertEq(outcome5, IEVMBlackjack.Outcome.DEALER_WIN, "Hand 5");
    }

    function test_determineHandOutcome_tieWithManyCards() public {
        // Hand 6: Tie with many cards
        // Player Hand: 8T
        // Dealer Hand: T323
        uint8[] memory playerCards6 = new uint8[](2);
        playerCards6[0] = 8;
        playerCards6[1] = 52;
        uint8[] memory dealerCards6 = new uint8[](4);
        dealerCards6[0] = 50;
        dealerCards6[1] = 16;
        dealerCards6[2] = 2;
        dealerCards6[3] = 3;
        (IEVMBlackjack.Outcome outcome6, uint8 p, uint8 d) = evmbj.determineHandOutcome(playerCards6, dealerCards6);
        assertEq(outcome6, IEVMBlackjack.Outcome.TIE, "Hand 6");
    }
    */

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

    function assertEq(IEVMBlackjack.Outcome a, IEVMBlackjack.Outcome b, string memory reason) internal {
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

    event BetPlaced(address indexed player, uint256 betSize, bytes32 requestId);
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
