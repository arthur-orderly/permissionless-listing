// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/ListingRegistry.sol";
import "../src/ListingStake.sol";
import "../src/libraries/ListingLib.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USDC", "USDC") {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
    function decimals() public pure override returns (uint8) { return 6; }
}

contract ListingStakeTest is Test {
    ListingRegistry public registry;
    ListingStake public staking;
    MockUSDC public usdc;
    
    address admin = address(1);
    address lister = address(2);
    address oracle = address(3);
    address insuranceFund = address(4);

    function setUp() public {
        usdc = new MockUSDC();

        ListingRegistry regImpl = new ListingRegistry();
        ERC1967Proxy regProxy = new ERC1967Proxy(
            address(regImpl), abi.encodeCall(ListingRegistry.initialize, (admin))
        );
        registry = ListingRegistry(address(regProxy));

        ListingStake stakeImpl = new ListingStake();
        ERC1967Proxy stakeProxy = new ERC1967Proxy(
            address(stakeImpl),
            abi.encodeCall(ListingStake.initialize, (
                admin, address(usdc), address(registry), insuranceFund, 50_000e6, 180 days
            ))
        );
        staking = ListingStake(address(stakeProxy));

        vm.startPrank(admin);
        registry.grantRole(registry.LISTER_ROLE(), lister);
        registry.grantRole(registry.ORACLE_ROLE(), oracle);
        staking.grantRole(staking.ORACLE_ROLE(), oracle);
        vm.stopPrank();

        usdc.mint(lister, 200_000e6);
        vm.prank(lister);
        usdc.approve(address(staking), type(uint256).max);
    }

    function _createListing() internal returns (uint256) {
        uint256 mcap = 200_000_000e18;
        uint256 imr = ListingLib.imrFromLeverage(20);
        uint256 mmr = ListingLib.mmrFromImr(imr, mcap);
        IListingRegistry.ListingParams memory params = IListingRegistry.ListingParams({
            baseSpread: 100, maxLeverage: 20, baseImr: imr, baseMmr: mmr,
            fundingPeriod: 28800, minNotional: 10e6, takerFeeMarkup: 2,
            makerFeeMarkup: 1, marketCapUsd: mcap
        });
        vm.prank(lister);
        return registry.createListing("PEPE", params);
    }

    function test_stakeAndUnstake() public {
        uint256 id = _createListing();

        vm.prank(lister);
        staking.stake(id, 50_000e6);

        (uint256 amt, , bool locked) = staking.getStake(id);
        assertEq(amt, 50_000e6);
        assertTrue(locked);

        // Cannot unstake while locked
        vm.prank(lister);
        vm.expectRevert();
        staking.unstake(id);

        // Warp past lock + delist
        vm.warp(block.timestamp + 181 days);
        vm.prank(admin);
        registry.activateListing(id);
        vm.prank(lister);
        registry.deactivateListing(id);

        vm.prank(lister);
        staking.unstake(id);
        assertEq(usdc.balanceOf(lister), 200_000e6);
    }

    function test_slash100Percent() public {
        uint256 id = _createListing();
        vm.prank(lister);
        staking.stake(id, 100_000e6);

        vm.prank(oracle);
        staking.slash(id, 10_000, "Rug pull");

        (uint256 amt,,) = staking.getStake(id);
        assertEq(amt, 0);
        assertEq(usdc.balanceOf(insuranceFund), 100_000e6);
    }

    function test_slash50Percent() public {
        uint256 id = _createListing();
        vm.prank(lister);
        staking.stake(id, 100_000e6);

        vm.prank(oracle);
        staking.slash(id, 5_000, "Listing abandonment");

        (uint256 amt,,) = staking.getStake(id);
        assertEq(amt, 50_000e6);
        assertEq(usdc.balanceOf(insuranceFund), 50_000e6);
    }

    function test_insufficientStake() public {
        uint256 id = _createListing();
        vm.prank(lister);
        vm.expectRevert();
        staking.stake(id, 10_000e6); // below 50K min
    }
}
