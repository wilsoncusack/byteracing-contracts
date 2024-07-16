// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./ByteRace.t.sol";

contract RegisterRaceTest is ByteRacesBaseTest {
    function test_reverts_whenRaceAlreadyRegistered(
        uint40 registrationEnd,
        uint64 raceRegistrationFee,
        uint8 creatorTakePercent
    ) public {
        vm.assume(registrationEnd > block.timestamp + byteRaces.MIN_REGISTRATION_PERIOD());

        bytes32 id = byteRaces.getRaceId(map, startPosition);
        byteRaces.registerRace(id, registrationEnd, raceRegistrationFee, creatorTakePercent);
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.AlreadyRegistered.selector, id));
        byteRaces.registerRace(id, registrationEnd, raceRegistrationFee, creatorTakePercent);
    }

    function test_reverts_whenRegistrationTooShort(
        bytes32 raceId,
        uint40 registrationEnd,
        uint64 raceRegistrationFee,
        uint8 creatorTakePercent
    ) public {
        vm.assume(registrationEnd < block.timestamp + byteRaces.MIN_REGISTRATION_PERIOD());
        vm.expectRevert(ByteRaces.MinRegistrationPeriod.selector);
        byteRaces.registerRace(raceId, registrationEnd, raceRegistrationFee, creatorTakePercent);
    }

    function test_savesRaceDetails(
        bytes32 raceId,
        uint40 registrationEnd,
        uint64 raceRegistrationFee,
        uint8 creatorTakePercent
    ) public {
        vm.assume(registrationEnd > block.timestamp + byteRaces.MIN_REGISTRATION_PERIOD());

        byteRaces.registerRace(raceId, registrationEnd, raceRegistrationFee, creatorTakePercent);
        assertEq(byteRaces.raceDetails(raceId).registrationEnd, registrationEnd);
        assertEq(byteRaces.raceDetails(raceId).raceRegistrationFee, raceRegistrationFee);
        assertEq(byteRaces.raceDetails(raceId).creatorTakePercent, creatorTakePercent);
    }

    function test_emitsRaceRegistered(
        bytes32 raceId,
        uint40 registrationEnd,
        uint64 raceRegistrationFee,
        uint8 creatorTakePercent
    ) public {
        vm.assume(registrationEnd > block.timestamp + byteRaces.MIN_REGISTRATION_PERIOD());

        vm.expectEmit(true, false, false, true);
        emit ByteRaces.RaceRegistered(raceId, registrationEnd, raceRegistrationFee, creatorTakePercent, address(this));
        byteRaces.registerRace(raceId, registrationEnd, raceRegistrationFee, creatorTakePercent);
    }
}
