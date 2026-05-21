// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {PredixUmaBondToken} from "../src/PredixUmaBondToken.sol";

/// @title Deploy
/// @notice Deploys `PredixUmaBondToken` from environment variables and asserts post-deploy invariants.
/// @dev Required env: TOKEN_NAME, TOKEN_SYMBOL, MAX_SUPPLY, ADMIN_ADDRESS, MINTER_ADDRESS,
///      PAUSER_ADDRESS, RISK_ADDRESS, MINT_LIMIT_PER_WINDOW, MINT_WINDOW_SECONDS, PRIVATE_KEY, RPC_URL.
contract Deploy is Script {
    function run() external returns (PredixUmaBondToken token) {
        string memory name = vm.envString("TOKEN_NAME");
        string memory symbol = vm.envString("TOKEN_SYMBOL");
        uint256 maxSupply = vm.envUint("MAX_SUPPLY");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address minter = vm.envAddress("MINTER_ADDRESS");
        address pauser = vm.envAddress("PAUSER_ADDRESS");
        address risk = vm.envAddress("RISK_ADDRESS");
        uint256 mintLimit = vm.envUint("MINT_LIMIT_PER_WINDOW");
        uint256 mintWindow = vm.envUint("MINT_WINDOW_SECONDS");

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        token = new PredixUmaBondToken(name, symbol, maxSupply, admin, minter, pauser, risk, mintLimit, mintWindow);

        vm.stopBroadcast();

        _assertDeployment(token, name, symbol, maxSupply, admin, minter, pauser, risk, mintLimit, mintWindow);
        _logSummary(token, admin, minter, pauser, risk, mintLimit, mintWindow);
    }

    function _assertDeployment(
        PredixUmaBondToken token,
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        address admin,
        address minter,
        address pauser,
        address risk,
        uint256 mintLimit,
        uint256 mintWindow
    ) internal view {
        require(keccak256(bytes(token.name())) == keccak256(bytes(name)), "name mismatch");
        require(keccak256(bytes(token.symbol())) == keccak256(bytes(symbol)), "symbol mismatch");
        require(token.maxSupply() == maxSupply, "maxSupply mismatch");
        require(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin), "admin role missing");
        require(token.hasRole(token.MINTER_ROLE(), minter), "minter role missing");
        require(token.hasRole(token.PAUSER_ROLE(), pauser), "pauser role missing");
        require(token.hasRole(token.RISK_ROLE(), risk), "risk role missing");
        require(token.mintLimitPerWindow() == mintLimit, "mint limit mismatch");
        require(token.mintWindowSizeSeconds() == mintWindow, "mint window mismatch");
        require(token.totalSupply() == 0, "unexpected initial supply");
    }

    function _logSummary(
        PredixUmaBondToken token,
        address admin,
        address minter,
        address pauser,
        address risk,
        uint256 mintLimit,
        uint256 mintWindow
    ) internal view {
        console2.log("========== PredixUmaBondToken Deployment ==========");
        console2.log("Token address:", address(token));
        console2.log("Name:", token.name());
        console2.log("Symbol:", token.symbol());
        console2.log("Max supply:", token.maxSupply());
        console2.log("Mint limit / window:", mintLimit);
        console2.log("Mint window (seconds):", mintWindow);
        console2.log("--- Roles ---");
        console2.log("DEFAULT_ADMIN:", admin);
        console2.log("MINTER:", minter);
        console2.log("PAUSER:", pauser);
        console2.log("RISK:", risk);
        console2.log("===================================================");
    }
}
