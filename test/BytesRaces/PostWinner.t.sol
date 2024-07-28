// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./ByteRace.t.sol";

contract PostWinnerTesrt is ByteRacesBaseTest {
    uint40 registrationEnd;
    uint64 raceRegistrationFee;
    uint8 creatorTakePercent;
    address racerOwner = makeAddr("racerOwner");
    uint256 winner;
    address payoutAddress = makeAddr("payoutAddress");

    function setUp() public override {
        super.setUp();
        registrationEnd = uint40(block.timestamp + byteRaces.MIN_REGISTRATION_PERIOD());
        winner = racers.mintTo({byteCode: "", to: racerOwner});
    }

    function test_reverts_whenDetailsNotPosted() public {
        byteRaces.registerRace(raceId, registrationEnd, raceRegistrationFee, creatorTakePercent);
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.RaceDetailsNotPosted.selector, raceId));
        byteRaces.postWinner(raceId, winner);
    }

    function test_reverts_whenNotCalledByCreator() public {
        _setupWinnerPostableRace();
        vm.prank(makeAddr("notCreator"));
        vm.expectRevert(ByteRaces.CreatorOnly.selector);
        byteRaces.postWinner(raceId, winner);
    }

    function test_reverts_whenWinnerAlreadyPosted() public {
        _setupWinnerPostableRace();
        byteRaces.postWinner(raceId, winner);
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.RaceWinnerAlreadyPosted.selector, raceId, winner));
        byteRaces.postWinner(raceId, winner);
    }

    function test_reverts_whenRacerNotRegister() public {
        _setupWinnerPostableRace();
        uint256 nonRegisteredRacer = 255;
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.RacerNotRegistered.selector, raceId, nonRegisteredRacer));
        byteRaces.postWinner(raceId, nonRegisteredRacer);
    }

    function test_paysOutCorrectly(uint64 raceRegistrationFee_, uint8 creatorTakePercent_) public {
        raceRegistrationFee = raceRegistrationFee_;
        creatorTakePercent = creatorTakePercent_;
        _setupWinnerPostableRace();
        uint256 totalFees = byteRaces.raceDetails(raceId).totalFees;
        uint256 creatorTake = totalFees * creatorTakePercent / byteRaces.CREATOR_TAKE_DENOMINATOR();
        uint256 winnerTake = totalFees - creatorTake;
        uint256 creatorBeforeBalance = byteRaces.raceDetails(raceId).creator.balance;
        uint256 winnerBeforeBalance = payoutAddress.balance;
        byteRaces.postWinner(raceId, winner);
        assertEq(byteRaces.raceDetails(raceId).creator.balance, creatorBeforeBalance + creatorTake);
        assertEq(payoutAddress.balance, winnerBeforeBalance + winnerTake);
    }

    function test_emitsCorrectly() public {
        _setupWinnerPostableRace();
        vm.expectEmit(true, true, true, true);
        emit ByteRaces.RaceWinnerPosted(raceId, winner);
        byteRaces.postWinner(raceId, winner);
    }

    function _setupWinnerPostableRace() internal {
        byteRaces.registerRace(raceId, registrationEnd, raceRegistrationFee, creatorTakePercent);
        vm.deal(racerOwner, raceRegistrationFee);
        vm.prank(racerOwner);
        byteRaces.registerRacerForRace{value: raceRegistrationFee}({
            raceId: raceId,
            racerId: winner,
            payoutTo: payoutAddress
        });
        vm.warp(registrationEnd + 1);
        byteRaces.postRaceDetails(map, startPosition);
    }
}
