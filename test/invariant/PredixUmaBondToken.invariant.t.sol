// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PredixUmaBondToken} from "../../src/PredixUmaBondToken.sol";
import {Handler} from "./Handler.sol";

contract PredixUmaBondTokenInvariantTest is Test {
    PredixUmaBondToken internal token;
    Handler internal handler;

    address internal admin = makeAddr("admin");
    address internal minter = makeAddr("minter");
    address internal pauser = makeAddr("pauser");
    address internal risk = makeAddr("risk");

    uint256 internal constant MAX_SUPPLY = 100_000_000 ether;
    uint256 internal constant MINT_LIMIT = 5_000_000 ether;
    uint256 internal constant WINDOW = 1 days;

    function setUp() public {
        token = new PredixUmaBondToken(
            "PrediX UMA Bond", "pUMAB", MAX_SUPPLY, admin, minter, pauser, risk, MINT_LIMIT, WINDOW
        );
        handler = new Handler(token, minter, pauser, risk, admin);
        targetContract(address(handler));
    }

    function invariant_totalSupplyNeverExceedsMaxSupply() public view {
        assertLe(token.totalSupply(), token.maxSupply());
    }

    function invariant_mintedInWindowNeverExceedsLimit() public view {
        if (block.timestamp >= token.mintWindowStart() + token.mintWindowSizeSeconds()) {
            // Window expired; next mint will reset — counter may appear stale until then.
            return;
        }
        assertLe(token.mintedInWindow(), token.mintLimitPerWindow());
    }

    function invariant_strangerCannotMintWithoutRole() public view {
        assertFalse(token.hasRole(token.MINTER_ROLE(), address(0xdead)));
    }
}
