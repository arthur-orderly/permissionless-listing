// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/ListingRegistry.sol";
import "../src/interfaces/IListingRegistry.sol";
import "../src/libraries/ListingLib.sol";

contract ListingRegistryTest is Test {
    ListingRegistry public registry;
    address admin = address(1);
    address lister = address(2);
    address oracle = address(3);

    function setUp() public {
        ListingRegistry impl = new ListingRegistry();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl), abi.encodeCall(ListingRegistry.initialize, (admin))
        );
        registry = ListingRegistry(address(proxy));

        vm.startPrank(admin);
        registry.grantRole(registry.LISTER_ROLE(), lister);
        registry.grantRole(registry.ORACLE_ROLE(), oracle);
        vm.stopPrank();
    }

    function _defaultParams(uint256 leverage, uint256 mcap) internal pure returns (IListingRegistry.ListingParams memory) {
        uint256 imr = ListingLib.imrFromLeverage(leverage);
        uint256 mmr = ListingLib.mmrFromImr(imr, mcap);
        return IListingRegistry.ListingParams({
            baseSpread: 100,
            maxLeverage: leverage,
            baseImr: imr,
            baseMmr: mmr,
            fundingPeriod: 28800,
            minNotional: 10e6,
            takerFeeMarkup: 2,
            makerFeeMarkup: 1,
            marketCapUsd: mcap
        });
    }

    function test_createListing() public {
        IListingRegistry.ListingParams memory params = _defaultParams(20, 200_000_000e18);
        vm.prank(lister);
        uint256 id = registry.createListing("PEPE", params);
        assertEq(id, 0);
        
        IListingRegistry.Listing memory l = registry.getListing(0);
        assertEq(l.lister, lister);
        assertEq(uint(l.status), uint(IListingRegistry.ListingStatus.Pending));
        assertEq(l.params.maxLeverage, 20);
    }

    function test_leverageCap_low() public {
        // mcap < $30M → max 5x
        IListingRegistry.ListingParams memory params = _defaultParams(5, 20_000_000e18);
        vm.prank(lister);
        registry.createListing("SMALL", params);

        // Should revert with 10x at low mcap
        params.maxLeverage = 10;
        params.baseImr = 1000;
        params.baseMmr = 600;
        vm.prank(lister);
        vm.expectRevert();
        registry.createListing("SMALL2", params);
    }

    function test_leverageCap_mid() public {
        // mcap $50M → max 10x
        IListingRegistry.ListingParams memory params = _defaultParams(10, 50_000_000e18);
        vm.prank(lister);
        registry.createListing("MID", params);
    }

    function test_activateAndDeactivate() public {
        IListingRegistry.ListingParams memory params = _defaultParams(20, 200_000_000e18);
        vm.prank(lister);
        uint256 id = registry.createListing("PEPE", params);

        vm.prank(admin);
        registry.activateListing(id);
        assertEq(uint(registry.getListing(id).status), uint(IListingRegistry.ListingStatus.Active));

        vm.prank(lister);
        registry.deactivateListing(id);
        assertEq(uint(registry.getListing(id).status), uint(IListingRegistry.ListingStatus.Delisted));
    }

    function test_duplicateSymbol() public {
        IListingRegistry.ListingParams memory params = _defaultParams(20, 200_000_000e18);
        vm.prank(lister);
        registry.createListing("PEPE", params);

        vm.prank(lister);
        vm.expectRevert();
        registry.createListing("PEPE", params);
    }

    function test_feeMarkupBounds() public {
        IListingRegistry.ListingParams memory params = _defaultParams(20, 200_000_000e18);
        params.takerFeeMarkup = 6; // exceeds 5 bps
        vm.prank(lister);
        vm.expectRevert();
        registry.createListing("BAD", params);
    }

    function test_updateParams() public {
        IListingRegistry.ListingParams memory params = _defaultParams(20, 200_000_000e18);
        vm.prank(lister);
        uint256 id = registry.createListing("PEPE", params);

        params.takerFeeMarkup = 5;
        vm.prank(lister);
        registry.updateParams(id, params);

        assertEq(registry.getListing(id).params.takerFeeMarkup, 5);
    }

    function test_mmrException() public {
        // mcap $50M, 10x → MMR should be 6% (exception)
        uint256 mcap = 50_000_000e18;
        IListingRegistry.ListingParams memory params = _defaultParams(10, mcap);
        assertEq(params.baseMmr, 600); // 6%
        
        vm.prank(lister);
        registry.createListing("MID", params);
    }
}
