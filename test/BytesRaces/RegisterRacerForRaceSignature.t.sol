// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./ByteRace.t.sol";
import "solady/utils/SignatureCheckerLib.sol";

contract RegisterRacerForRaceTest is ByteRacesBaseTest {
    uint256 ownerPk = 1111;
    address owner;
    uint256 racerId;
    bytes32 id;
    uint40 registrationEnd;
    uint64 raceRegistrationFee;
    uint8 creatorTakePercent;
    address payoutTo;

    function setUp() public override {
        super.setUp();
        owner = vm.addr(ownerPk);
        racerId = racers.mintTo({to: owner, byteCode: ""});
        id = byteRaces.getRaceId(map, startPosition);
        registrationEnd = uint40(block.timestamp + byteRaces.MIN_REGISTRATION_PERIOD());
        raceRegistrationFee = 1 ether;
        creatorTakePercent = 10;
        payoutTo = makeAddr("payout address");
        byteRaces.registerRace(id, registrationEnd, raceRegistrationFee, creatorTakePercent);
    }

    function test_savesDataCorrectly() public {
        _registerWithSignature(ownerPk, raceRegistrationFee);

        assertEq(byteRaces.raceDetails(id).totalFees, raceRegistrationFee);
        assertEq(byteRaces.payoutAddress(id, racerId), payoutTo);
    }

    function test_reverts_whenPayoutAddressZero() public {
        payoutTo = address(0);
        vm.expectRevert(ByteRaces.ZeroAddress.selector);
        _registerWithSignature(ownerPk, raceRegistrationFee);
    }

    function test_reverts_whenInvalidSignature() public {
        uint256 wrongSigner = 222;

        vm.expectRevert(abi.encodeWithSelector(ByteRaces.InvalidSignature.selector));
        _registerWithSignature(wrongSigner, raceRegistrationFee);
    }

    function test_reverts_whenTamperedMessage() public {
        bytes memory signature = _getSignature(ownerPk, id, payoutTo);
        address differentPayoutTo = makeAddr("different payout address");

        vm.deal(address(this), raceRegistrationFee);
        vm.expectRevert(abi.encodeWithSelector(ByteRaces.InvalidSignature.selector));
        byteRaces.registerRacerForRace{value: raceRegistrationFee}(racerId, id, differentPayoutTo, signature);
    }

    function test_reverts_whenInvalidRegistrationFee() public {
        uint256 invalidFee = raceRegistrationFee - 1;

        vm.expectRevert(
            abi.encodeWithSelector(ByteRaces.InvalidRegistrationFee.selector, raceRegistrationFee, invalidFee)
        );
        _registerWithSignature(ownerPk, invalidFee);
    }

    function test_reverts_whenAlreadyRegistered() public {
        _registerWithSignature(ownerPk, raceRegistrationFee);

        vm.expectRevert(abi.encodeWithSelector(ByteRaces.RacerAlreadyRegistered.selector, id, racerId));
        _registerWithSignature(ownerPk, raceRegistrationFee);
    }

    function test_registerRacerForRace_emitsRacerRegistered() public {
        vm.expectEmit(true, true, true, true);
        emit ByteRaces.RacerRegistered(id, racerId);
        _registerWithSignature(ownerPk, raceRegistrationFee);
    }

    function _getSignature(uint256 signerPk, bytes32 raceId, address payoutAddress) internal returns (bytes memory) {
        bytes32 hash = SignatureCheckerLib.toEthSignedMessageHash(abi.encode(raceId, payoutAddress));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, hash);
        return abi.encodePacked(r, s, v);
    }

    function _registerWithSignature(uint256 signerPk, uint256 value) internal {
        bytes memory signature = _getSignature(signerPk, id, payoutTo);
        vm.deal(address(this), value);
        byteRaces.registerRacerForRace{value: value}(racerId, id, payoutTo, signature);
    }
}
