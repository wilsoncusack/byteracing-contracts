// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

import {ByteRacers} from "./ByteRacers.sol";

contract ByteRaces {
    struct Position {
        uint64 x;
        uint64 y;
    }

    struct RaceDetails {
        address creator;
        // 10 = 1%
        uint8 creatorTakePercent;
        uint40 registrationEnd;
        uint48 racePosted;
        uint64 raceRegistrationFee;
        uint64 totalFees;
        uint256 winner;
    }

    mapping(bytes32 raceId => RaceDetails details) raceDetails;
    mapping(bytes32 raceId => mapping(uint256 racerId => address payoutTo)) payoutAddress;

    event RaceRegistered(bytes32 indexed raceId, uint256 registrationEnd, uint256 raceRegistrationFee);
    event RaceDetailsPosted(bytes32 indexed raceId, int8[][] map, Position start);
    event RaceWinnerPosted(bytes32 indexed raceId, uint256 indexed winner);
    event RacerRegistered(bytes32 indexed raceId, uint256 indexed racerId);

    error AlreadyRegistered(bytes32 raceId);
    error RaceNotRegistered(bytes32 raceId);
    error RegistrationNotEnded(uint256 registrationEnd, uint256 currentTime);
    error RaceDetailsAlreadyPosted(bytes32 raceId);
    error RaceDetailsNotPosted(bytes32 raceId);
    error RaceWinnerAlreadyPosted(bytes32 raceId);
    error OnlyRacerOwnerCanRegister();
    error RegistrationEnded();
    error InvalidRegistrationFee(uint256 expected, uint256 received);
    error InvalidSignature();
    error RacerAlreadyRegistered(bytes32 raceId, uint256 racerId);

    uint256 public constant CREATOR_TAKE_DENOMINATOR = 1000;
    ByteRacers public immutable byteRacers;

    constructor(ByteRacers byteRacers_) {
        byteRacers = byteRacers_;
    }

    function registerRace(bytes32 raceId, uint40 registrationEnd, uint64 raceRegistrationFee, uint8 creatorTakePercent)
        external
    {
        if (raceDetails[raceId].registrationEnd != 0) {
            revert AlreadyRegistered(raceId);
        }

        raceDetails[raceId].registrationEnd = registrationEnd;
        raceDetails[raceId].raceRegistrationFee = raceRegistrationFee;
        raceDetails[raceId].creatorTakePercent = creatorTakePercent;
        raceDetails[raceId].creator = msg.sender;

        emit RaceRegistered(raceId, registrationEnd, raceRegistrationFee);
    }

    function donate(bytes32 raceId) external payable {
        if (raceDetails[raceId].registrationEnd == 0) {
            revert RaceNotRegistered(raceId);
        }

        if (raceDetails[raceId].winner != 0) {
            revert RaceWinnerAlreadyPosted(raceId);
        }

        raceDetails[raceId].totalFees += uint64(msg.value);
    }

    function postRaceDetails(int8[][] calldata map, Position calldata start) external {
        bytes32 raceId = getRaceId(map, start);
        uint256 registrationEnd = raceDetails[raceId].registrationEnd;

        if (registrationEnd == 0) {
            revert RaceNotRegistered(raceId);
        }

        if (registrationEnd >= block.timestamp) {
            revert RegistrationNotEnded(registrationEnd, block.timestamp);
        }

        if (raceDetails[raceId].racePosted != 0) {
            revert RaceDetailsAlreadyPosted(raceId);
        }

        raceDetails[raceId].racePosted = uint48(block.timestamp);

        emit RaceDetailsPosted(raceId, map, start);
    }

    function postWinner(bytes32 raceId, uint256 winningRacerId) external {
        if (raceDetails[raceId].racePosted == 0) {
            revert RaceDetailsNotPosted(raceId);
        }

        if (raceDetails[raceId].winner != 0) {
            revert RaceWinnerAlreadyPosted(raceId);
        }

        raceDetails[raceId].winner = winningRacerId;

        uint256 take = raceDetails[raceId].totalFees * raceDetails[raceId].creatorTakePercent / CREATOR_TAKE_DENOMINATOR;
        uint256 remainder = raceDetails[raceId].totalFees - take;

        SafeTransferLib.forceSafeTransferETH(
            byteRacers.ownerOf(winningRacerId), remainder, SafeTransferLib.GAS_STIPEND_NO_GRIEF
        );

        emit RaceWinnerPosted(raceId, winningRacerId);
    }

    function registerRacerForRace(uint256 racerId, bytes32 raceId, address payoutTo) external payable {
        if (msg.sender != byteRacers.ownerOf(racerId)) {
            revert OnlyRacerOwnerCanRegister();
        }
        _registerRacer(racerId, raceId, payoutTo);
    }

    function registerRacerForRace(uint256 racerId, bytes32 raceId, address payoutTo, bytes calldata signature)
        external
        payable
    {
        if (!SignatureCheckerLib.isValidSignatureNowCalldata(byteRacers.ownerOf(racerId), raceId, signature)) {
            revert InvalidSignature();
        }
        _registerRacer(racerId, raceId, payoutTo);
    }

    function getRaceId(int8[][] calldata map, Position calldata position) public view returns (bytes32) {
        return keccak256(abi.encode(map, position));
    }

    function _registerRacer(uint256 racerId, bytes32 raceId, address payoutTo) internal {
        if (raceDetails[raceId].registrationEnd < block.timestamp) {
            revert RegistrationEnded();
        }

        if (msg.value != raceDetails[raceId].raceRegistrationFee) {
            revert InvalidRegistrationFee(raceDetails[raceId].raceRegistrationFee, msg.value);
        }

        if (payoutAddress[raceId][racerId] != address(0)) {
            revert RacerAlreadyRegistered(raceId, racerId);
        }

        payoutAddress[raceId][racerId] = payoutTo;

        raceDetails[raceId].totalFees += uint64(msg.value);

        emit RacerRegistered(raceId, racerId);
    }
}
