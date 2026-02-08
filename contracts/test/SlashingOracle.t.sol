// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/ListingRegistry.sol";
import "../src/ListingStake.sol";
import "../src/SlashingOracle.sol";
import "../src/libraries/ListingLib.sol";

contract MockUSDC2 is ERC20 {
    constructor() ERC20("USDC", "USDC") {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
    function decimals() public pure override returns (uint8) { return 6; }
}

contract SlashingOracleTest is Test {
    ListingRegistry public registry;
    ListingStake public staking;
    SlashingOracle public oracle;
    MockUSDC2 public usdc;

    address admin = address(1);
    address lister = address(2);
    address insuranceFund = address(10);
    address[5] voters;

    function setUp() public {
        for (uint i = 0; i < 5; i++) voters[i] = address(uint160(100 + i));
        usdc = new MockUSDC2();

        // Registry
        ListingRegistry regImpl = new ListingRegistry();
        ERC1967Proxy regProxy = new ERC1967Proxy(
            address(regImpl), abi.encodeCall(ListingRegistry.initialize, (admin))
        );
        registry = ListingRegistry(address(regProxy));

        // Staking
        ListingStake stakeImpl = new ListingStake();
        ERC1967Proxy stakeProxy = new ERC1967Proxy(
            address(stakeImpl),
            abi.encodeCall(ListingStake.initialize, (
                admin, address(usdc), address(registry), insuranceFund, 50_000e6, 180 days
            ))
        );
        staking = ListingStake(address(stakeProxy));

        // Oracle
        SlashingOracle oracleImpl = new SlashingOracle();
        ERC1967Proxy oracleProxy = new ERC1967Proxy(
            address(oracleImpl),
            abi.encodeCall(SlashingOracle.initialize, (admin, address(staking)))
        );
        oracle = SlashingOracle(address(oracleProxy));

        // Roles
        vm.startPrank(admin);
        registry.grantRole(registry.LISTER_ROLE(), lister);
        staking.grantRole(staking.ORACLE_ROLE(), address(oracle));
        for (uint i = 0; i < 5; i++) {
            oracle.grantRole(oracle.VOTER_ROLE(), voters[i]);
        }
        vm.stopPrank();

        // Fund lister
        usdc.mint(lister, 200_000e6);
        vm.prank(lister);
        usdc.approve(address(staking), type(uint256).max);
    }

    function _createAndStake() internal returns (uint256) {
        uint256 mcap = 200_000_000e18;
        uint256 imr = ListingLib.imrFromLeverage(20);
        uint256 mmr = ListingLib.mmrFromImr(imr, mcap);
        IListingRegistry.ListingParams memory params = IListingRegistry.ListingParams({
            baseSpread: 100, maxLeverage: 20, baseImr: imr, baseMmr: mmr,
            fundingPeriod: 28800, minNotional: 10e6, takerFeeMarkup: 0,
            makerFeeMarkup: 0, marketCapUsd: mcap
        });
        vm.prank(lister);
        uint256 id = registry.createListing("PEPE", params);
        vm.prank(lister);
        staking.stake(id, 100_000e6);
        return id;
    }

    function test_fullSlashFlow() public {
        uint256 listingId = _createAndStake();

        // Propose
        vm.prank(voters[0]);
        uint256 pid = oracle.proposeSlash(listingId, 10_000, "Rug pull confirmed");

        // Vote (need 2 more for quorum of 3, proposer already voted)
        vm.prank(voters[1]);
        oracle.voteSlash(pid);
        vm.prank(voters[2]);
        oracle.voteSlash(pid);

        // Cannot execute before timelock
        vm.prank(voters[0]);
        vm.expectRevert();
        oracle.executeSlash(pid);

        // Warp past timelock
        vm.warp(block.timestamp + 49 hours);

        vm.prank(voters[0]);
        oracle.executeSlash(pid);

        // Verify slash happened
        (uint256 amt,,) = staking.getStake(listingId);
        assertEq(amt, 0);
        assertEq(usdc.balanceOf(insuranceFund), 100_000e6);
    }

    function test_quorumNotReached() public {
        uint256 listingId = _createAndStake();

        vm.prank(voters[0]);
        uint256 pid = oracle.proposeSlash(listingId, 5_000, "Abandonment");

        vm.prank(voters[1]);
        oracle.voteSlash(pid);

        // Only 2 votes, need 3
        vm.warp(block.timestamp + 49 hours);
        vm.prank(voters[0]);
        vm.expectRevert();
        oracle.executeSlash(pid);
    }

    function test_cancelSlash() public {
        uint256 listingId = _createAndStake();

        vm.prank(voters[0]);
        uint256 pid = oracle.proposeSlash(listingId, 5_000, "False alarm");

        vm.prank(admin);
        oracle.cancelSlash(pid);

        vm.prank(voters[1]);
        vm.expectRevert();
        oracle.voteSlash(pid);
    }

    function test_doubleVote() public {
        uint256 listingId = _createAndStake();

        vm.prank(voters[0]);
        uint256 pid = oracle.proposeSlash(listingId, 5_000, "Test");

        vm.prank(voters[0]);
        vm.expectRevert();
        oracle.voteSlash(pid);
    }
}
