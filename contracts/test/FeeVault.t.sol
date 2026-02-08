// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/FeeVault.sol";

contract MockToken is ERC20 {
    constructor() ERC20("USDC", "USDC") {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
}

contract FeeVaultTest is Test {
    FeeVault public vault;
    MockToken public usdc;
    
    address admin = address(1);
    address collector = address(2);
    address lister = address(3);
    address treasury = address(4);
    address insurance = address(5);

    function setUp() public {
        usdc = new MockToken();
        
        FeeVault impl = new FeeVault();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(impl),
            abi.encodeCall(FeeVault.initialize, (admin, treasury, insurance, 5000, 3000, 2000))
        );
        vault = FeeVault(address(proxy));

        vm.startPrank(admin);
        vault.grantRole(vault.COLLECTOR_ROLE(), collector);
        vm.stopPrank();

        usdc.mint(collector, 1_000_000e6);
        vm.prank(collector);
        usdc.approve(address(vault), type(uint256).max);
    }

    function test_collectAndDistribute() public {
        vm.prank(collector);
        vault.collectFees(address(usdc), 0, 10_000e6, lister);

        assertEq(vault.accumulatedFees(address(usdc), 0), 10_000e6);

        vault.distributeFees(address(usdc), 0);

        assertEq(usdc.balanceOf(treasury), 5_000e6);    // 50%
        assertEq(usdc.balanceOf(lister), 3_000e6);      // 30%
        assertEq(usdc.balanceOf(insurance), 2_000e6);    // 20%
    }

    function test_updateFeeSplit() public {
        vm.prank(admin);
        vault.updateFeeSplit(4000, 4000, 2000);

        (uint256 p, uint256 l, uint256 i) = vault.feeSplit();
        assertEq(p, 4000);
        assertEq(l, 4000);
        assertEq(i, 2000);
    }

    function test_invalidFeeSplit() public {
        vm.prank(admin);
        vm.expectRevert();
        vault.updateFeeSplit(5000, 5000, 5000); // > 10000
    }

    function test_noFeesToDistribute() public {
        vm.expectRevert();
        vault.distributeFees(address(usdc), 999);
    }
}
