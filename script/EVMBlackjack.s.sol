// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "forge-std/Script.sol";

import "../src/Chip.sol";
import "../src/EVMBlackjack.sol";

// forge script EVMBlackjackDeployScript --rpc-url=$SEPOLIA_RPC_URL --broadcast --slow --verify "$ETHERSCAN_API_KEY" --chain-id=11155111 --watch
contract EVMBlackjackDeployScript is Script {
    address vrfCoordinator;
    uint64 subscriptionId;
    bytes32 keyHash;

    function run() public {
        // Get environment variables
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        // Start recording calls and contract creations
        vm.startBroadcast(privateKey);

        // Create contracts
        Chip chip = new Chip();
        EVMBlackjack evmbj = new EVMBlackjack(
            chip, 
            vrfCoordinator,
            subscriptionId,
            keyHash);
        chip.houseMint(address(evmbj));

        // Stop recording
        vm.stopBroadcast();
    }
}
