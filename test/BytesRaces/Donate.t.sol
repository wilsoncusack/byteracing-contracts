// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./ByteRace.t.sol";

contract DonateTest is ByteRacesBaseTest {
    function test_reverts_whenRaceNotRegistered() public {
        vm.deal(address(this), 1);
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.RaceNotRegistered.selector, raceId));
        byteRaces.donate{value: 1}(raceId);
    }

    function test_reverts_whenDonationZero() public {
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.ZeroDonation.selector));
        byteRaces.donate(raceId);
    }

    function test_reverts_whenWinnerSet(uint40 registrationEnd, uint64 raceRegistrationFee, uint8 creatorTakePercent)
        public
    {
        vm.assume(registrationEnd < type(uint40).max);
        vm.assume(registrationEnd >= block.number + byteRaces.MIN_REGISTRATION_PERIOD());
        bytes32 id = byteRaces.getRaceId(map, startPosition);
        byteRaces.registerRace(id, registrationEnd, raceRegistrationFee, creatorTakePercent);

        address owner = makeAddr("racer owner");
        uint256 racerId = racers.mintTo({to: owner, byteCode: ""});
        vm.deal(owner, raceRegistrationFee);
        vm.prank(owner);
        byteRaces.registerRacerForRace{value: raceRegistrationFee}(racerId, id, address(this));
        vm.warp(registrationEnd + 1);
        byteRaces.postRaceDetails(map, startPosition);
        byteRaces.postWinner(id, racerId);
        vm.deal(address(this), 1);
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.RaceWinnerAlreadyPosted.selector, id));
        byteRaces.donate{value: 1}(id);
    }

    function test_donates(uint40 registrationEnd, uint64 raceRegistrationFee, uint8 creatorTakePercent, uint72 donation)
        public
    {
        vm.assume(donation > 0);
        vm.assume(registrationEnd >= block.number + byteRaces.MIN_REGISTRATION_PERIOD());
        bytes32 id = byteRaces.getRaceId(map, startPosition);
        byteRaces.registerRace(id, registrationEnd, raceRegistrationFee, creatorTakePercent);
        assertEq(byteRaces.raceDetails(id).totalFees, 0);
        vm.deal(address(this), donation);
        byteRaces.donate{value: donation}(id);
        assertEq(byteRaces.raceDetails(id).totalFees, donation);
    }

    function test_emitsDonated(
        uint40 registrationEnd,
        uint64 raceRegistrationFee,
        uint8 creatorTakePercent,
        uint72 donation
    ) public {
        vm.assume(donation > 0);
        vm.assume(registrationEnd >= block.number + byteRaces.MIN_REGISTRATION_PERIOD());
        bytes32 id = byteRaces.getRaceId(map, startPosition);
        byteRaces.registerRace(id, registrationEnd, raceRegistrationFee, creatorTakePercent);
        vm.deal(address(this), donation);
        vm.expectEmit(true, true, true, true);
        emit ByteRaces.Donated(id, donation);
        byteRaces.donate{value: donation}(id);
    }

    function test_reverts_whenFeesExceedUint72(
        uint40 registrationEnd,
        uint64 raceRegistrationFee,
        uint8 creatorTakePercent,
        uint256 donation
    ) public {
        vm.assume(registrationEnd >= block.number + byteRaces.MIN_REGISTRATION_PERIOD());
        bytes32 id = byteRaces.getRaceId(map, startPosition);
        byteRaces.registerRace(id, registrationEnd, raceRegistrationFee, creatorTakePercent);
        vm.assume(donation > type(uint72).max);
        vm.deal(address(this), donation);
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.MaxFees.selector));
        byteRaces.donate{value: donation}(raceId);
    }
}
