// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {ByteRacers} from "../src/ByteRacers.sol";

contract ByteRacersTest is Test {
    ByteRacers public racers = new ByteRacers();

    function setUp() public {}

    function test_mint_mintsCorrectId() public {
        bytes memory byteCode = "";
        vm.prank(address(1));
        uint256 id = racers.mint(byteCode);

        assertEq(id, uint256(keccak256(byteCode)));
    }

    function test_mint_mintsToCaller() public {
        bytes memory byteCode = "";
        address caller = address(1);
        vm.prank(caller);
        uint256 id = racers.mint(byteCode);

        assertEq(racers.balanceOf(caller), 1);
        assertEq(racers.ownerOf(id), caller);
    }

    function test_mint_emitsCorrectly() public {
        bytes memory byteCode = "test";
        vm.expectEmit(true, true, true, true);
        emit ByteRacers.RacerMinted(uint256(keccak256(byteCode)), byteCode);
        vm.prank(address(1));
        racers.mint(byteCode);
    }

    function test_mintTo_mintsToSpecifiedAddress() public {
        bytes memory byteCode = "test";
        address to = address(2);
        vm.prank(address(1));
        racers.mintTo(to, byteCode);

        assertEq(racers.balanceOf(to), 1);
    }
}
