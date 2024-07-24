// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./ByteRace.t.sol";

contract PostRaceDetailsTest is ByteRacesBaseTest {
    uint40 registrationEnd;
    uint64 raceRegistrationFee;
    uint8 creatorTakePercent;

    function setUp() public override {
        super.setUp();
        registrationEnd = uint40(block.timestamp + byteRaces.MIN_REGISTRATION_PERIOD());
    }

    function test_emitsRaceDetailsPosted(int8[][] calldata raceMap, ByteRaces.Position calldata start) public {
        bytes32 id = byteRaces.getRaceId(raceMap, start);
        byteRaces.registerRace(id, registrationEnd, raceRegistrationFee, creatorTakePercent);
        vm.warp(registrationEnd + 1);

        vm.expectEmit(true, true, true, true);
        emit ByteRaces.RaceDetailsPosted(id, raceMap, start);
        byteRaces.postRaceDetails(raceMap, start);
    }

    function test_updatesRacePosted(uint40 timestamp) public {
        vm.assume(timestamp > registrationEnd);
        byteRaces.registerRace(raceId, registrationEnd, raceRegistrationFee, creatorTakePercent);
        vm.warp(timestamp);
        byteRaces.postRaceDetails(map, startPosition);
        assertEq(byteRaces.raceDetails(raceId).racePosted, timestamp);
    }

    function test_reverts_whenRaceNotRegistered(int8[][] calldata raceMap, ByteRaces.Position calldata start) public {
        bytes32 id = byteRaces.getRaceId(raceMap, start);
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.RaceNotRegistered.selector, id));
        byteRaces.postRaceDetails(raceMap, start);
    }

    function test_reverts_whenRegistrationNotEnded() public {
        byteRaces.registerRace(raceId, registrationEnd, raceRegistrationFee, creatorTakePercent);
        vm.expectRevert(
            abi.encodeWithSelector(ByteRaces.RegistrationNotEnded.selector, registrationEnd, block.timestamp)
        );
        byteRaces.postRaceDetails(map, startPosition);
    }

    function test_reverts_whenRaceDetailsAlreadyPosted() public {
        byteRaces.registerRace(raceId, registrationEnd, raceRegistrationFee, creatorTakePercent);
        vm.warp(registrationEnd + 1);
        byteRaces.postRaceDetails(map, startPosition);
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.RaceDetailsAlreadyPosted.selector, raceId));
        byteRaces.postRaceDetails(map, startPosition);
    }
}
