// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PredixUmaBondToken} from "../../src/PredixUmaBondToken.sol";

/// @notice Stateful fuzz handler for PredixUmaBondToken invariants.
contract Handler is Test {
    PredixUmaBondToken public token;
    address public minter;
    address public pauser;
    address public risk;
    address public admin;

    uint256 public ghost_totalMinted;
    uint256 public calls;

    constructor(
        PredixUmaBondToken token_,
        address minter_,
        address pauser_,
        address risk_,
        address admin_
    ) {
        token = token_;
        minter = minter_;
        pauser = pauser_;
        risk = risk_;
        admin = admin_;
    }

    function mint(
        uint256 amount,
        address to
    ) public {
        amount = bound(amount, 0, token.maxSupply());
        to = address(uint160(uint256(keccak256(abi.encode(to, amount, calls))) % type(uint160).max));
        if (to == address(0)) to = address(0xBEEF);

        calls++;
        vm.prank(minter);
        try token.mint(to, amount) {
            ghost_totalMinted += amount;
        } catch {}
    }

    function warp(
        uint256 seconds_
    ) public {
        seconds_ = bound(seconds_, 0, 30 days);
        vm.warp(block.timestamp + seconds_);
        calls++;
    }

    function setLimit(
        uint256 newLimit
    ) public {
        newLimit = bound(newLimit, 0, type(uint128).max);
        calls++;
        vm.prank(risk);
        try token.setMintLimitPerWindow(newLimit) {} catch {}
    }

    function pause() public {
        calls++;
        vm.prank(pauser);
        try token.pause() {} catch {}
    }

    function unpause() public {
        calls++;
        vm.prank(pauser);
        try token.unpause() {} catch {}
    }
}
