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
        // max 255 = 25.5%
        uint8 creatorTakePercent;
        uint40 registrationEnd;
        uint40 racePosted;
        // max 18 eth 
        uint64 raceRegistrationFee;
        // max prize pool 4.7k ETH
        uint72 totalFees;
        uint256 winner;
    }

    mapping(bytes32 raceId => mapping(uint256 racerId => address payoutTo)) public payoutAddress;
    mapping(bytes32 raceId => RaceDetails details) internal _raceDetails;

    event RaceRegistered(
        bytes32 indexed raceId,
        uint256 registrationEnd,
        uint256 raceRegistrationFee,
        uint256 creatorTakePercent,
        address creator
    );
    event Donated(bytes32 indexed raceId, uint256 value);
    event RaceDetailsPosted(bytes32 indexed raceId, int8[][] map, Position start);
    event RaceWinnerPosted(bytes32 indexed raceId, uint256 indexed winningRacer);
    event RacerRegistered(bytes32 indexed raceId, uint256 indexed racerId);

    error AlreadyRegistered(bytes32 raceId);
    error MinRegistrationPeriod();
    error RaceNotRegistered(bytes32 raceId);
    error RegistrationNotEnded(uint256 registrationEnd, uint256 currentTime);
    error RaceDetailsAlreadyPosted(bytes32 raceId);
    error RaceDetailsNotPosted(bytes32 raceId);
    error RaceWinnerAlreadyPosted(bytes32 raceId, uint256 winningRacer);
    error RacerNotRegistered(bytes32 raceId, uint256 racerId);
    error OnlyRacerOwnerCanRegister();
    error RegistrationEnded();
    error InvalidRegistrationFee(uint256 expected, uint256 received);
    error InvalidSignature();
    error RacerAlreadyRegistered(bytes32 raceId, uint256 racerId);
    error MaxFees();
    error ZeroDonation();
    error ZeroAddress();
    error CreatorOnly();

    uint256 public constant CREATOR_TAKE_DENOMINATOR = 1000;
    uint256 public constant MIN_REGISTRATION_PERIOD = 0.5 hours;
    ByteRacers public immutable byteRacers;

    constructor(ByteRacers byteRacers_) {
        byteRacers = byteRacers_;
    }

    /// @dev Users need to trust the race creator that the race has a valid solution
    function registerRace(bytes32 raceId, uint40 registrationEnd, uint64 raceRegistrationFee, uint8 creatorTakePercent)
        external
    {
        if (_raceDetails[raceId].registrationEnd != 0) {
            revert AlreadyRegistered(raceId);
        }

        if (registrationEnd < block.timestamp + MIN_REGISTRATION_PERIOD) {
            revert MinRegistrationPeriod();
        }

        _raceDetails[raceId].registrationEnd = registrationEnd;
        _raceDetails[raceId].raceRegistrationFee = raceRegistrationFee;
        _raceDetails[raceId].creatorTakePercent = creatorTakePercent;
        _raceDetails[raceId].creator = msg.sender;

        emit RaceRegistered(raceId, registrationEnd, raceRegistrationFee, creatorTakePercent, msg.sender);
    }

    function donate(bytes32 raceId) external payable {
        if (msg.value == 0) {
            revert ZeroDonation();
        }

        if (_raceDetails[raceId].registrationEnd == 0) {
            revert RaceNotRegistered(raceId);
        }

        if (_raceDetails[raceId].winner != 0) {
            revert RaceWinnerAlreadyPosted(raceId, _raceDetails[raceId].winner);
        }

        // extremely unlikely but, hey, gas is cheap
        if (_raceDetails[raceId].totalFees + msg.value > type(uint72).max) {
            revert MaxFees();
        }

        _raceDetails[raceId].totalFees += uint72(msg.value);

        emit Donated(raceId, msg.value);
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
        bytes32 hash = SignatureCheckerLib.toEthSignedMessageHash(abi.encode(raceId, payoutTo));
        if (!SignatureCheckerLib.isValidSignatureNowCalldata(byteRacers.ownerOf(racerId), hash, signature)) {
            revert InvalidSignature();
        }
        _registerRacer(racerId, raceId, payoutTo);
    }

    function postRaceDetails(int8[][] calldata map, Position calldata start) external {
        bytes32 raceId = getRaceId(map, start);
        uint256 registrationEnd = _raceDetails[raceId].registrationEnd;

        if (registrationEnd == 0) {
            revert RaceNotRegistered(raceId);
        }

        if (registrationEnd >= block.timestamp) {
            revert RegistrationNotEnded(registrationEnd, block.timestamp);
        }

        if (_raceDetails[raceId].racePosted != 0) {
            revert RaceDetailsAlreadyPosted(raceId);
        }

        _raceDetails[raceId].racePosted = uint40(block.timestamp);

        emit RaceDetailsPosted(raceId, map, start);
    }

    function postWinner(bytes32 raceId, uint256 winningRacerId) external {
        if (_raceDetails[raceId].racePosted == 0) {
            revert RaceDetailsNotPosted(raceId);
        }

        if (msg.sender != _raceDetails[raceId].creator) {
            revert CreatorOnly();
        }

        address payoutTo = payoutAddress[raceId][winningRacerId];
        if (payoutTo == address(0)) {
            revert RacerNotRegistered(raceId, winningRacerId);
        }

        if (_raceDetails[raceId].winner != 0) {
            revert RaceWinnerAlreadyPosted(raceId, _raceDetails[raceId].winner);
        }

        _raceDetails[raceId].winner = winningRacerId;

        uint256 take =
            _raceDetails[raceId].totalFees * _raceDetails[raceId].creatorTakePercent / CREATOR_TAKE_DENOMINATOR;
        uint256 remainder = _raceDetails[raceId].totalFees - take;

        SafeTransferLib.forceSafeTransferETH(_raceDetails[raceId].creator, take, SafeTransferLib.GAS_STIPEND_NO_GRIEF);

        SafeTransferLib.forceSafeTransferETH(payoutTo, remainder, SafeTransferLib.GAS_STIPEND_NO_GRIEF);

        emit RaceWinnerPosted(raceId, winningRacerId);
    }

    function raceDetails(bytes32 raceId) external view returns (RaceDetails memory) {
        return _raceDetails[raceId];
    }

    function getRaceId(int8[][] calldata map, Position calldata startPosition) public pure returns (bytes32) {
        return keccak256(abi.encode(map, startPosition));
    }

    function _registerRacer(uint256 racerId, bytes32 raceId, address payoutTo) internal {
        if (payoutTo == address(0)) {
            revert ZeroAddress();
        }

        if (_raceDetails[raceId].registrationEnd <= block.timestamp) {
            revert RegistrationEnded();
        }

        if (msg.value != _raceDetails[raceId].raceRegistrationFee) {
            revert InvalidRegistrationFee(_raceDetails[raceId].raceRegistrationFee, msg.value);
        }

        if (payoutAddress[raceId][racerId] != address(0)) {
            revert RacerAlreadyRegistered(raceId, racerId);
        }

        payoutAddress[raceId][racerId] = payoutTo;

        // extremely unlikely but, hey, gas is cheap
        // .. though if gas is cheap, maybe I should use uint256 :D 
        if (_raceDetails[raceId].totalFees + msg.value > type(uint72).max) {
            revert MaxFees();
        }

        _raceDetails[raceId].totalFees += uint72(msg.value);

        emit RacerRegistered(raceId, racerId);
    }
}
