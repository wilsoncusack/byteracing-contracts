// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {ByteRaces} from "../../src/ByteRaces.sol";
import {ByteRacers} from "../../src/ByteRacers.sol";

contract ByteRacesBaseTest is Test {
    int8[][] public map;
    ByteRaces.Position public startPosition;
    bytes32 public raceId;
    ByteRacers public racers = new ByteRacers();
    ByteRaces public byteRaces = new ByteRaces(racers);

    function setUp() public virtual {
        raceId = byteRaces.getRaceId(map, startPosition);
    }
}
