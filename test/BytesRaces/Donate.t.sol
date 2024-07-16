// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./ByteRace.t.sol";

contract DonateTest is ByteRacesBaseTest {
    function test_reverts_whenRaceNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.RaceNotRegistered.selector, raceId));
        byteRaces.donate(raceId);
    }

    function test_reverts_whenWinnerSet(uint8 creatorTakePercent) public {
        uint64 raceRegistrationFee = 0;
        uint40 registrationEnd = uint40(block.number + byteRaces.MIN_REGISTRATION_PERIOD());

        bytes32 id = byteRaces.getRaceId(map, startPosition);
        byteRaces.registerRace(id, registrationEnd, raceRegistrationFee, creatorTakePercent);
        address owner = makeAddr("racer owner");
        uint256 racerId = racers.mintTo({to: owner, byteCode: ""});
        vm.prank(owner);
        byteRaces.registerRacerForRace(racerId, id, address(this));
        vm.warp(registrationEnd + 1);
        byteRaces.postRaceDetails(map, startPosition);
        byteRaces.postWinner(id, racerId);
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.RaceWinnerAlreadyPosted.selector, id));
        byteRaces.donate(id);
    }

    function test_donates() public {}

    function test_emitsDonated() public {}
}
