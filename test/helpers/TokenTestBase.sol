// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PredixUmaBondToken} from "../../src/PredixUmaBondToken.sol";

/// @notice Shared fixture for PredixUmaBondToken tests.
abstract contract TokenTestBase is Test {
    PredixUmaBondToken internal token;

    address internal admin = makeAddr("admin");
    address internal minter = makeAddr("minter");
    address internal pauser = makeAddr("pauser");
    address internal risk = makeAddr("risk");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal stranger = makeAddr("stranger");

    uint256 internal constant MAX_SUPPLY = 10_000_000 ether;
    uint256 internal constant MINT_LIMIT = 1_000_000 ether;
    uint256 internal constant WINDOW = 1 days;

    string internal constant TOKEN_NAME = "PrediX UMA Bond";
    string internal constant TOKEN_SYMBOL = "pUMAB";

    bytes32 internal minterRole;
    bytes32 internal pauserRole;

    function setUp() public virtual {
        token = new PredixUmaBondToken(
            TOKEN_NAME, TOKEN_SYMBOL, MAX_SUPPLY, admin, minter, pauser, risk, MINT_LIMIT, WINDOW
        );

        minterRole = token.MINTER_ROLE();
        pauserRole = token.PAUSER_ROLE();
    }

    function _raiseMintLimitToMaxSupply() internal {
        vm.prank(risk);
        token.setMintLimitPerWindow(MAX_SUPPLY);
    }

    function _mintAsMinter(
        address to,
        uint256 amount
    ) internal {
        vm.prank(minter);
        token.mint(to, amount);
    }
}
