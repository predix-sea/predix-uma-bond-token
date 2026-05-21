// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {PredixUmaBondToken} from "../src/PredixUmaBondToken.sol";
import {TokenTestBase} from "./helpers/TokenTestBase.sol";

contract PredixUmaBondTokenFuzzTest is TokenTestBase {
    function testFuzz_Mint_NeverExceedsMaxSupply(
        uint256 amount
    ) public {
        amount = bound(amount, 0, MINT_LIMIT);
        _mintAsMinter(alice, amount);
        assertLe(token.totalSupply(), MAX_SUPPLY);
        assertEq(token.totalSupply(), amount);
    }

    function testFuzz_Mint_RateLimitBound(
        uint256 first,
        uint256 second
    ) public {
        first = bound(first, 0, MINT_LIMIT);
        second = bound(second, 0, MINT_LIMIT);

        if (first > 0) _mintAsMinter(alice, first);

        uint256 remaining = MINT_LIMIT - token.mintedInWindow();
        if (second > remaining) {
            vm.prank(minter);
            vm.expectRevert();
            token.mint(bob, second);
        } else if (first + second <= MAX_SUPPLY) {
            _mintAsMinter(bob, second);
            assertLe(token.mintedInWindow(), MINT_LIMIT);
        }
    }

    function testFuzz_StrangerCannotMint(
        uint256 amount,
        address caller
    ) public {
        vm.assume(caller != minter);
        vm.assume(!token.hasRole(minterRole, caller));
        amount = bound(amount, 1, MINT_LIMIT);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, caller, minterRole)
        );
        vm.prank(caller);
        token.mint(alice, amount);
    }

    function testFuzz_WindowRollResetsCounter(
        uint256 warpExtra,
        uint256 mintAmount
    ) public {
        mintAmount = bound(mintAmount, 1, MINT_LIMIT);
        _mintAsMinter(alice, mintAmount);

        warpExtra = bound(warpExtra, WINDOW, WINDOW * 30);
        vm.warp(block.timestamp + warpExtra);

        _mintAsMinter(bob, mintAmount);
        assertEq(token.mintedInWindow(), mintAmount);
    }

    function testFuzz_SetMintLimit_OnlyRiskOrAdmin(
        address caller,
        uint256 newLimit
    ) public {
        vm.assume(caller != risk && caller != admin);
        vm.assume(!token.hasRole(token.RISK_ROLE(), caller));
        vm.assume(!token.hasRole(token.DEFAULT_ADMIN_ROLE(), caller));

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(PredixUmaBondToken.UnauthorizedRiskOrAdmin.selector, caller));
        token.setMintLimitPerWindow(newLimit);
    }
}
