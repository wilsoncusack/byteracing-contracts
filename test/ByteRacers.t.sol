// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {ByteRacers, ERC721} from "../src/ByteRacers.sol";

contract ByteRacersTest is Test {
    ByteRacers public racers = new ByteRacers();

    function setUp() public {}

    function test_mint_mintsCorrectId() public {
        bytes memory byteCode = "";
        vm.prank(address(1));
        uint256 id = racers.mint(byteCode);

        assertEq(id, uint256(keccak256(byteCode)));
    }

    function test_mint_mintsToCaller() public {
        bytes memory byteCode = "";
        address caller = address(1);
        vm.prank(caller);
        uint256 id = racers.mint(byteCode);

        assertEq(racers.balanceOf(caller), 1);
        assertEq(racers.ownerOf(id), caller);
    }

    function test_mint_emitsCorrectly() public {
        bytes memory byteCode = "test";
        vm.expectEmit(true, true, true, true);
        emit ByteRacers.RacerMinted(uint256(keccak256(byteCode)), byteCode);
        vm.prank(address(1));
        racers.mint(byteCode);
    }

    function test_mintTo_mintsToSpecifiedAddress() public {
        bytes memory byteCode = "test";
        address to = address(2);
        vm.prank(address(1));
        racers.mintTo(to, byteCode);

        assertEq(racers.balanceOf(to), 1);
    }

    function test_tokenURI_reverts_ifTokenDoesNotExist() public {
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        racers.tokenURI(1);
    }

    function test_setTokenURI_setsCallToCorrectly() public {
        vm.createSelectFork("https://mainnet.base.org");
        racers = new ByteRacers();
        bytes memory byteCode = "test";
        vm.startPrank(address(1));
        uint256 id = racers.mint(byteCode);
        // based punks address
        address callTo = 0xcB28749c24AF4797808364D71d71539bc01E76d4;
        bytes memory callData = abi.encodeWithSelector(ERC721.tokenURI.selector, 1);
        racers.setTokenURI(id, callTo, callData);

        string memory uri = racers.tokenURI(id);
        assertEq(uri, "ipfs://QmPiUqt9twpDjfeWLyk5Nwjg7sEzuNouDx1cqtjUvn5kTW/1");
    }

    function test_setTokenURI_setsURICorrectly() public {
        bytes memory byteCode = "test";
        vm.startPrank(address(1));
        uint256 id = racers.mint(byteCode);
        racers.setTokenURI(id, "test");

        string memory uri = racers.tokenURI(id);
        assertEq(uri, "test");
    }
}
