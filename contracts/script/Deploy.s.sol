// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/ListingRegistry.sol";
import "../src/ListingStake.sol";
import "../src/FeeVault.sol";
import "../src/SlashingOracle.sol";

/// @notice Deploy all Permissionless Listing contracts to Arbitrum
contract Deploy is Script {
    // Arbitrum USDC
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    function run() external {
        address deployer = vm.envAddress("DEPLOYER");
        address insuranceFund = vm.envAddress("INSURANCE_FUND");
        address protocolTreasury = vm.envAddress("PROTOCOL_TREASURY");

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // 1. Deploy implementations
        ListingRegistry registryImpl = new ListingRegistry();
        ListingStake stakeImpl = new ListingStake();
        FeeVault feeVaultImpl = new FeeVault();
        SlashingOracle oracleImpl = new SlashingOracle();

        // 2. Deploy proxies
        ERC1967Proxy registryProxy = new ERC1967Proxy(
            address(registryImpl),
            abi.encodeCall(ListingRegistry.initialize, (deployer))
        );

        ERC1967Proxy stakeProxy = new ERC1967Proxy(
            address(stakeImpl),
            abi.encodeCall(ListingStake.initialize, (
                deployer,
                USDC,
                address(registryProxy),
                insuranceFund,
                50_000e6,       // $50K min stake
                180 days        // 6 month lock
            ))
        );

        ERC1967Proxy feeVaultProxy = new ERC1967Proxy(
            address(feeVaultImpl),
            abi.encodeCall(FeeVault.initialize, (
                deployer,
                protocolTreasury,
                insuranceFund,
                5000,  // 50% protocol
                3000,  // 30% lister
                2000   // 20% insurance
            ))
        );

        ERC1967Proxy oracleProxy = new ERC1967Proxy(
            address(oracleImpl),
            abi.encodeCall(SlashingOracle.initialize, (
                deployer,
                address(stakeProxy)
            ))
        );

        // 3. Grant roles
        ListingRegistry registry = ListingRegistry(address(registryProxy));
        ListingStake stakeContract = ListingStake(address(stakeProxy));

        // Grant ORACLE_ROLE to SlashingOracle so it can call slash()
        stakeContract.grantRole(stakeContract.ORACLE_ROLE(), address(oracleProxy));

        vm.stopBroadcast();

        // Log addresses
        console.log("ListingRegistry:", address(registryProxy));
        console.log("ListingStake:", address(stakeProxy));
        console.log("FeeVault:", address(feeVaultProxy));
        console.log("SlashingOracle:", address(oracleProxy));
    }
}
