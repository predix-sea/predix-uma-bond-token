// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {PredixUmaBondToken} from "../src/PredixUmaBondToken.sol";
import {TokenTestBase} from "./helpers/TokenTestBase.sol";

contract PredixUmaBondTokenTest is TokenTestBase {
    // -------------------------------------------------------------------------
    // Constructor / metadata
    // -------------------------------------------------------------------------

    function test_Constructor_SetsMetadataAndRoles() public view {
        assertEq(token.name(), TOKEN_NAME);
        assertEq(token.symbol(), TOKEN_SYMBOL);
        assertEq(token.maxSupply(), MAX_SUPPLY);
        assertEq(token.mintLimitPerWindow(), MINT_LIMIT);
        assertEq(token.mintWindowSizeSeconds(), WINDOW);
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));
        assertTrue(token.hasRole(token.PAUSER_ROLE(), pauser));
        assertTrue(token.hasRole(token.RISK_ROLE(), risk));
    }

    function test_Constructor_RevertsOnZeroAdmin() public {
        vm.expectRevert(PredixUmaBondToken.ZeroAddress.selector);
        new PredixUmaBondToken(
            TOKEN_NAME, TOKEN_SYMBOL, MAX_SUPPLY, address(0), minter, pauser, risk, MINT_LIMIT, WINDOW
        );
    }

    function test_Constructor_RevertsOnZeroWindow() public {
        vm.expectRevert(PredixUmaBondToken.InvalidMintWindowSize.selector);
        new PredixUmaBondToken(TOKEN_NAME, TOKEN_SYMBOL, MAX_SUPPLY, admin, minter, pauser, risk, MINT_LIMIT, 0);
    }

    // -------------------------------------------------------------------------
    // Roles
    // -------------------------------------------------------------------------

    function test_Mint_OnlyMinter() public {
        _mintAsMinter(alice, 100 ether);
        assertEq(token.balanceOf(alice), 100 ether);

        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, minterRole)
        );
        token.mint(alice, 1 ether);
    }

    function test_Admin_CanGrantAndRevokeMinter() public {
        address newMinter = makeAddr("newMinter");
        vm.startPrank(admin);
        token.grantRole(minterRole, newMinter);
        vm.stopPrank();

        vm.prank(newMinter);
        token.mint(alice, 1 ether);

        vm.startPrank(admin);
        token.revokeRole(minterRole, newMinter);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, newMinter, minterRole)
        );
        vm.prank(newMinter);
        token.mint(alice, 1 ether);
    }

    function test_Pause_OnlyPauser() public {
        vm.prank(pauser);
        token.pause();

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, stranger, pauserRole)
        );
        vm.prank(stranger);
        token.pause();
    }

    // -------------------------------------------------------------------------
    // Mint / maxSupply
    // -------------------------------------------------------------------------

    function test_Mint_SuccessAndEmitsBondMinted() public {
        vm.expectEmit(true, true, false, true);
        emit PredixUmaBondToken.BondMinted(minter, alice, 500 ether);
        _mintAsMinter(alice, 500 ether);
        assertEq(token.totalSupply(), 500 ether);
    }

    function test_Mint_RevertsZeroAddress() public {
        vm.prank(minter);
        vm.expectRevert(PredixUmaBondToken.ZeroAddress.selector);
        token.mint(address(0), 1 ether);
    }

    function test_Mint_RevertsWhenExceedsMaxSupply() public {
        _raiseMintLimitToMaxSupply();
        _mintAsMinter(alice, MAX_SUPPLY - 1 ether);
        vm.warp(block.timestamp + WINDOW + 1);
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(PredixUmaBondToken.ExceedsMaxSupply.selector, 2 ether, 1 ether));
        token.mint(alice, 2 ether);
    }

    function test_Mint_RevertsAtExactMaxSupplyPlusOne() public {
        _raiseMintLimitToMaxSupply();
        _mintAsMinter(alice, MAX_SUPPLY);
        vm.warp(block.timestamp + WINDOW + 1);
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(PredixUmaBondToken.ExceedsMaxSupply.selector, 1, 0));
        token.mint(alice, 1);
    }

    // -------------------------------------------------------------------------
    // Rate limit
    // -------------------------------------------------------------------------

    function test_Mint_RateLimitWithinWindow() public {
        _mintAsMinter(alice, MINT_LIMIT);
        assertEq(token.mintedInWindow(), MINT_LIMIT);
    }

    function test_Mint_RateLimitRevertsOverWindow() public {
        _mintAsMinter(alice, MINT_LIMIT);
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(PredixUmaBondToken.MintRateLimitExceeded.selector, 1 ether, 0));
        token.mint(alice, 1 ether);
    }

    function test_Mint_WindowRollsAfterExpiry() public {
        _mintAsMinter(alice, MINT_LIMIT);
        vm.warp(block.timestamp + WINDOW + 1);
        _mintAsMinter(bob, MINT_LIMIT);
        assertEq(token.balanceOf(bob), MINT_LIMIT);
        assertEq(token.mintedInWindow(), MINT_LIMIT);
    }

    function test_RemainingMintInWindow_AfterPartialMint() public view {
        // fresh token in setUp
        assertEq(token.remainingMintInWindow(), MINT_LIMIT);
    }

    function test_RemainingMaxSupply_View() public {
        _mintAsMinter(alice, 100 ether);
        assertEq(token.remainingMaxSupply(), MAX_SUPPLY - 100 ether);
    }

    function test_RemainingMintInWindow_AfterWindowExpiry() public {
        vm.warp(block.timestamp + WINDOW + 1);
        assertEq(token.remainingMintInWindow(), MINT_LIMIT);
    }

    // -------------------------------------------------------------------------
    // Pause (mint only; transfers continue)
    // -------------------------------------------------------------------------

    function test_Pause_BlocksMintNotTransfer() public {
        _mintAsMinter(alice, 100 ether);

        vm.prank(pauser);
        vm.expectEmit(true, false, false, false);
        emit PredixUmaBondToken.BondPaused(pauser);
        token.pause();

        vm.prank(minter);
        vm.expectRevert();
        token.mint(bob, 1 ether);

        vm.prank(alice);
        token.transfer(bob, 50 ether);
        assertEq(token.balanceOf(bob), 50 ether);
    }

    function test_Unpause_AllowsMintAgain() public {
        vm.prank(pauser);
        token.pause();

        vm.prank(pauser);
        vm.expectEmit(true, false, false, false);
        emit PredixUmaBondToken.BondUnpaused(pauser);
        token.unpause();

        _mintAsMinter(alice, 1 ether);
        assertEq(token.balanceOf(alice), 1 ether);
    }

    // -------------------------------------------------------------------------
    // Risk / admin parameters
    // -------------------------------------------------------------------------

    function test_SetMintLimit_RiskRole() public {
        vm.prank(risk);
        vm.expectEmit(false, false, false, true);
        emit PredixUmaBondToken.BondMintLimitUpdated(MINT_LIMIT, 2_000_000 ether);
        token.setMintLimitPerWindow(2_000_000 ether);
        assertEq(token.mintLimitPerWindow(), 2_000_000 ether);
    }

    function test_SetMintLimit_AdminRole() public {
        vm.prank(admin);
        token.setMintLimitPerWindow(500_000 ether);
        assertEq(token.mintLimitPerWindow(), 500_000 ether);
    }

    function test_SetMintLimit_RevertsStranger() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(PredixUmaBondToken.UnauthorizedRiskOrAdmin.selector, stranger));
        token.setMintLimitPerWindow(1);
    }

    function test_SetMintWindow_RiskRole() public {
        vm.prank(risk);
        vm.expectEmit(false, false, false, true);
        emit PredixUmaBondToken.BondMintWindowUpdated(WINDOW, 12 hours);
        token.setMintWindowSizeSeconds(12 hours);
        assertEq(token.mintWindowSizeSeconds(), 12 hours);
    }

    function test_SetMintWindow_RevertsZero() public {
        vm.prank(risk);
        vm.expectRevert(PredixUmaBondToken.InvalidMintWindowSize.selector);
        token.setMintWindowSizeSeconds(0);
    }

    function test_SetMintLimit_RevertsBelowMintedInWindow() public {
        _mintAsMinter(alice, 100 ether);
        vm.prank(risk);
        vm.expectRevert(
            abi.encodeWithSelector(PredixUmaBondToken.MintLimitBelowCurrentWindowUsage.selector, 100 ether, 50 ether)
        );
        token.setMintLimitPerWindow(50 ether);
    }

    // -------------------------------------------------------------------------
    // Permit (EIP-2612)
    // -------------------------------------------------------------------------

    function test_Permit_Success() public {
        uint256 ownerKey = 0xA11CE;
        address owner = vm.addr(ownerKey);
        _mintAsMinter(owner, 1000 ether);

        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(owner);

        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                bob,
                100 ether,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, digest);

        token.permit(owner, bob, 100 ether, deadline, v, r, s);
        assertEq(token.allowance(owner, bob), 100 ether);

        vm.prank(bob);
        token.transferFrom(owner, bob, 100 ether);
        assertEq(token.balanceOf(bob), 100 ether);
    }

    function test_Permit_WorksWhilePaused() public {
        uint256 ownerKey = 0xB0B;
        address owner = vm.addr(ownerKey);
        _mintAsMinter(owner, 100 ether);

        vm.prank(pauser);
        token.pause();

        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(owner);
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner,
                bob,
                10 ether,
                nonce,
                deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, digest);

        token.permit(owner, bob, 10 ether, deadline, v, r, s);
        assertEq(token.allowance(owner, bob), 10 ether);
    }
}
