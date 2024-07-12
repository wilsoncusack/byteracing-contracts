// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ByteRaces} from "../../src/ByteRaces.sol";
import {ByteRacers} from "../../src/ByteRacers.sol";

contract ByteRacesBaseTest is Test {
    ByteRacers public racers = new ByteRacers();
    ByteRaces public byteraces = new ByteRaces(racers);

    function setUp() public {}
}
