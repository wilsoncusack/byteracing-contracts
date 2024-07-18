// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./ByteRace.t.sol";

contract RegisterRacerForRaceTest is ByteRacesBaseTest {
    function test_reverts_whenNotRacerOwner() public {
        bytes32 id = byteRaces.getRaceId(map, startPosition);
        byteRaces.registerRace(id, uint40(block.timestamp + byteRaces.MIN_REGISTRATION_PERIOD()), 1 ether, 10);

        address owner = makeAddr("racer owner");
        uint256 racerId = racers.mintTo({to: owner, byteCode: ""});

        vm.deal(address(this), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.OnlyRacerOwnerCanRegister.selector));
        byteRaces.registerRacerForRace{value: 1 ether}(racerId, id, address(this));
    }

    function test_reverts_whenRegistrationEnded(uint40 registrationEnd) public {
        vm.assume(registrationEnd > block.timestamp + byteRaces.MIN_REGISTRATION_PERIOD());

        bytes32 id = byteRaces.getRaceId(map, startPosition);
        byteRaces.registerRace(id, registrationEnd, 1 ether, 10);

        address owner = makeAddr("racer owner");
        uint256 racerId = racers.mintTo({to: owner, byteCode: ""});

        vm.deal(owner, 1 ether);
        vm.prank(owner);
        vm.warp(registrationEnd);
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.RegistrationEnded.selector));
        byteRaces.registerRacerForRace{value: 1 ether}(racerId, id, address(this));
    }

    function test_reverts_whenInvalidRegistrationFee(uint64 fee, uint64 badFee) public {
        vm.assume(badFee != fee);

        bytes32 id = byteRaces.getRaceId(map, startPosition);
        byteRaces.registerRace(id, uint40(block.timestamp + byteRaces.MIN_REGISTRATION_PERIOD()), badFee, 10);

        address owner = makeAddr("racer owner");
        uint256 racerId = racers.mintTo({to: owner, byteCode: ""});

        vm.deal(owner, fee);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.InvalidRegistrationFee.selector, badFee, fee));
        byteRaces.registerRacerForRace{value: fee}(racerId, id, address(this));
    }

    function test_reverts_whenRacerAlreadyRegistered() public {
        bytes32 id = byteRaces.getRaceId(map, startPosition);
        byteRaces.registerRace(id, uint40(block.timestamp + byteRaces.MIN_REGISTRATION_PERIOD()), 1 ether, 10);

        address owner = makeAddr("racer owner");
        uint256 racerId = racers.mintTo({to: owner, byteCode: ""});

        vm.deal(owner, 2 ether);
        vm.startPrank(owner);
        byteRaces.registerRacerForRace{value: 1 ether}(racerId, id, address(this));

        vm.expectRevert(abi.encodeWithSelector(ByteRaces.RacerAlreadyRegistered.selector, id, racerId));
        byteRaces.registerRacerForRace{value: 1 ether}(racerId, id, address(this));
        vm.stopPrank();
    }

    function test_registersRacer(
        uint40 registrationEnd,
        uint64 raceRegistrationFee,
        uint8 creatorTakePercent,
        address payoutAddress
    ) public {
        vm.assume(registrationEnd > block.timestamp + byteRaces.MIN_REGISTRATION_PERIOD());

        bytes32 id = byteRaces.getRaceId(map, startPosition);
        byteRaces.registerRace(id, registrationEnd, raceRegistrationFee, creatorTakePercent);

        address owner = makeAddr("racer owner");
        uint256 racerId = racers.mintTo({to: owner, byteCode: ""});

        vm.deal(owner, raceRegistrationFee);
        vm.prank(owner);
        byteRaces.registerRacerForRace{value: raceRegistrationFee}(racerId, id, payoutAddress);

        assertEq(byteRaces.raceDetails(id).totalFees, raceRegistrationFee);
        assertEq(byteRaces.payoutAddress(raceId, racerId), payoutAddress);
    }

    function test_emitsRacerRegistered(uint40 registrationEnd, uint64 raceRegistrationFee, uint8 creatorTakePercent)
        public
    {
        vm.assume(registrationEnd > block.timestamp + byteRaces.MIN_REGISTRATION_PERIOD());

        bytes32 id = byteRaces.getRaceId(map, startPosition);
        byteRaces.registerRace(id, registrationEnd, raceRegistrationFee, creatorTakePercent);

        address owner = makeAddr("racer owner");
        uint256 racerId = racers.mintTo({to: owner, byteCode: ""});

        vm.deal(owner, raceRegistrationFee);
        vm.prank(owner);
        vm.expectEmit(true, true, true, true);
        emit ByteRaces.RacerRegistered(id, racerId);
        byteRaces.registerRacerForRace{value: raceRegistrationFee}(racerId, id, address(this));
    }

    function test_reverts_whenFeesExceedUint72() public {
        uint8 creatorTakePercent = 0;
        uint40 registrationEnd = uint40(block.timestamp + byteRaces.MIN_REGISTRATION_PERIOD());
        uint64 raceRegistrationFee = 1;
        bytes32 id = byteRaces.getRaceId(map, startPosition);
        byteRaces.registerRace(id, registrationEnd, raceRegistrationFee, creatorTakePercent);

        address owner = makeAddr("racer owner");
        uint256 racerId = racers.mintTo({to: owner, byteCode: ""});

        vm.deal(address(this), type(uint72).max);
        byteRaces.donate{value: type(uint72).max}(id);
        vm.deal(owner, 1);

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.MaxFees.selector));
        byteRaces.registerRacerForRace{value: raceRegistrationFee}(racerId, id, address(this));
    }
}
