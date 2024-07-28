// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC721} from "solady/tokens/ERC721.sol";

contract ByteRacers is ERC721 {
    struct TokenURIResolution {
        string uri;
        address callTo;
        bytes callData;
    }

    error InvalidTokenId(uint256 tokenId);
    error OnlyOwner();
    error idZeroNotAllowed();

    event RacerMinted(uint256 indexed racerId, bytes byteCode);

    mapping(uint256 tokenId => TokenURIResolution resolution) internal _tokenURI;

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

    function setTokenURI(uint256 id, string memory uri) public {
        if (ownerOf(id) != msg.sender) {
            revert OnlyOwner();
        }

        _tokenURI[id] = TokenURIResolution({uri: uri, callTo: address(0), callData: ""});
    }

    function setTokenURI(uint256 id, address callTo, bytes calldata callData) public {
        if (ownerOf(id) != msg.sender) {
            revert OnlyOwner();
        }

        _tokenURI[id] = TokenURIResolution({uri: "", callTo: callTo, callData: callData});
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        // reverts if token does not exist
        ownerOf(id);

        if (_tokenURI[id].callTo != address(0)) {
            (bool success, bytes memory ret) = _tokenURI[id].callTo.staticcall(_tokenURI[id].callData);
            if (success) {
                return abi.decode(ret, (string));
            } else {
                assembly ("memory-safe") {
                    revert(add(ret, 32), mload(ret))
                }
            }
        } else {
            return _tokenURI[id].uri;
        }
    }

    function name() public view override returns (string memory) {
        return "ByteRacers";
    }

    function symbol() public view override returns (string memory) {
        return "BR";
    }
}
