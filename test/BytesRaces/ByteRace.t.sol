// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {ByteRaces} from "../../src/ByteRaces.sol";
import {ByteRacers} from "../../src/ByteRacers.sol";

contract ByteRacesBaseTest is Test {
    int8[][] map;
    ByteRaces.Position startPosition;
    bytes32 raceId;
    ByteRacers public racers = new ByteRacers();
    ByteRaces public byteRaces = new ByteRaces(racers);

    function setUp() public virtual {
        raceId = byteRaces.getRaceId(map, startPosition);
    }
}
