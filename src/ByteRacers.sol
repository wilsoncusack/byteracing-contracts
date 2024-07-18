// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC721} from "solady/tokens/ERC721.sol";

contract ByteRacers is ERC721 {
    error InvalidTokenId(uint256 tokenId);
    error OnlyOwner();
    error idZeroNotAllowed();

    event RacerMinted(uint256 indexed racerId, bytes byteCode);

    uint256 internal _nonce;

    mapping(uint256 tokenId => string tokenURI) internal _tokenURI;

    function mint(bytes calldata byteCode) external returns (uint256 id) {
        return mintTo(msg.sender, byteCode);
    }

    function mintTo(address to, bytes calldata byteCode) public returns (uint256 id) {
        id = uint256(keccak256(byteCode));
        if (id == 0) {
            // breaks some logic in byteRaces
            revert idZeroNotAllowed();
        }
        _safeMint(to, id);

        emit RacerMinted(id, byteCode);
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        // will revert if doesn't exist
        ownerOf(id);

        return _tokenURI[id];
    }

    function setTokenURI(uint256 id, string memory uri) public {
        if (ownerOf(id) != msg.sender) {
            revert OnlyOwner();
        }

        _tokenURI[id] = uri;
    }

    function name() public view override returns (string memory) {
        return "ByteRacers";
    }

    function symbol() public view override returns (string memory) {
        return "BR";
    }
}
