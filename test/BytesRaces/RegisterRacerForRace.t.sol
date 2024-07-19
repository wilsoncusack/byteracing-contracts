// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./ByteRace.t.sol";

contract RegisterRacerForRaceTest is ByteRacesBaseTest {
    address owner = makeAddr("racer owner");
    uint256 racerId;
    bytes32 id;
    uint40 registrationEnd;
    uint64 raceRegistrationFee;
    uint8 creatorTakePercent;

    function setUp() public override {
        super.setUp();
        racerId = racers.mintTo({to: owner, byteCode: ""});
        id = byteRaces.getRaceId(map, startPosition);
        registrationEnd = uint40(block.timestamp + byteRaces.MIN_REGISTRATION_PERIOD());
    }

    function test_reverts_whenNotRacerOwner() public {
        byteRaces.registerRace(id, registrationEnd, raceRegistrationFee, creatorTakePercent);

        vm.deal(address(this), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.OnlyRacerOwnerCanRegister.selector));
        byteRaces.registerRacerForRace{value: 1 ether}(racerId, id, address(this));
    }

    function test_reverts_whenRegistrationEnded(uint40 registrationEnd_) public {
        vm.assume(registrationEnd_ > block.timestamp + byteRaces.MIN_REGISTRATION_PERIOD());
        registrationEnd = registrationEnd_;

        byteRaces.registerRace(id, registrationEnd, raceRegistrationFee, creatorTakePercent);

        vm.warp(registrationEnd);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.RegistrationEnded.selector));
        byteRaces.registerRacerForRace(racerId, id, address(this));
    }

    function test_reverts_whenInvalidRegistrationFee(uint64 fee, uint64 badFee) public {
        vm.assume(badFee != fee);

        byteRaces.registerRace(id, registrationEnd, fee, creatorTakePercent);

        vm.deal(owner, badFee);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.InvalidRegistrationFee.selector, fee, badFee));
        byteRaces.registerRacerForRace{value: badFee}(racerId, id, address(this));
    }

    function test_reverts_whenRacerAlreadyRegistered() public {
        byteRaces.registerRace(id, registrationEnd, 1 ether, 10);

        vm.deal(owner, 2 ether);
        vm.startPrank(owner);
        byteRaces.registerRacerForRace{value: 1 ether}(racerId, id, address(this));

        vm.expectRevert(abi.encodeWithSelector(ByteRaces.RacerAlreadyRegistered.selector, id, racerId));
        byteRaces.registerRacerForRace{value: 1 ether}(racerId, id, address(this));
        vm.stopPrank();
    }

    function test_reverts_whenPayoutAddressZero() public {
        byteRaces.registerRace(id, registrationEnd, raceRegistrationFee, creatorTakePercent);

        vm.deal(owner, raceRegistrationFee);
        vm.prank(owner);
        vm.expectRevert(ByteRaces.ZeroAddress.selector);
        byteRaces.registerRacerForRace(racerId, id, address(0));
    }

    function test_registersRacer(uint64 raceRegistrationFee_, address payoutAddress) public {
        vm.assume(payoutAddress != address(0));
        raceRegistrationFee = raceRegistrationFee_;

        byteRaces.registerRace(id, registrationEnd, raceRegistrationFee, creatorTakePercent);

        vm.deal(owner, raceRegistrationFee);
        vm.prank(owner);
        byteRaces.registerRacerForRace{value: raceRegistrationFee}(racerId, id, payoutAddress);

        assertEq(byteRaces.raceDetails(id).totalFees, raceRegistrationFee);
        assertEq(byteRaces.payoutAddress(raceId, racerId), payoutAddress);
    }

    // test reverts if payout to address zero

    function test_emitsRacerRegistered() public {
        byteRaces.registerRace(id, registrationEnd, raceRegistrationFee, creatorTakePercent);

        vm.deal(owner, raceRegistrationFee);
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit ByteRaces.RacerRegistered(id, racerId);
        byteRaces.registerRacerForRace{value: raceRegistrationFee}(racerId, id, address(this));
    }

    function test_reverts_whenFeesExceedUint72() public {
        uint64 raceRegistrationFee = 1;
        byteRaces.registerRace(id, registrationEnd, raceRegistrationFee, creatorTakePercent);

        vm.deal(address(this), type(uint72).max);
        byteRaces.donate{value: type(uint72).max}(id);
        vm.deal(owner, 1);

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.MaxFees.selector));
        byteRaces.registerRacerForRace{value: raceRegistrationFee}(racerId, id, address(this));
    }
}
