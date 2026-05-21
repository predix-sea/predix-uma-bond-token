// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {PredixUmaBondToken} from "../src/PredixUmaBondToken.sol";

contract DeployTest is Test {
    function test_DeployScript_WithEnv() public {
        address admin = makeAddr("admin");
        address minter = makeAddr("minter");
        address pauser = makeAddr("pauser");
        address risk = makeAddr("risk");

        vm.setEnv("TOKEN_NAME", "PrediX UMA Bond");
        vm.setEnv("TOKEN_SYMBOL", "pUMAB");
        vm.setEnv("MAX_SUPPLY", vm.toString(uint256(10_000_000 ether)));
        vm.setEnv("ADMIN_ADDRESS", vm.toString(admin));
        vm.setEnv("MINTER_ADDRESS", vm.toString(minter));
        vm.setEnv("PAUSER_ADDRESS", vm.toString(pauser));
        vm.setEnv("RISK_ADDRESS", vm.toString(risk));
        vm.setEnv("MINT_LIMIT_PER_WINDOW", vm.toString(uint256(1_000_000 ether)));
        vm.setEnv("MINT_WINDOW_SECONDS", vm.toString(uint256(86_400)));
        vm.setEnv("PRIVATE_KEY", vm.toString(uint256(1)));

        Deploy deployer = new Deploy();
        PredixUmaBondToken token = deployer.run();

        assertEq(token.maxSupply(), 10_000_000 ether);
        assertEq(token.mintLimitPerWindow(), 1_000_000 ether);
        assertEq(token.mintWindowSizeSeconds(), 86_400);
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
    }
}
